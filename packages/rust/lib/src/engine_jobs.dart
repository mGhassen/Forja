import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'engine.dart';
import 'library_path.dart';

/// Job kinds — must match [JobKind] in `crates/ffi/src/engine_jobs.rs`.
abstract final class EngineAsyncJob {
  static const webstreamrGetStreams = 1;
  static const stremioHttpGet = 2;
  static const resolveVidsrcEmbed = 3;
  static const searchTorrents = 4;
  static const httpGet = 5;
  static const httpPost = 6;
  static const iptvProbeStream = 7;
  static const torrentStream = 8;
  static const seek111477Start = 9;
  static const resolverEngineResolve = 10;
  static const resolverEngineContinue = 11;
  static const liveMatchesFetch = 12;
  static const iptvRedditCatalog = 13;
  static const iptvXtream = 14;
}

class _AwaitJobCmd {
  const _AwaitJobCmd(this.jobId, this.replyPort);
  final int jobId;
  final SendPort replyPort;
}

class _SubscribeStatusCmd {
  const _SubscribeStatusCmd(this.updatesPort);
  final SendPort updatesPort;
}

class _UnsubscribeStatusCmd {
  const _UnsubscribeStatusCmd(this.updatesPort);
  final SendPort updatesPort;
}

class _ShutdownCmd {
  const _ShutdownCmd();
}

class _WaiterStartupFailure {
  const _WaiterStartupFailure(this.error);
  final String error;
}

/// Async Rust jobs: submit on the caller isolate, **poll FFI on a background
/// isolate** so the UI never spins on `engineTakeJobResult` / status JSON.
abstract final class EngineJobs {
  static SendPort? _cmdPort;
  static Isolate? _isolate;
  static SendPort? _mainExitListenerPort;
  static Future<void>? _starting;
  static String? _libraryPath;

  /// Spawn the background waiter (idempotent). Call from [Engine.init].
  static Future<void> ensureStarted([String? libraryPath]) async {
    if (_cmdPort != null) return;
    final path = libraryPath ??
        _libraryPath ??
        RustLib.loadedLibraryPath ??
        firstExistingRustLibrary();
    if (path == null) {
      throw StateError(
        'Rust library path unknown — call Engine.init() on the main isolate first',
      );
    }
    _libraryPath = path;
    await (_starting ??= _spawnWaiter(path));
  }

  static Future<void> _ensureStarted() => ensureStarted();

  static Future<void> _spawnWaiter(String libraryPath) async {
    final ready = ReceivePort();
    try {
      final isolate = await Isolate.spawn(
        _engineJobsWaiterMain,
        [ready.sendPort, libraryPath],
        debugName: 'forja-engine-jobs-waiter',
      );
      final startup = await ready.first;
      if (startup is _WaiterStartupFailure) {
        isolate.kill(priority: Isolate.immediate);
        throw StateError(
          'EngineJobs waiter failed to load Rust library: ${startup.error}',
        );
      }
      final ports = startup as List<Object?>;
      _cmdPort = ports[0] as SendPort;
      _mainExitListenerPort = ports[1] as SendPort;
      _isolate = isolate;
      Isolate.current.addOnExitListener(_mainExitListenerPort!);
    } finally {
      ready.close();
      _starting = null;
    }
  }

  static Future<String> run(int kind, Map<String, Object?> payload) {
    // When the waiter is already up, submit synchronously in this turn so a
    // same-turn `engineCancelPending()` still sees the job as Pending.
    if (_cmdPort != null) {
      return _awaitSubmitted(kind, payload);
    }
    return _ensureStarted().then((_) => _awaitSubmitted(kind, payload));
  }

  static Future<String> _awaitSubmitted(
    int kind,
    Map<String, Object?> payload,
  ) {
    final jobId =
        RustLib.instance.engineSubmitJob(kind, jsonEncode(payload));
    final reply = ReceivePort();
    _cmdPort!.send(_AwaitJobCmd(jobId, reply.sendPort));
    return reply.first.then((result) {
      reply.close();
      if (result is String) return result;
      throw StateError('EngineJobs waiter returned unexpected reply: $result');
    });
  }

