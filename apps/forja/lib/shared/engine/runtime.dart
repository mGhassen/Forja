import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as dart_crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_js/flutter_js.dart';
import 'package:forja/shared/engine/engine_polyfills.dart';
import 'package:forja/shared/engine/live_goat_unlock.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/nuvio/crypto_aes.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';
import 'package:rust/rust.dart';

void _forjaJsConsole(Map<String, dynamic> m) {
  final msg = (m['msg'] ?? '').toString();
  if (msg.isEmpty) return;
  debugPrint(msg);
}

void _forjaRuntimeLog(String msg) => debugPrint('[ForjaRuntime] $msg');

class EngineMutex {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return () async {
      await previous;
      try {
        return await action();
      } finally {
        if (!done.isCompleted) done.complete();
      }
    }();
  }
}

/// Own QuickJS/JSC heap. Does not call NuvioRuntime.
class EngineRuntime {
  EngineRuntime._();
  static final EngineRuntime instance = EngineRuntime._();

  /// Isolated plugin heaps (Sources Forja pool). Cancel must abort these too —
  /// [instance.abortPendingWork] alone leaves fork VMs live until `dispose`.
  static final Set<EngineRuntime> _liveForks = <EngineRuntime>{};

  /// Torrent indexer batch — must survive [abortAll] while Engine/Nuvio pool
  /// runs; only [abortTorrentSearchForks] / explicit dispose stops it.
  bool _torrentSearchScope = false;

  factory EngineRuntime.fork() {
    final rt = EngineRuntime._();
    _liveForks.add(rt);
    return rt;
  }

  /// One QuickJS heap for a sequential torrent-indexer batch.
  factory EngineRuntime.torrentSearchFork() {
    final rt = EngineRuntime.fork();
    rt._torrentSearchScope = true;
    return rt;
  }

  bool get isActive => _runtime != null && !_deferredDrop;

  /// Stop shared + extract forks. Skips [torrentSearchFork] heaps unless
  /// [includeTorrentSearch] (panel dismiss / torrent cancel).
  static void abortAll({bool includeTorrentSearch = false}) {
    instance.abortPendingWork();
    for (final fork in List<EngineRuntime>.of(_liveForks)) {
      if (fork._torrentSearchScope && !includeTorrentSearch) continue;
      fork.abortPendingWork();
    }
  }

  static void abortTorrentSearchForks() {
    for (final fork in List<EngineRuntime>.of(_liveForks)) {
      if (fork._torrentSearchScope) fork.abortPendingWork();
    }
  }

  JavascriptRuntime? _runtime;
  bool _ready = false;
  Completer<void>? _initCompleter;
  final Set<String> _loadedIds = {};
  final Map<String, String> _pluginCode = {};
  final EngineMutex _jsLock = EngineMutex();

  int _callSeq = 0;
  final Map<int, Completer<String>> _pendingResults = {};

  int _fetchGeneration = 0;
  final Map<int, int> _fetchGens = {};
  bool _acceptingFetches = false;
  int _activeExtract = 0;
  /// Abort asked to drop the VM while [_activeExtract] > 0. Dispose runs in
  /// [_extractUnlocked]'s `finally` after the pump exits — never mid-evaluate
  /// (macOS JSC SIGSEGV in JSValueToStringCopy / JSLockHolder).
  bool _deferredDrop = false;

  int _timerSeq = 0;
  final Map<int, Timer> _activeTimers = {};

  http.Client _http = http.Client();

  Movie? _extractMovie;
  String? _extractImdbId;
  String _extractTmdbId = '';
  String _extractType = 'movie';
  int _extractSeason = 1;
  int _extractEpisode = 1;
  String _extractTitle = '';
  String _extractYear = '';
  String _extractUrl = '';
  int _hopDepth = 0;
  List<EnginePlugin> _hopPlugins = const [];

  Future<void> _ensureInit() async {
    if (_ready) return;
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();
    try {
      final rt = getJavascriptRuntime(
        xhr: false,
        extraArgs: const {'stackSize': 4 * 1024 * 1024},
      );
      _runtime = rt;
      _registerBridges(rt);
      _installHost(rt);
      _installPolyfills(rt);
      await _loadStreamCrypto(rt);
      await _loadCheerio(rt);
      _ready = true;
      _initCompleter!.complete();
    } catch (e, st) {
      _initCompleter!.completeError(e, st);
      _initCompleter = null;
      rethrow;
    }
  }

