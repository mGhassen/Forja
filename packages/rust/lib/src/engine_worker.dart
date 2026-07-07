import 'dart:async';
import 'dart:isolate';

import 'engine.dart';
import 'library_path.dart';

/// Long-lived Rust FFI workers — one [Isolate.run] per call replaced by a pool.
enum EngineJobKind {
  version,
  webstreamrGetStreams,
  stremioHttpGet,
  resolveVidsrcEmbed,
  opensslAesDecrypt,
  searchTorrents,
  filterTorrents,
  sortTorrents,
  parseM3u,
  parseHlsMaster,
  decryptKisskh,
  httpGet,
  httpPost,
  animeRequest,
  indexerRequest,
  debridRequest,
  site111477IndexRequest,
  megaResolve,
  musicRequest,
  metadataRequest,
  subtitleRequest,
  parseXtreamCategories,
  parseXtreamStreams,
  parseXtreamSeriesEpisodes,
  iptvProbeStream,
  decryptPasteResponse,
}

class _WorkerJob {
  _WorkerJob({
    required this.id,
    required this.kind,
    required this.args,
    required this.replyPort,
  });

  final int id;
  final EngineJobKind kind;
  final Map<String, Object?> args;
  final SendPort replyPort;
}

class _WorkerReply {
  _WorkerReply({required this.id, this.result, this.error});

  final int id;
  final String? result;
  final String? error;
}

/// Pool of worker isolates with Rust dylib loaded once each.
abstract final class EngineWorkerPool {
  static const _poolSize = 3;

  static final List<SendPort> _ports = [];
  static int _roundRobin = 0;
  static int _nextJobId = 0;
  static String? _libraryPath;
  static Future<void>? _starting;

  static bool get isRunning => _ports.isNotEmpty;

  static Future<void> start(String libraryPath) {
    _libraryPath = libraryPath;
    if (_ports.isNotEmpty) return Future.value();
    return _starting ??= _spawnPool(libraryPath);
  }

  static Future<void> _ensureStarted() async {
    if (_ports.isNotEmpty) return;
    final path =
        _libraryPath ?? RustLib.loadedLibraryPath ?? firstExistingRustLibrary();
    if (path == null) {
      throw StateError(
        'Rust library path unknown — call Engine.init() on the main isolate first',
      );
    }
    await start(path);
  }

  static Future<void> _spawnPool(String libraryPath) async {
    final readyPorts = List.generate(_poolSize, (_) => ReceivePort());
    try {
      for (var i = 0; i < _poolSize; i++) {
        await Isolate.spawn(
          _engineWorkerMain,
          [readyPorts[i].sendPort, libraryPath],
          debugName: 'forja-engine-worker-$i',
        );
        _ports.add(await readyPorts[i].first as SendPort);
      }
    } finally {
      for (final p in readyPorts) {
        p.close();
      }
    }
  }

  static Future<String> run(
    EngineJobKind kind,
    Map<String, Object?> args,
  ) async {
    await _ensureStarted();
    final id = _nextJobId++;
    final reply = ReceivePort();
    final port = _ports[_roundRobin++ % _ports.length];
    port.send(
      _WorkerJob(
        id: id,
        kind: kind,
        args: args,
        replyPort: reply.sendPort,
      ),
    );
    final msg = await reply.first as _WorkerReply;
    reply.close();
    if (msg.error != null) {
      throw StateError(msg.error!);
    }
    return msg.result ?? '';
  }
}

void _engineWorkerMain(List<Object?> startArgs) {
  final readyPort = startArgs[0] as SendPort;
  final libraryPath = startArgs[1] as String;
  RustLib.initSync(libraryPath);
  final jobs = ReceivePort();
  readyPort.send(jobs.sendPort);

  jobs.listen((message) {
    final job = message as _WorkerJob;
    try {
      final result = _dispatchJob(job);
      job.replyPort.send(_WorkerReply(id: job.id, result: result));
    } catch (e) {
      job.replyPort.send(_WorkerReply(id: job.id, error: e.toString()));
    }
  });
}