  /// Live `torrent_status_json` from the waiter isolate (not the UI isolate).
  static Stream<String> torrentStatusJsonStream() {
    late final StreamController<String> controller;
    final updates = ReceivePort();
    var subscribed = false;
    var cancelled = false;

    Future<void> start() async {
      await _ensureStarted();
      if (cancelled || controller.isClosed) return;
      _cmdPort!.send(_SubscribeStatusCmd(updates.sendPort));
      subscribed = true;
      updates.listen((message) {
        if (message is String && !controller.isClosed) {
          controller.add(message);
        }
      });
    }

    controller = StreamController<String>(
      onListen: () {
        unawaited(start());
      },
      onCancel: () {
        cancelled = true;
        if (subscribed) {
          _cmdPort?.send(_UnsubscribeStatusCmd(updates.sendPort));
        }
        updates.close();
      },
    );
    return controller.stream;
  }

  /// Stop polling and fail in-flight async jobs during app shutdown.
  static void shutdown() {
    final port = _cmdPort;
    _cmdPort = null;
    if (_mainExitListenerPort != null) {
      Isolate.current.removeOnExitListener(_mainExitListenerPort!);
      _mainExitListenerPort = null;
    }
    if (port != null) {
      try {
        port.send(const _ShutdownCmd());
      } catch (_) {}
    }
    final isolate = _isolate;
    _isolate = null;
    if (isolate != null) {
      // Give the waiter a beat to exit; then force-kill.
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        isolate.kill(priority: Isolate.immediate);
      });
    }
    if (RustLib.isInitialized) {
      RustLib.instance.enginePrepareShutdown();
    }
    _starting = null;
  }
}

void _engineJobsWaiterMain(List<Object?> startArgs) {
  final readyPort = startArgs[0] as SendPort;
  final libraryPath = startArgs[1] as String;
  final mainDeath = ReceivePort();
  mainDeath.listen((_) => Isolate.exit());

  try {
    RustLib.initSync(libraryPath);
  } catch (e) {
    readyPort.send(_WaiterStartupFailure(e.toString()));
    return;
  }

  final cmds = ReceivePort();
  readyPort.send([cmds.sendPort, mainDeath.sendPort]);

  final pending = <int, SendPort>{};
  final statusListeners = <SendPort>{};
  Timer? timer;

  void stopTimerIfIdle() {
    if (pending.isEmpty && statusListeners.isEmpty) {
      timer?.cancel();
      timer = null;
    }
  }

  void tick() {
    final rust = RustLib.instance;
    for (final entry in pending.entries.toList()) {
      final result = rust.engineTakeJobResult(entry.key);
      if (result == null) continue;
      try {
        entry.value.send(result);
      } catch (_) {}
      pending.remove(entry.key);
    }
    if (statusListeners.isNotEmpty) {
      final json = rust.torrentStatusJson();
      for (final port in statusListeners.toList()) {
        try {
          port.send(json);
        } catch (_) {
          statusListeners.remove(port);
        }
      }
    }
    stopTimerIfIdle();
  }

  void ensureTimer() {
    timer ??= Timer.periodic(const Duration(milliseconds: 20), (_) => tick());
  }

  cmds.listen((message) {
    if (message is _ShutdownCmd) {
      timer?.cancel();
      for (final reply in pending.values) {
        try {
          reply.send('{"error":"cancelled"}');
        } catch (_) {}
      }
      pending.clear();
      statusListeners.clear();
      Isolate.exit();
    }
    if (message is _AwaitJobCmd) {
      pending[message.jobId] = message.replyPort;
      ensureTimer();
      tick();
      return;
    }
    if (message is _SubscribeStatusCmd) {
      statusListeners.add(message.updatesPort);
      ensureTimer();
      tick();
      return;
    }
    if (message is _UnsubscribeStatusCmd) {
      statusListeners.remove(message.updatesPort);
      stopTimerIfIdle();
    }
  });
}