  Map<String, dynamic> _bridgeMap(dynamic args) {
    if (args is Map) return Map<String, dynamic>.from(args);
    if (args is String && args.isNotEmpty) {
      try {
        final decoded = jsonDecode(args);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }

  void _registerBridges(JavascriptRuntime rt) {
    void br(String name, Object? Function(dynamic args) fn) {
      rt.setupBridge(name, fn);
    }

    br('Console', (args) {
      try {
        _forjaJsConsole(_bridgeMap(args));
      } catch (_) {}
      return null;
    });

    br('CryptoDigest', (args) {
      try {
        final m = _bridgeMap(args);
        final algo = (m['algo'] ?? 'SHA256').toString();
        final hex = (m['hex'] ?? '').toString();
        if (hex.isNotEmpty) {
          return _hashFor(algo).convert(bytesFromHex(hex)).toString();
        }
        return _digestHex(algo, (m['data'] ?? '').toString());
      } catch (_) {
        return '';
      }
    });
    br('SolvePow', (args) {
      try {
        return _solvePow(_bridgeMap(args));
      } catch (_) {
        return '';
      }
    });
    br('SolveScryptPow', (args) {
      try {
        return _solveScryptPow(_bridgeMap(args));
      } catch (_) {
        return '';
      }
    });
    br('CryptoHmac', (args) {
      try {
        final m = _bridgeMap(args);
        return _hmacHex(
          (m['algo'] ?? 'SHA256').toString(),
          (m['key'] ?? '').toString(),
          (m['data'] ?? '').toString(),
        );
      } catch (_) {
        return '';
      }
    });
    br('CryptoUtf8ToHex', (args) {
      try {
        final m = _bridgeMap(args);
        return hexFromBytes(utf8.encode((m['data'] ?? '').toString()));
      } catch (_) {
        return '';
      }
    });
    br('CryptoHexToUtf8', (args) {
      try {
        final m = _bridgeMap(args);
        return utf8.decode(
          bytesFromHex((m['data'] ?? '').toString()),
          allowMalformed: true,
        );
      } catch (_) {
        return '';
      }
    });
    br('CryptoAes', (args) {
      try {
        final m = _bridgeMap(args);
        return aesHex(
          mode: (m['mode'] ?? 'AES-CBC').toString(),
          keyHex: (m['key'] ?? '').toString(),
          ivHex: (m['iv'] ?? '').toString(),
          dataHex: (m['data'] ?? '').toString(),
          encrypt: m['encrypt'] == true,
        );
      } catch (_) {
        return '';
      }
    });
    br('ParseUrl', (args) {
      try {
        final m = _bridgeMap(args);
        return _parseUrl((m['url'] ?? '').toString());
      } catch (_) {
        return _emptyUrlParts();
      }
    });

    br('HostStart', (args) {
      try {
        if (!_acceptingFetches || _activeExtract <= 0) return null;
        final m = _bridgeMap(args);
        final id = (m['id'] as num).toInt();
        final hostId = (m['hostId'] ?? '').toString().trim();
        final gen = _fetchGeneration;
        unawaited(_dispatchHost(id: id, hostId: hostId, gen: gen));
      } catch (_) {}
      return null;
    });

    br('HopStart', (args) {
      try {
        if (!_acceptingFetches || _activeExtract <= 0) return null;
        final m = _bridgeMap(args);
        final id = (m['id'] as num).toInt();
        final url = (m['url'] ?? '').toString().trim();
        final gen = _fetchGeneration;
        unawaited(_dispatchHop(id: id, url: url, gen: gen));
      } catch (_) {}
      return null;
    });

    br('KissKhKkey', (args) {
      try {
        final m = _bridgeMap(args);
        final episodeId =
            int.tryParse((m['episodeId'] ?? m['id'] ?? '').toString()) ?? 0;
        final kind = (m['kind'] ?? 'video').toString();
        return '';
      } catch (_) {
        return '';
      }
    });
    br('EncodePipe', (args) {
      try {
        final m = _bridgeMap(args);
        return _encodePipe((m['json'] ?? m['body'] ?? '').toString());
      } catch (_) {
        return '';
      }
    });
    br('DecodePipe', (args) {
      try {
        final m = _bridgeMap(args);
        return _decodePipe(
          (m['body'] ?? '').toString(),
          (m['xObf'] ?? m['xobf'] ?? '').toString(),
        );
      } catch (_) {
        return '';
      }
    });

    br('LiveGoatUnlock', (args) async {
      try {
        final m = _bridgeMap(args);
        final slotRaw = m['slot'];
        final slot = slotRaw is Map
            ? Map<String, dynamic>.from(slotRaw)
            : <String, dynamic>{};
        final url = await LiveGoatUnlock.unlock(
          slot: slot,
          goat: (m['goat'] ?? '').toString(),
          bodyHex: (m['bodyHex'] ?? '').toString(),
        );
        return url ?? '';
      } catch (_) {
        return '';
      }
    });

    br('LiveGasmUnlock', (args) async {
      try {
        final m = _bridgeMap(args);
        final slotRaw = m['slot'];
        final slot = slotRaw is Map
            ? Map<String, dynamic>.from(slotRaw)
            : <String, dynamic>{};
        final url = await LiveGoatUnlock.unlockGasm(
          slot: slot,
          island: (m['island'] ?? '').toString(),
          bodyHex: (m['bodyHex'] ?? '').toString(),
        );
        return url ?? '';
      } catch (_) {
        return '';
      }
    });

    br('LiveSportsEmbedUnlock', (args) async {
      try {
        final m = _bridgeMap(args);
        final url = await LiveGoatUnlock.resolveSportsEmbed(
          embedUrl: (m['embedUrl'] ?? m['url'] ?? '').toString(),
        );
        return url?.url ?? '';
      } catch (_) {
        return '';
      }
    });

    br('LiveSniffEmbed', (args) async {
      try {
        final m = _bridgeMap(args);
        final url = await LiveGoatUnlock.sniffEmbed(
          embedUrl: (m['url'] ?? m['embedUrl'] ?? '').toString(),
          referer: (m['referer'] ?? '').toString(),
        );
        return url ?? '';
      } catch (_) {
        return '';
      }
    });

    br('FetchStart', (args) {
      try {
        if (!_acceptingFetches || _activeExtract <= 0) return null;
        final m = _bridgeMap(args);
        final id = (m['id'] as num).toInt();
        final url = (m['url'] ?? '').toString();
        final method = (m['method'] ?? 'GET').toString().toUpperCase();
        final headers = <String, String>{};
        final hRaw = m['headers'];
        if (hRaw is Map) {
          hRaw.forEach((k, v) => headers[k.toString()] = v.toString());
        }
        final body = (m['body'] ?? '').toString();
        final gen = _fetchGeneration;
        _fetchGens[id] = gen;
        unawaited(
          _dispatchFetch(
            id: id,
            url: url,
            method: method,
            headers: headers,
            body: body,
            gen: gen,
          ),
        );
      } catch (_) {}
      return null;
    });

    br('CaptureResult', (args) {
      try {
        final m = _bridgeMap(args);
        final id = (m['id'] as num).toInt();
        final body = (m['body'] ?? '[]').toString();
        final c = _pendingResults.remove(id);
        if (c != null && !c.isCompleted) c.complete(body);
      } catch (_) {}
      return null;
    });

    br('TimerSchedule', (args) {
      try {
        if (!_acceptingFetches || _deferredDrop) return 0;
        final m = _bridgeMap(args);
        final ms = ((m['ms'] as num?) ?? 0).toInt().clamp(0, 600000);
        final repeat = m['repeat'] == true;
        final id = ++_timerSeq;
        if (repeat) {
          _activeTimers[id] = Timer.periodic(
            Duration(milliseconds: ms == 0 ? 1 : ms),
            (_) => _fireTimer(id, repeat: true),
          );
        } else {
          _activeTimers[id] = Timer(Duration(milliseconds: ms), () {
            _fireTimer(id, repeat: false);
          });
        }
        return id;
      } catch (_) {
        return 0;
      }
    });
    br('TimerCancel', (args) {
      try {
        final m = _bridgeMap(args);
        final id = (m['id'] as num).toInt();
        _activeTimers.remove(id)?.cancel();
      } catch (_) {}
      return null;
    });
  }

  void _fireTimer(int id, {required bool repeat}) {
    final rt = _runtime;
    if (rt == null || _deferredDrop || !_acceptingFetches) return;
    if (!repeat) _activeTimers.remove(id);
    _evalOn(rt, 'try { globalThis.__engineTimerFire($id); } catch (e) {}',
        sourceUrl: 'engine://timer/$id');
  }

  /// Evaluate only if [rt] is still the live heap. Never call evaluate on a
  /// disposed / replaced JavascriptRuntime (JSC use-after-dispose).
  void _evalOn(JavascriptRuntime rt, String code, {String? sourceUrl}) {
    if (_deferredDrop || !identical(_runtime, rt)) return;
    try {
      rt.evaluate(code, sourceUrl: sourceUrl);
    } catch (_) {}
  }

  void _installHost(JavascriptRuntime rt) {
    final res = rt.evaluate(_hostJs, sourceUrl: 'engine://host');
    if (res.isError) {
      throw StateError('engine host failed: ${res.stringResult}');
    }
  }

  void _installPolyfills(JavascriptRuntime rt) {
    final res = rt.evaluate(
      kEnginePolyfillsJs,
      sourceUrl: 'engine://polyfills',
    );
    if (res.isError) {
      throw StateError('engine polyfills failed: ${res.stringResult}');
    }
  }

  Future<void> _loadStreamCrypto(JavascriptRuntime rt) async {
    try {
      final code = await rootBundle.loadString(
        'assets/engine/_streamcrypto.js',
      );
      final res = rt.evaluate(code, sourceUrl: 'engine://streamcrypto');
      if (res.isError) {
        _forjaRuntimeLog('streamcrypto load error: ${res.stringResult}');
      }
    } catch (e) {
      _forjaRuntimeLog('streamcrypto load failed: $e');
    }
  }

  Future<void> _loadCheerio(JavascriptRuntime rt) async {
    try {
      final code = await rootBundle.loadString(
        'assets/nuvio/cheerio.bundle.js',
      );
      final wrapped =
          '''
(function(){
  var module = { exports: {} };
  var exports = module.exports;
  try {
    $code
    var c = (module.exports && Object.keys(module.exports).length > 0)
      ? module.exports
      : (typeof cheerio !== 'undefined' ? cheerio : null);
    if (c) globalThis.__engineCheerio = c;
  } catch (e) {
    sendMessage('Console', JSON.stringify({level:'err',msg:'[ForjaRuntime] cheerio load failed: ' + (e && e.message ? e.message : e)}));
  }
})();
''';
      final res = rt.evaluate(wrapped, sourceUrl: 'engine://cheerio');
      if (res.isError) {
        _forjaRuntimeLog('cheerio bundle error: ${res.stringResult}');
      }
    } catch (e) {
      _forjaRuntimeLog('cheerio load failed: $e');
    }
  }

  Future<void> loadPlugin({required String pluginId, required String code}) {
    return _jsLock.run(() async {
      await _ensureInit();
      _pluginCode[pluginId] = code;
      _loadPluginUnlocked(pluginId, code);
    });
  }

  bool isLoaded(String pluginId) => _loadedIds.contains(pluginId);

  void stashPluginCode(String pluginId, String code) {
    if (pluginId.isEmpty || code.isEmpty) return;
    _pluginCode[pluginId] = code;
  }

  void registerHops(List<EnginePlugin> hops) {
    _hopPlugins = List<EnginePlugin>.from(hops);
  }

  void _loadPluginUnlocked(String pluginId, String code) {
    final rt = _runtime!;
    final wrapped =
        '''
(function(){
  var module = { exports: {} };
  var exports = module.exports;
  globalThis.extract = undefined;
  globalThis.search = undefined;
  try {
    $code
    if (typeof extract === 'function') {
      if (typeof module.exports.extract !== 'function') module.exports.extract = extract;
      if (typeof globalThis.extract !== 'function') globalThis.extract = extract;
    }
    if (typeof search === 'function') {
      if (typeof module.exports.search !== 'function') module.exports.search = search;
      if (typeof globalThis.search !== 'function') globalThis.search = search;
    }
  } catch (e) {
    sendMessage('Console', JSON.stringify({level:'err',msg:'[ForjaLoader:'+${jsonEncode(pluginId)}+'] ' + (e && e.message ? e.message : e)}));
    throw e;
  }
  var extractFn = (module.exports && module.exports.extract) || globalThis.extract;
  var searchFn = (module.exports && module.exports.search) || globalThis.search;
  globalThis.__engineRegistry[${jsonEncode(pluginId)}] = { extract: extractFn, search: searchFn };
})();
''';
    final res = rt.evaluate(wrapped, sourceUrl: 'engine://$pluginId');
    if (res.isError) {
      throw Exception('engine load failed ($pluginId): ${res.stringResult}');
    }
    _loadedIds.add(pluginId);
  }

  Future<List<Map<String, dynamic>>> extract({
    required String pluginId,
    String? pluginName,
    required String tmdbId,
    String? imdbId,
    int? malId,
    int? anilistId,
    int? mappedEpisode,
    required String type,
    int? season,
    int? episode,
    String? title,
    String? year,
    Map<String, dynamic> config = const {},
    Movie? movie,
    String? url,
    Map<String, dynamic> extractCtx = const {},
    Duration timeout = const Duration(seconds: 30),
    bool allowHostFallback = false,
    bool Function()? isCancelled,
  }) {
    return _jsLock.run(() async {
      await _ensureInit();
      if (isCancelled?.call() == true) return [];
      if (!_loadedIds.contains(pluginId)) {
        final code = _pluginCode[pluginId];
        if (code == null) {
          throw StateError('engine plugin $pluginId not loaded');
        }
        _loadPluginUnlocked(pluginId, code);
      }
      return _extractUnlocked(
        pluginId: pluginId,
        pluginName: pluginName,
        tmdbId: tmdbId,
        imdbId: imdbId,
        malId: malId,
        anilistId: anilistId,
        mappedEpisode: mappedEpisode,
        type: type,
        season: season,
        episode: episode,
        title: title,
        year: year,
        config: config,
        movie: movie,
        url: url,
        extractCtx: extractCtx,
        timeout: timeout,
        allowHostFallback: allowHostFallback,
        isCancelled: isCancelled,
      );
    });
  }

  Future<List<Map<String, dynamic>>> extractLive({
    required String pluginId,
    String? pluginName,
    required String action,
    Map<String, dynamic> params = const {},
    Map<String, dynamic> config = const {},
    Duration timeout = const Duration(seconds: 45),
    bool Function()? isCancelled,
  }) {
    return _jsLock.run(() async {
      await _ensureInit();
      if (isCancelled?.call() == true) return [];
      if (!_loadedIds.contains(pluginId)) {
        final code = _pluginCode[pluginId];
        if (code == null) {
          throw StateError('engine plugin $pluginId not loaded');
        }
        _loadPluginUnlocked(pluginId, code);
      }
      return _extractUnlocked(
        pluginId: pluginId,
        pluginName: pluginName,
        tmdbId: '',
        type: 'live',
        config: config,
        timeout: timeout,
        allowHostFallback: false,
        isCancelled: isCancelled,
        extraCtx: {
          'action': action,
          'pluginId': pluginId,
          ...params,
        },
      );
    });
  }

  Future<List<Map<String, dynamic>>> searchTorrent({
    required String pluginId,
    String? pluginName,
    required String query,
    String? imdbId,
    int? season,
    int? episode,
    Map<String, dynamic> config = const {},
    Duration timeout = const Duration(seconds: 20),
    bool Function()? isCancelled,
  }) {
    return _jsLock.run(() async {
      await _ensureInit();
      if (isCancelled?.call() == true) return [];
      if (!_loadedIds.contains(pluginId)) {
        final code = _pluginCode[pluginId];
        if (code == null) {
          throw StateError('engine plugin $pluginId not loaded');
        }
        _loadPluginUnlocked(pluginId, code);
      }
      return _searchUnlocked(
        pluginId: pluginId,
        pluginName: pluginName,
        query: query,
        imdbId: imdbId,
        season: season,
        episode: episode,
        config: config,
        timeout: timeout,
        isCancelled: isCancelled,
      );
    });
  }

  Future<List<Map<String, dynamic>>> _searchUnlocked({
    required String pluginId,
    String? pluginName,
    required String query,
    String? imdbId,
    int? season,
    int? episode,
    Map<String, dynamic> config = const {},
    required Duration timeout,
    bool Function()? isCancelled,
  }) async {
    final rt = _runtime!;
    final callId = ++_callSeq;
    final completer = Completer<String>();
    _pendingResults[callId] = completer;
    _activeExtract++;
    _acceptingFetches = true;

    try {
      final ctx = jsonEncode({
        'query': query,
        'imdbId': imdbId ?? '',
        'season': season ?? 0,
        'episode': episode ?? 0,
        'config': config,
      });
      final pluginLabel = (pluginName != null && pluginName.trim().isNotEmpty)
          ? pluginName.trim()
          : pluginId;
      final invoker =
          '''
(function(){
  var entry = globalThis.__engineRegistry[${jsonEncode(pluginId)}];
  var fn = entry && entry.search;
  if (typeof fn !== 'function') {
    sendMessage('CaptureResult', JSON.stringify({id:$callId, body:'[]'}));
    return;
  }
  var meta = $ctx;
  var pluginLabel = ${jsonEncode(pluginLabel)};
  var ctx = {
    query: String(meta.query || ''),
    imdbId: String(meta.imdbId || ''),
    season: meta.season || 0,
    episode: meta.episode || 0,
    config: meta.config || {},
    log: function(msg) {
      console.log('[' + pluginLabel + '] ' + String(msg == null ? '' : msg));
    },
    error: function(msg) {
      console.error('[' + pluginLabel + '] Error: ' + String(msg == null ? '' : msg));
    },
    fetch: globalThis.fetch,
    html: globalThis.__engineHtml
  };
  Promise.resolve()
    .then(function(){ return fn(ctx); })
    .then(function(r){
      try { sendMessage('CaptureResult', JSON.stringify({id:$callId, body: JSON.stringify(r == null ? [] : r)})); }
      catch (e) { sendMessage('CaptureResult', JSON.stringify({id:$callId, body:'[]'})); }
    })
    .catch(function(e){
      var msg = (e && e.message) ? e.message : (e ? String(e) : 'unknown');
      sendMessage('Console', JSON.stringify({level:'err',msg:'[ForjaTorrent:'+${jsonEncode(pluginId)}+'] '+msg}));
      sendMessage('CaptureResult', JSON.stringify({id:$callId, body:'[]'}));
    });
})();
''';
      final r = rt.evaluate(invoker);
      if (r.isError) {
        _pendingResults.remove(callId);
        _forjaRuntimeLog('torrent invoker error: ${r.stringResult}');
        return [];
      }

      final stopwatch = Stopwatch()..start();
      while (!completer.isCompleted &&
          stopwatch.elapsedMilliseconds < timeout.inMilliseconds) {
        if (isCancelled?.call() == true) {
          _pendingResults.remove(callId);
          if (!completer.isCompleted) completer.complete('[]');
          return [];
        }
        if (!identical(_runtime, rt) || _deferredDrop) {
          if (!completer.isCompleted) completer.complete('[]');
          return [];
        }
        try {
          rt.executePendingJob();
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 8));
      }
      if (!completer.isCompleted) {
        _pendingResults.remove(callId);
        if (!completer.isCompleted) completer.complete('[]');
        _fetchGeneration++;
        _fetchGens.clear();
        return [];
      }

      final body = (await completer.future).trim();
      if (isCancelled?.call() == true) return [];
      if (!identical(_runtime, rt) || _deferredDrop) return [];
      if (body.isEmpty || body == 'null' || body == 'undefined') return [];
      try {
        final decoded = jsonDecode(body);
        if (decoded is! List) return [];
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (e) {
        _forjaRuntimeLog('torrent result parse failed ($pluginId): $e');
        return [];
      }
    } finally {
      _pendingResults.remove(callId);
      _activeExtract = (_activeExtract - 1).clamp(0, 1 << 30);
      if (_activeExtract <= 0) {
        _acceptingFetches = false;
        if (_deferredDrop) {
          _dropRuntime();
        }
      }
    }
  }

  Future<List<Map<String, dynamic>>> _extractUnlocked({
    required String pluginId,
    String? pluginName,
    required String tmdbId,
    String? imdbId,
    int? malId,
    int? anilistId,
    int? mappedEpisode,
    required String type,
    int? season,
    int? episode,
    String? title,
    String? year,
    Map<String, dynamic> config = const {},
    Movie? movie,
    String? url,
    Map<String, dynamic> extractCtx = const {},
    required Duration timeout,
    required bool allowHostFallback,
    bool Function()? isCancelled,
    Map<String, dynamic> extraCtx = const {},
  }) async {
    final rt = _runtime!;
    _extractMovie = movie;
    _extractImdbId = imdbId;
    _extractTmdbId = tmdbId;
    _extractType = type == 'tv' || type == 'series' ? 'tv' : 'movie';
    _extractSeason = season ?? 1;
    _extractEpisode = episode ?? 1;
    _extractTitle = title ?? '';
    _extractYear = year ?? '';
    if (url != null) _extractUrl = url;
    final callId = ++_callSeq;
    final completer = Completer<String>();
    _pendingResults[callId] = completer;
    _activeExtract++;
    _acceptingFetches = true;

    try {
      final ctx = jsonEncode({
        'tmdbId': tmdbId,
        'imdbId': imdbId ?? '',
        'malId': malId ?? '',
        'anilistId': anilistId ?? '',
        'mappedEpisode': mappedEpisode ?? _extractEpisode,
        'type': _extractType,
        'season': _extractSeason,
        'episode': _extractEpisode,
        'title': _extractTitle,
        'year': _extractYear,
        'url': _extractUrl,
        ...extractCtx,
        'config': config,
        ...extraCtx,
      });
      final pluginLabel = (pluginName != null && pluginName.trim().isNotEmpty)
          ? pluginName.trim()
          : pluginId;
      final invoker =
          '''
(function(){
  var entry = globalThis.__engineRegistry[${jsonEncode(pluginId)}];
  var fn = entry && entry.extract;
  if (typeof fn !== 'function') {
    sendMessage('CaptureResult', JSON.stringify({id:$callId, body:'[]'}));
    return;
  }
  var meta = $ctx;
  var pluginLabel = ${jsonEncode(pluginLabel)};
  var streamDecrypt = function(body, seed, tmdbId) {
    var fn = globalThis.__engineStreamDecrypt;
    if (typeof fn !== 'function') {
      throw new Error('STREAMCRYPTO: not loaded');
    }
    return fn(
      String(body == null ? '' : body),
      String(seed == null ? '' : seed),
      String(tmdbId == null ? '' : tmdbId),
    );
  };
  var ctx = {
    tmdbId: meta.tmdbId,
    imdbId: meta.imdbId,
    malId: meta.malId,
    anilistId: meta.anilistId,
    mappedEpisode: meta.mappedEpisode,
    type: meta.type,
    season: meta.season,
    episode: meta.episode,
    title: meta.title,
    year: meta.year,
    url: meta.url || '',
    config: meta.config || {},
    action: meta.action || '',
    params: meta.params || {},
    auth: meta.auth || {},
    cache: meta.cache || {},
    kit: meta.kit || 0,
    protocol: meta.protocol || 0,
    matchId: meta.matchId || '',
    source: meta.source || '',
    stream: meta.stream || '',
    embedUrl: meta.embedUrl || '',
    category: meta.category || '',
    pluginId: meta.pluginId || '',
    live: {
      goatUnlock: function(bodyHex, goat, slot) {
        return sendMessage('LiveGoatUnlock', JSON.stringify({
          bodyHex: String(bodyHex == null ? '' : bodyHex),
          goat: String(goat == null ? '' : goat),
          slot: slot || {}
        })) || '';
      },
      gasmUnlock: function(bodyHex, island, slot) {
        return sendMessage('LiveGasmUnlock', JSON.stringify({
          bodyHex: String(bodyHex == null ? '' : bodyHex),
          island: String(island == null ? '' : island),
          slot: slot || {}
        })) || '';
      },
      sportsEmbedUnlock: function(embedUrl) {
        return sendMessage('LiveSportsEmbedUnlock', JSON.stringify({
          embedUrl: String(embedUrl == null ? '' : embedUrl)
        })) || '';
      },
      sniffEmbed: function(url, referer) {
        return sendMessage('LiveSniffEmbed', JSON.stringify({
          url: String(url == null ? '' : url),
          referer: String(referer == null ? '' : referer)
        })) || '';
      }
    },
    log: function(msg) {
      console.log('[' + pluginLabel + '] ' + String(msg == null ? '' : msg));
    },
    error: function(msg) {
      console.error('[' + pluginLabel + '] Error: ' + String(msg == null ? '' : msg));
    },
    fetch: globalThis.fetch,
    html: globalThis.__engineHtml,
    host: (function(){
      var h = ${allowHostFallback ? 'globalThis.__engineHost' : 'function(){ return Promise.resolve([]); }'};
      if (typeof h !== 'function') h = function(){ return Promise.resolve([]); };
      var tmdbKey = (meta.config && meta.config.apiKey) ? String(meta.config.apiKey) : '';
      h.tmdb = {
        match: function(query) {
          query = query || {};
          var title = String(query.title || '').trim();
          if (!title || !tmdbKey) return Promise.resolve(null);
          var prefer = String(query.type || '').trim().toLowerCase();
          var primary = prefer === 'movie' ? 'movie' : 'tv';
          var secondary = primary === 'movie' ? 'tv' : 'movie';
          var year = Number(query.year) > 0 ? Number(query.year) : 0;
          function yearOf(m, media) {
            var d = String(media === 'movie' ? (m.release_date || '') : (m.first_air_date || ''));
            return d.length >= 4 ? (Number(d.slice(0, 4)) || 0) : 0;
          }
          function pick(results, media) {
            function withBackdrop(list) {
              for (var i = 0; i < list.length; i++) if (list[i] && list[i].backdrop_path) return list[i];
              return list.length ? list[0] : null;
            }
            var chosen = null;
            if (year > 0) {
              var exact = [], near = [];
              for (var i = 0; i < results.length; i++) {
                var y = yearOf(results[i], media);
                if (y === year) exact.push(results[i]);
                else if (y && Math.abs(y - year) <= 1) near.push(results[i]);
              }
              chosen = withBackdrop(exact) || withBackdrop(near) || withBackdrop(results);
            } else chosen = withBackdrop(results);
            if (!chosen || !chosen.id) return null;
            var overview = String(chosen.overview || '').trim();
            var rating = Number(chosen.vote_average);
            return {
              id: Number(chosen.id),
              mediaType: media,
              name: String(media === 'movie' ? (chosen.title || '') : (chosen.name || '')),
              year: yearOf(chosen, media) || null,
              poster: chosen.poster_path ? 'https://image.tmdb.org/t/p/w500' + chosen.poster_path : null,
              backdrop: chosen.backdrop_path ? 'https://image.tmdb.org/t/p/w1280' + chosen.backdrop_path : null,
              overview: overview || null,
              rating: rating > 0 ? rating : null
            };
          }
          function search(media) {
            var url = 'https://api.themoviedb.org/3/search/' + media +
              '?api_key=' + encodeURIComponent(tmdbKey) +
              '&query=' + encodeURIComponent(title) +
              '&include_adult=false';
            return globalThis.fetch(url).then(function(res) {
              if (!res.ok) return null;
              return res.json();
            }).then(function(json) {
              if (!json || !Array.isArray(json.results) || !json.results.length) return null;
              return pick(json.results, media);
            }).catch(function(){ return null; });
          }
          return search(primary).then(function(hit){ return hit || search(secondary); });
        }
      };
      return h;
    })(),
    hop: globalThis.__engineHop,
    crypto: Object.assign({}, globalThis.CryptoJS || {}, {
      streamDecrypt: streamDecrypt,
      kisskhKkey: function(episodeId, kind) {
        return sendMessage('KissKhKkey', JSON.stringify({
          episodeId: episodeId, kind: kind || 'video'
        })) || '';
      },
      encodePipe: function(payload) {
        var raw = typeof payload === 'string' ? payload : JSON.stringify(payload == null ? {} : payload);
        return sendMessage('EncodePipe', JSON.stringify({ json: raw })) || '';
      },
      decodePipe: function(body, xObf) {
        var raw = sendMessage('DecodePipe', JSON.stringify({
          body: String(body == null ? '' : body),
          xObf: String(xObf == null ? '' : xObf)
        })) || '';
        if (!raw) return null;
        try { return JSON.parse(raw); } catch (e) { return null; }
      },
      solvePow: function(challenge, difficulty, max) {
        var raw = sendMessage('SolvePow', JSON.stringify({
          challenge: String(challenge == null ? '' : challenge),
          difficulty: difficulty,
          max: max
        })) || '';
        if (!raw) return null;
        try { return JSON.parse(raw); } catch (e) { return null; }
      },
      solveScryptPow: function(challenge) {
        return sendMessage('SolveScryptPow', JSON.stringify(challenge || {})) || null;
      }
    }),
    streamcrypto: { decrypt: streamDecrypt }
  };
  Promise.resolve()
    .then(function(){ return fn(ctx); })
    .then(function(r){
      var n = Array.isArray(r) ? r.length : (r == null ? 0 : 1);
      sendMessage('Console', JSON.stringify({level:'log',msg:'['+pluginLabel+'] streams='+n}));
      try { sendMessage('CaptureResult', JSON.stringify({id:$callId, body: JSON.stringify(r == null ? [] : r)})); }
      catch (e) { sendMessage('CaptureResult', JSON.stringify({id:$callId, body:'[]'})); }
    })
    .catch(function(e){
      var msg = (e && e.message) ? e.message : (e ? String(e) : 'unknown');
      sendMessage('Console', JSON.stringify({level:'err',msg:'[ForjaInvoker:'+${jsonEncode(pluginId)}+'] '+msg}));
      sendMessage('CaptureResult', JSON.stringify({id:$callId, body:'[]'}));
    });
})();
''';
      final r = rt.evaluate(invoker);
      if (r.isError) {
        _pendingResults.remove(callId);
        _forjaRuntimeLog('invoker error: ${r.stringResult}');
        return [];
      }

      final stopwatch = Stopwatch()..start();
      while (!completer.isCompleted &&
          stopwatch.elapsedMilliseconds < timeout.inMilliseconds) {
        if (isCancelled?.call() == true) {
          _pendingResults.remove(callId);
          if (!completer.isCompleted) completer.complete('[]');
          return [];
        }
        if (!identical(_runtime, rt) || _deferredDrop) {
          if (!completer.isCompleted) completer.complete('[]');
          _forjaRuntimeLog('$pluginId aborted (VM dropped)');
          return [];
        }
        try {
          rt.executePendingJob();
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 8));
      }
      if (!completer.isCompleted) {
        _pendingResults.remove(callId);
        if (!completer.isCompleted) completer.complete('[]');
        // Drop in-flight HTTP so a hung body read cannot pin the fork.
        _fetchGeneration++;
        _fetchGens.clear();
        _forjaRuntimeLog('$pluginId timed out after ${timeout.inSeconds}s');
        return [];
      }

      final body = (await completer.future).trim();
      if (isCancelled?.call() == true) return [];
      if (!identical(_runtime, rt) || _deferredDrop) return [];
      if (body.isEmpty || body == 'null' || body == 'undefined') return [];
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          if (map.containsKey('ok')) return [map];
        }
        if (decoded is! List) return [];
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (e) {
        _forjaRuntimeLog('result parse failed ($pluginId): $e');
        return [];
      }
    } finally {
      _pendingResults.remove(callId);
      _activeExtract = (_activeExtract - 1).clamp(0, 1 << 30);
      if (_activeExtract <= 0) {
        _acceptingFetches = false;
        if (_deferredDrop) {
          _dropRuntime();
          _forjaRuntimeLog('deferred VM drop complete');
        }
      }
    }
  }

