import 'dart:async';
import 'dart:convert';

import 'engine.dart';

/// Job kinds — must match [JobKind] in `crates/ffi/src/engine_jobs.rs`.
abstract final class EngineAsyncJob {
  static const webstreamrGetStreams = 1;
  static const stremioHttpGet = 2;
  static const resolveVidsrcEmbed = 3;
  static const searchTorrents = 4;
  static const httpGet = 5;
  static const httpPost = 6;
  static const iptvProbeStream = 7;
}

/// Non-blocking long I/O via Rust tokio runtime; main isolate polls for result.
abstract final class EngineJobs {
  static final _pending = <int, Completer<String>>{};
  static Timer? _pollTimer;

  static Future<String> run(int kind, Map<String, Object?> payload) {
    final jobId =
        RustLib.instance.engineSubmitJob(kind, jsonEncode(payload));
    final completer = Completer<String>();
    _pending[jobId] = completer;
    _ensurePolling();
    return completer.future;
  }

  static void _ensurePolling() {
    _pollTimer ??=
        Timer.periodic(const Duration(milliseconds: 2), (_) => _pollOnce());
  }

  static void _pollOnce() {
    if (_pending.isEmpty) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    for (final entry in _pending.entries.toList()) {
      final result = RustLib.instance.engineTakeJobResult(entry.key);
      if (result == null) continue;
      entry.value.complete(result);
      _pending.remove(entry.key);
    }
  }
}