String _dispatchJob(_WorkerJob job) {
  final rust = RustLib.instance;
  switch (job.kind) {
    case EngineJobKind.version:
      return rust.version;
    case EngineJobKind.webstreamrGetStreams:
      return rust.webstreamrGetStreamsJson(
        job.args['requestJson']! as String,
      );
    case EngineJobKind.stremioHttpGet:
      return rust.stremioHttpGet(
        job.args['url']! as String,
        timeoutSecs: job.args['timeoutSecs']! as int,
      );
    case EngineJobKind.resolveVidsrcEmbed:
      return rust.resolveVidsrcEmbedJson(job.args['requestJson']! as String);
    case EngineJobKind.opensslAesDecrypt:
      return rust.opensslAesDecryptJson(
        job.args['b64']! as String,
        passphrase: job.args['passphrase'] as String? ?? '',
      );
    case EngineJobKind.searchTorrents:
      return rust.searchTorrentsJson(job.args['query']! as String);
    case EngineJobKind.filterTorrents:
      return rust.filterTorrentsJson(
        job.args['resultsJson']! as String,
        job.args['showTitle']! as String,
        requiredSeason: job.args['requiredSeason']! as int,
        requiredEpisode: job.args['requiredEpisode']! as int,
      );
    case EngineJobKind.sortTorrents:
      return rust.sortTorrentsJson(
        job.args['resultsJson']! as String,
        job.args['preference']! as String,
      );
    case EngineJobKind.parseM3u:
      return rust.parseM3uJson(job.args['content']! as String);
    case EngineJobKind.parseHlsMaster:
      return rust.parseHlsMasterJson(
        job.args['masterUrl']! as String,
        job.args['body']! as String,
      );
    case EngineJobKind.decryptKisskh:
      return rust.decryptKisskhBody(
        job.args['body']! as String,
        sourceUrl: job.args['sourceUrl'] as String?,
      );
    case EngineJobKind.httpGet:
      return rust.httpGetJson(
        job.args['url']! as String,
        timeoutSecs: job.args['timeoutSecs']! as int,
        headersJson: job.args['headersJson']! as String,
      );
    case EngineJobKind.httpPost:
      return rust.httpPostJson(
        job.args['url']! as String,
        timeoutSecs: job.args['timeoutSecs']! as int,
        headersJson: job.args['headersJson']! as String,
        body: job.args['body']! as String,
      );
    case EngineJobKind.animeRequest:
      return rust.animeRequestJson(job.args['requestJson']! as String);
    case EngineJobKind.indexerRequest:
      return rust.indexerRequestJson(job.args['requestJson']! as String);
    case EngineJobKind.debridRequest:
      return rust.debridRequestJson(job.args['requestJson']! as String);
    case EngineJobKind.site111477IndexRequest:
      return rust.site111477IndexRequestJson(job.args['requestJson']! as String);
    case EngineJobKind.megaResolve:
      return rust.megaResolveJson(job.args['embedUrl']! as String);
    case EngineJobKind.musicRequest:
      return rust.musicRequestJson(job.args['requestJson']! as String);
    case EngineJobKind.metadataRequest:
      return rust.metadataRequestJson(job.args['requestJson']! as String);
    case EngineJobKind.subtitleRequest:
      return rust.subtitleRequestJson(job.args['requestJson']! as String);
    case EngineJobKind.parseXtreamCategories:
      return rust.parseXtreamCategoriesJson(job.args['json']! as String);
    case EngineJobKind.parseXtreamStreams:
      return rust.parseXtreamStreamsJson(
        job.args['json']! as String,
        job.args['section']! as String,
      );
    case EngineJobKind.parseXtreamSeriesEpisodes:
      return rust.parseXtreamSeriesEpisodesJson(job.args['json']! as String);
    case EngineJobKind.iptvProbeStream:
      return rust.iptvProbeStreamJson(
        job.args['url']! as String,
        timeoutSecs: job.args['timeoutSecs']! as int,
      );
    case EngineJobKind.decryptPasteResponse:
      return rust.decryptPasteResponse(
        job.args['urlWithHash']! as String,
        job.args['rawResponse']! as String,
      );
  }
}