  void abortPendingWork() {
    final hadWork =
        _acceptingFetches ||
        _activeExtract > 0 ||
        _activeTimers.isNotEmpty ||
        _pendingResults.isNotEmpty;
    _acceptingFetches = false;
    _fetchGeneration++;
    _fetchGens.clear();
    for (final t in _activeTimers.values) {
      try {
        t.cancel();
      } catch (_) {}
    }
    _activeTimers.clear();
    for (final c in _pendingResults.values) {
      if (!c.isCompleted) c.complete('[]');
    }
    _pendingResults.clear();
    try {
      _http.close();
    } catch (_) {}
    _http = http.Client();
    if (hadWork) {
      if (_activeExtract > 0) {
        _deferredDrop = true;
        _forjaRuntimeLog('abortPendingWork (deferred VM drop)');
      } else {
        _dropRuntime();
        _forjaRuntimeLog('abortPendingWork');
      }
    }
  }

  void dispose() {
    abortPendingWork();
    try {
      _http.close();
    } catch (_) {}
    if (_activeExtract > 0) {
      _deferredDrop = true;
    } else {
      _dropRuntime();
    }
  }

  void _dropRuntime() {
    try {
      _runtime?.dispose();
    } catch (_) {}
    _runtime = null;
    _ready = false;
    _loadedIds.clear();
    _initCompleter = null;
    _activeExtract = 0;
    _deferredDrop = false;
    _liveForks.remove(this);
  }

  Future<void> _dispatchFetch({
    required int id,
    required String url,
    required String method,
    required Map<String, String> headers,
    required String body,
    required int gen,
  }) async {
    if (gen != _fetchGeneration) {
      _fetchGens.remove(id);
      return;
    }
    Map<String, dynamic> envelope;
    try {
      headers.putIfAbsent(
        'User-Agent',
        () =>
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36',
      );
      final uri = Uri.parse(url);

      final req = http.Request(method, uri);
      req.followRedirects = true;
      req.maxRedirects = 8;
      req.headers.addAll(headers);
      final contentType = (headers['Content-Type'] ?? headers['content-type'] ?? '')
          .toLowerCase();
      if (body.isNotEmpty &&
          method != 'GET' &&
          method != 'HEAD' &&
          method != 'OPTIONS') {
        if (contentType.contains('application/octet-stream')) {
          req.bodyBytes = body.codeUnits;
        } else {
          req.body = body;
        }
      }
      final streamed = await _http
          .send(req)
          .timeout(const Duration(seconds: 20));
      if (gen != _fetchGeneration) {
        _fetchGens.remove(id);
        return;
      }
      // Body read must time out too — send() alone returns while a stalled
      // stream hangs the whole extract (Videasy/VidLink 90–105s empties).
      final bytes = await streamed.stream.toBytes().timeout(
        const Duration(seconds: 20),
      );
      if (gen != _fetchGeneration) {
        _fetchGens.remove(id);
        return;
      }
      var text = utf8.decode(bytes, allowMalformed: true);
      const maxLen = 1024 * 1024;
      if (text.length > maxLen) text = text.substring(0, maxLen);
      final respHeaders = <String, dynamic>{};
      streamed.headers.forEach((k, v) => respHeaders[k.toLowerCase()] = v);
      final respCt =
          (streamed.headers['content-type'] ?? '').toLowerCase();
      final respGoat = streamed.headers['goat'];
      final binaryResp = respCt.contains('application/octet-stream') ||
          (respGoat != null && respGoat.isNotEmpty);
      envelope = {
        'ok': streamed.statusCode >= 200 && streamed.statusCode < 300,
        'status': streamed.statusCode,
        'statusText': streamed.reasonPhrase ?? '',
        'url': streamed.request?.url.toString() ?? url,
        'body': binaryResp ? '' : text,
        if (binaryResp) 'bodyB64': base64Encode(bytes),
        'headers': respHeaders,
      };
    } catch (e) {
      if (gen != _fetchGeneration) {
        _fetchGens.remove(id);
        return;
      }
      envelope = {
        'ok': false,
        'status': 0,
        'statusText': e.toString(),
        'url': url,
        'body': '',
        'headers': <String, dynamic>{},
      };
    }
    _fetchGens.remove(id);
    if (gen != _fetchGeneration) return;
    final rt = _runtime;
    if (rt == null || !_acceptingFetches) return;
    _evalOn(
      rt,
      'try { globalThis.__engineFetchResolve($id, ${jsonEncode(envelope)}); } catch (e) {}',
      sourceUrl: 'engine://fetch/$id',
    );
  }

  Future<void> _dispatchHost({
    required int id,
    required String hostId,
    required int gen,
  }) async {
    if (gen != _fetchGeneration) return;
    if (hostId.isEmpty) {
      _resolveHost(id: id, gen: gen, streams: const []);
      return;
    }
    _resolveHost(id: id, gen: gen, streams: const []);
  }

  Future<void> _dispatchHop({
    required int id,
    required String url,
    required int gen,
  }) async {
    if (gen != _fetchGeneration) return;
    if (url.isEmpty || _hopDepth >= 3) {
      _resolveHop(id: id, gen: gen, streams: const []);
      return;
    }
    final hopId = hopPluginIdForUrl(url, _hopPlugins);
    if (hopId == null) {
      _resolveHop(id: id, gen: gen, streams: const []);
      return;
    }
    if (!_loadedIds.contains(hopId)) {
      final code = _pluginCode[hopId];
      if (code == null || code.isEmpty) {
        _resolveHop(id: id, gen: gen, streams: const []);
        return;
      }
      try {
        _loadPluginUnlocked(hopId, code);
      } catch (e) {
        _forjaRuntimeLog('hop load failed id=$hopId: $e');
        _resolveHop(id: id, gen: gen, streams: const []);
        return;
      }
    }

    final savedMovie = _extractMovie;
    final savedImdb = _extractImdbId;
    final savedTmdb = _extractTmdbId;
    final savedType = _extractType;
    final savedSeason = _extractSeason;
    final savedEpisode = _extractEpisode;
    final savedTitle = _extractTitle;
    final savedYear = _extractYear;
    final savedUrl = _extractUrl;
    _hopDepth++;
    List<Map<String, dynamic>> streams = const [];
    try {
      streams = await _extractUnlocked(
        pluginId: hopId,
        tmdbId: savedTmdb,
        imdbId: savedImdb,
        type: savedType,
        season: savedSeason,
        episode: savedEpisode,
        title: savedTitle,
        year: savedYear,
        url: url,
        movie: savedMovie,
        timeout: const Duration(seconds: 20),
        allowHostFallback: false,
        isCancelled: () => gen != _fetchGeneration,
      );
    } catch (e) {
      _forjaRuntimeLog('hop extract failed id=$hopId: $e');
    } finally {
      _hopDepth = (_hopDepth - 1).clamp(0, 8);
      _extractMovie = savedMovie;
      _extractImdbId = savedImdb;
      _extractTmdbId = savedTmdb;
      _extractType = savedType;
      _extractSeason = savedSeason;
      _extractEpisode = savedEpisode;
      _extractTitle = savedTitle;
      _extractYear = savedYear;
      _extractUrl = savedUrl;
    }
    if (gen != _fetchGeneration) return;
    _resolveHop(id: id, gen: gen, streams: streams);
  }

  void _resolveHop({
    required int id,
    required int gen,
    required List<Map<String, dynamic>> streams,
  }) {
    if (gen != _fetchGeneration) return;
    final rt = _runtime;
    if (rt == null || !_acceptingFetches) return;
    _evalOn(
      rt,
      'try { globalThis.__engineHopResolve($id, ${jsonEncode({'streams': streams})}); } catch (e) {}',
      sourceUrl: 'engine://hop/$id',
    );
  }

  void _resolveHost({
    required int id,
    required int gen,
    required List<Map<String, dynamic>> streams,
  }) {
    if (gen != _fetchGeneration) return;
    final rt = _runtime;
    if (rt == null || !_acceptingFetches) return;
    _evalOn(
      rt,
      'try { globalThis.__engineHostResolve($id, ${jsonEncode({'streams': streams})}); } catch (e) {}',
      sourceUrl: 'engine://host/$id',
    );
  }

  String _digestHex(String algo, String utf8Str) {
    final bytes = utf8.encode(utf8Str);
    final hash = _hashFor(algo).convert(bytes);
    return hash.toString();
  }

  // Same key as crates/archive/anime/src/extractors/miruro.rs PIPE_OBF_KEY.
  static const _pipeObfKey = <int>[
    0x71, 0x95, 0x10, 0x34, 0xf8, 0xfb, 0xcf, 0x53,
    0xd8, 0x9d, 0xb5, 0x2c, 0xeb, 0x3d, 0xc2, 0x2c,
  ];

  String _encodePipe(String json) {
    if (json.isEmpty) return '';
    return base64Url.encode(utf8.encode(json)).replaceAll('=', '');
  }

  String _decodePipe(String body, String xObf) {
    if (body.isEmpty) return '';
    final level = xObf.trim();
    if (level.isEmpty) {
      try {
        jsonDecode(body);
        return body;
      } catch (_) {
        return _inflatePipeBody(body, xor: false);
      }
    }
    return _inflatePipeBody(body, xor: level == '2');
  }

  String _inflatePipeBody(String body, {required bool xor}) {
    var b64 = body.replaceAll('-', '+').replaceAll('_', '/');
    final pad = b64.length % 4;
    if (pad != 0) b64 += '=' * (4 - pad);
    late List<int> data;
    try {
      data = base64.decode(b64);
    } catch (_) {
      return '';
    }
    if (xor) {
      final key = _pipeObfKey;
      data = List<int>.generate(
        data.length,
        (i) => data[i] ^ key[i % key.length],
      );
    }
    final plain = utf8.decode(_inflateBytes(data), allowMalformed: true);
    try {
      jsonDecode(plain);
      return plain;
    } catch (_) {
      return '';
    }
  }

  List<int> _inflateBytes(List<int> data) {
    if (data.length >= 2 && data[0] == 0x1f && data[1] == 0x8b) {
      try {
        return gzip.decode(data);
      } catch (_) {}
    }
    try {
      return zlib.decode(data);
    } catch (_) {}
    try {
      return zlib.decode(<int>[0x78, 0x01, ...data]);
    } catch (_) {}
    return data;
  }

  /// SHA-256 leading-hex-zero PoW (Goated `/api/challenge`). Loop stays in Dart
  /// so QuickJS does not round-trip millions of `CryptoDigest` calls.
  String _solvePow(Map<String, dynamic> m) {
    final challenge = (m['challenge'] ?? '').toString();
    if (challenge.isEmpty) return '';
    final difficulty = int.tryParse('${m['difficulty']}') ?? 0;
    if (difficulty < 0 || difficulty > 8) return '';
    final max = int.tryParse('${m['max']}') ?? 5000000;
    final cap = max.clamp(1, 5000000);
    final prefix = '0' * difficulty;
    final hash = dart_crypto.sha256;
    for (var n = 0; n < cap; n++) {
      final h = hash.convert(utf8.encode('$challenge$n')).toString();
      if (h.startsWith(prefix)) {
        return jsonEncode({'challenge': challenge, 'nonce': '$n'});
      }
    }
    return '';
  }

  /// scrypt leading-zero-bit PoW (CineJoy / api.shegu.st). Loop stays in Dart.
  String _solveScryptPow(Map<String, dynamic> m) {
    final s = (m['s'] ?? '').toString();
    final b = (m['b'] ?? '').toString();
    final n = int.tryParse('${m['n']}') ?? 0;
    final r = int.tryParse('${m['r']}') ?? 0;
    final p = int.tryParse('${m['p']}') ?? 0;
    final d = int.tryParse('${m['d']}') ?? 0;
    if (s.isEmpty || b.isEmpty || n <= 0 || r <= 0 || p <= 0 || d <= 0) {
      return '';
    }
    final max = int.tryParse('${m['max']}') ?? 500000;
    final cap = max.clamp(1, 500000);
    final salt = Uint8List.fromList(
      dart_crypto.sha256.convert(utf8.encode('pow2-salt|$s|$b')).bytes,
    );
    final scrypt = Scrypt();
    for (var counter = 0; counter < cap; counter++) {
      scrypt.init(ScryptParameters(n, r, p, 32, salt));
      final result = scrypt.process(utf8.encode('pow2|$b|$s|$counter'));
      if (_leadingZeroBits(result) >= d) {
        final payload = Map<String, dynamic>.from(m)..['c'] = counter;
        return base64Encode(utf8.encode(jsonEncode(payload)));
      }
    }
    return '';
  }

  int _leadingZeroBits(List<int> data) {
    var count = 0;
    for (final value in data) {
      if (value == 0) {
        count += 8;
        continue;
      }
      var bits = 0;
      var v = value;
      while (v > 0) {
        bits++;
        v >>= 1;
      }
      count += 8 - bits;
      break;
    }
    return count;
  }

  String _hmacHex(String algo, String key, String data) {
    final h = dart_crypto.Hmac(_hashFor(algo), utf8.encode(key));
    return h.convert(utf8.encode(data)).toString();
  }

  dart_crypto.Hash _hashFor(String algo) {
    switch (algo.toUpperCase()) {
      case 'MD5':
        return dart_crypto.md5;
      case 'SHA1':
        return dart_crypto.sha1;
      case 'SHA512':
        return dart_crypto.sha512;
      case 'SHA256':
      default:
        return dart_crypto.sha256;
    }
  }

  Map<String, dynamic> _parseUrl(String input) {
    try {
      final u = Uri.parse(input);
      final scheme = u.scheme.isEmpty ? 'https' : u.scheme;
      final host = u.host;
      final port = u.hasPort ? u.port.toString() : '';
      final search = u.query.isEmpty ? '' : '?${u.query}';
      final fragment = u.fragment.isEmpty ? '' : '#${u.fragment}';
      final pathname = u.path.isEmpty ? '/' : u.path;
      return {
        'protocol': '$scheme:',
        'host': port.isEmpty ? host : '$host:$port',
        'hostname': host,
        'port': port,
        'pathname': pathname,
        'search': search,
        'hash': fragment,
      };
    } catch (_) {
      return _emptyUrlParts();
    }
  }

  Map<String, dynamic> _emptyUrlParts() => {
    'protocol': '',
    'host': '',
    'hostname': '',
    'port': '',
    'pathname': '/',
    'search': '',
    'hash': '',
  };

  static const _hostJs = r'''
(function(){
  if (typeof atob === 'undefined') {
    globalThis.atob = function(input) {
      var str = String(input).replace(/[\t\n\f\r ]+/g, '');
      var map = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
      var output = '', bc = 0, bs = 0, buffer, idx = 0;
      for (; (buffer = str.charAt(idx++)); ~buffer && (bs = bc % 4 ? bs * 64 + buffer : buffer, bc++ % 4)
        ? output += String.fromCharCode(255 & (bs >> ((-2 * bc) & 6))) : 0) {
        buffer = map.indexOf(buffer);
      }
      return output;
    };
  }
  if (typeof btoa === 'undefined') {
    globalThis.btoa = function(input) {
      var str = String(input), output = '', map = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
      for (var block, charCode, idx = 0; str.charAt(idx | 0) || (map = '=', idx % 1);
           output += map.charAt(63 & (block >> (8 - (idx % 1) * 8)))) {
        charCode = str.charCodeAt(idx += 3 / 4);
        if (charCode > 0xFF) throw new Error('InvalidCharacterError');
        block = (block << 8) | charCode;
      }
      return output;
    };
  }
  if (typeof TextEncoder === 'undefined') {
    globalThis.TextEncoder = function TextEncoder() {};
    TextEncoder.prototype.encode = function(str) {
      str = String(str);
      var out = [];
      for (var i = 0; i < str.length; i++) {
        var c = str.charCodeAt(i);
        if (c < 0x80) out.push(c);
        else if (c < 0x800) out.push(0xc0 | (c >> 6), 0x80 | (c & 0x3f));
        else out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f));
      }
      return new Uint8Array(out);
    };
  }
  globalThis.__engineRegistry = globalThis.__engineRegistry || {};
  globalThis.__engineFetchPending = {};
  globalThis.__engineFetchSeq = 0;
  globalThis.__engineFetchResolve = function(id, envelope){
    var p = globalThis.__engineFetchPending[id];
    if (p) { delete globalThis.__engineFetchPending[id]; p(envelope); }
  };
  globalThis.fetch = function(url, options){
    options = options || {};
    var method = (options.method || 'GET').toString().toUpperCase();
    var headers = options.headers || {};
    var bodyOut = '';
    if (options.body != null) {
      bodyOut = typeof options.body === 'string' ? options.body : String(options.body);
    }
    return new Promise(function(resolve){
      var id = ++globalThis.__engineFetchSeq;
      globalThis.__engineFetchPending[id] = function(env){
        var lowered = {};
        if (env.headers) for (var k in env.headers) if (Object.prototype.hasOwnProperty.call(env.headers, k)) lowered[String(k).toLowerCase()] = String(env.headers[k]);
        var body = env.body == null ? '' : String(env.body);
        var bodyB64 = env.bodyB64 == null ? '' : String(env.bodyB64);
        resolve({
          ok: !!env.ok,
          status: env.status | 0,
          statusText: env.statusText || '',
          url: env.url || url,
          _bodyB64: bodyB64,
          headers: { get: function(name){ return lowered[String(name).toLowerCase()] || null; } },
          text: function(){ return Promise.resolve(body); },
          json: function(){
            try { return Promise.resolve(body ? JSON.parse(body) : null); }
            catch (e) { return Promise.resolve(null); }
          },
          arrayBuffer: function(){
            if (bodyB64) {
              var bin = atob(bodyB64);
              var buf = new ArrayBuffer(bin.length);
              var view = new Uint8Array(buf);
              for (var i = 0; i < bin.length; i++) view[i] = bin.charCodeAt(i);
              return Promise.resolve(buf);
            }
            var buf = new ArrayBuffer(body.length);
            var view = new Uint8Array(buf);
            for (var i = 0; i < body.length; i++) view[i] = body.charCodeAt(i) & 0xff;
            return Promise.resolve(buf);
          }
        });
      };
      sendMessage('FetchStart', JSON.stringify({
        id: id, url: String(url), method: method, headers: headers, body: bodyOut
      }));
    });
  };
  globalThis.__engineTimers = globalThis.__engineTimers || {};
  globalThis.__engineTimerFire = function(id){
    var entry = globalThis.__engineTimers[id];
    if (!entry) return;
    if (!entry.repeat) delete globalThis.__engineTimers[id];
    try { entry.fn.apply(null, entry.args); } catch (e) {}
  };
  globalThis.setTimeout = function(fn, ms){
    var args = Array.prototype.slice.call(arguments, 2);
    var id = sendMessage('TimerSchedule', JSON.stringify({ms: ms|0, repeat: false}));
    globalThis.__engineTimers[id] = { fn: typeof fn === 'function' ? fn : function(){}, args: args, repeat: false };
    return id;
  };
  globalThis.setInterval = function(fn, ms){
    var args = Array.prototype.slice.call(arguments, 2);
    var id = sendMessage('TimerSchedule', JSON.stringify({ms: ms|0, repeat: true}));
    globalThis.__engineTimers[id] = { fn: typeof fn === 'function' ? fn : function(){}, args: args, repeat: true };
    return id;
  };
  globalThis.clearTimeout = function(id){
    delete globalThis.__engineTimers[id];
    sendMessage('TimerCancel', JSON.stringify({id: id|0}));
  };
  globalThis.clearInterval = globalThis.clearTimeout;
  globalThis.__engineHostPending = globalThis.__engineHostPending || {};
  globalThis.__engineHostSeq = globalThis.__engineHostSeq || 0;
  globalThis.__engineHostResolve = function(id, envelope){
    var p = globalThis.__engineHostPending[id];
    if (p) { delete globalThis.__engineHostPending[id]; p(envelope); }
  };
  globalThis.__engineHost = function(hostId){
    return new Promise(function(resolve){
      var id = ++globalThis.__engineHostSeq;
      globalThis.__engineHostPending[id] = function(env){
        resolve(env && env.streams ? env.streams : []);
      };
      sendMessage('HostStart', JSON.stringify({id: id, hostId: String(hostId)}));
    });
  };
  globalThis.__engineHopPending = globalThis.__engineHopPending || {};
  globalThis.__engineHopSeq = globalThis.__engineHopSeq || 0;
  globalThis.__engineHopResolve = function(id, envelope){
    var p = globalThis.__engineHopPending[id];
    if (p) { delete globalThis.__engineHopPending[id]; p(envelope); }
  };
  globalThis.__engineHop = function(url){
    return new Promise(function(resolve){
      var id = ++globalThis.__engineHopSeq;
      globalThis.__engineHopPending[id] = function(env){
        resolve(env && env.streams ? env.streams : []);
      };
      sendMessage('HopStart', JSON.stringify({id: id, url: String(url || '')}));
    });
  };
  globalThis.__engineHtml = function(html){
    var c = globalThis.__engineCheerio;
    if (!c || typeof c.load !== 'function') return null;
    return c.load(String(html == null ? '' : html));
  };
  globalThis.__engineUnpack = function(source){
    var s = String(source == null ? '' : source);
    var m = s.match(/eval\(function\(p,a,c,k,e,d\)\{[\s\S]*?\}\('((?:\\.|[^'])*)',(\d+),(\d+),'((?:\\.|[^'])*)'\.split\('\|'\)/);
    if (!m) m = s.match(/eval\(function\(p,a,c,k,e,r\)\{[\s\S]*?\}\('((?:\\.|[^'])*)',(\d+),(\d+),'((?:\\.|[^'])*)'\.split\('\|'\)/);
    if (!m) return s;
    var p = m[1].replace(/\\'/g, "'");
    var a = parseInt(m[2], 10);
    var c = parseInt(m[3], 10);
    var k = m[4].split('|');
    var d = function(n){
      var alphabet = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
      return n.toString(a);
    };
    while (c--) {
      if (k[c]) p = p.replace(new RegExp('\\b' + d(c) + '\\b', 'g'), k[c]);
    }
    return p;
  };
  if (typeof globalThis.queueMicrotask !== 'function') {
    globalThis.queueMicrotask = function(cb){ Promise.resolve().then(cb); };
  }
  function _engineLog(level, args){
    var parts = [];
    for (var i = 0; i < args.length; i++) {
      var a = args[i];
      if (a == null || typeof a === 'string') parts.push(String(a));
      else try { parts.push(JSON.stringify(a)); } catch (e) { parts.push(String(a)); }
    }
    sendMessage('Console', JSON.stringify({level: level, msg: parts.join(' ')}));
  }
  globalThis.console = {
    log: function(){ _engineLog('log', arguments); },
    info: function(){ _engineLog('info', arguments); },
    warn: function(){ _engineLog('warn', arguments); },
    error: function(){ _engineLog('err', arguments); },
    debug: function(){ _engineLog('log', arguments); },
  };
})();
''';
}
