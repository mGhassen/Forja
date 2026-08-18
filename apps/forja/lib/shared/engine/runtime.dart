import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:forja/shared/extractors/core/stream_crypto.dart';
import 'package:http/http.dart' as http;

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

  int _timerSeq = 0;
  final Map<int, Timer> _activeTimers = {};

  http.Client _http = http.Client();

  Future<void> _ensureInit() async {
    if (_ready) return;
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();
    try {
      final rt = getJavascriptRuntime(
        xhr: false,
        extraArgs: const {'stackSize': 2 * 1024 * 1024},
      );
      _runtime = rt;
      _registerBridges(rt);
      _installHost(rt);
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
        final m = _bridgeMap(args);
        debugPrint('[engine:${m['level'] ?? 'log'}] ${m['msg'] ?? ''}');
      } catch (_) {}
      return null;
    });

    br('StreamCryptoDecrypt', (args) {
      try {
        final m = _bridgeMap(args);
        return StreamCrypto.decrypt(
          (m['body'] ?? '').toString(),
          (m['seed'] ?? '').toString(),
          (m['tmdbId'] ?? '').toString(),
        );
      } catch (e) {
        return 'ENGINE_DECRYPT_ERROR:${e.toString()}';
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
        unawaited(_dispatchFetch(
          id: id,
          url: url,
          method: method,
          headers: headers,
          body: body,
          gen: gen,
        ));
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
    if (rt == null) return;
    if (!repeat) _activeTimers.remove(id);
    try {
      rt.evaluate(
        'try { globalThis.__engineTimerFire($id); } catch (e) {}',
        sourceUrl: 'engine://timer/$id',
      );
    } catch (_) {}
  }

  void _installHost(JavascriptRuntime rt) {
    final res = rt.evaluate(_hostJs, sourceUrl: 'engine://host');
    if (res.isError) {
      throw StateError('engine host failed: ${res.stringResult}');
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

  void _loadPluginUnlocked(String pluginId, String code) {
    final rt = _runtime!;
    final wrapped = '''
(function(){
  var module = { exports: {} };
  var exports = module.exports;
  globalThis.extract = undefined;
  try {
    $code
    if (typeof extract === 'function') {
      if (typeof module.exports.extract !== 'function') module.exports.extract = extract;
      if (typeof globalThis.extract !== 'function') globalThis.extract = extract;
    }
  } catch (e) {
    sendMessage('Console', JSON.stringify({level:'error',msg:'[engine load $pluginId] ' + (e && e.message ? e.message : e)}));
    throw e;
  }
  var fn = (module.exports && module.exports.extract) || globalThis.extract;
  globalThis.__engineRegistry[${jsonEncode(pluginId)}] = { extract: fn };
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
    required String tmdbId,
    required String type,
    int? season,
    int? episode,
    String? title,
    String? year,
    Duration timeout = const Duration(seconds: 30),
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
        tmdbId: tmdbId,
        type: type,
        season: season,
        episode: episode,
        title: title,
        year: year,
        timeout: timeout,
        isCancelled: isCancelled,
      );
    });
  }

  Future<List<Map<String, dynamic>>> _extractUnlocked({
    required String pluginId,
    required String tmdbId,
    required String type,
    int? season,
    int? episode,
    String? title,
    String? year,
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
        'tmdbId': tmdbId,
        'type': type == 'tv' || type == 'series' ? 'tv' : 'movie',
        'season': season ?? 1,
        'episode': episode ?? 1,
        'title': title ?? '',
        'year': year ?? '',
      });
      final invoker = '''
(function(){
  var entry = globalThis.__engineRegistry[${jsonEncode(pluginId)}];
  var fn = entry && entry.extract;
  if (typeof fn !== 'function') {
    sendMessage('CaptureResult', JSON.stringify({id:$callId, body:'[]'}));
    return;
  }
  var meta = $ctx;
  var ctx = {
    tmdbId: meta.tmdbId,
    type: meta.type,
    season: meta.season,
    episode: meta.episode,
    title: meta.title,
    year: meta.year,
    fetch: globalThis.fetch,
    streamcrypto: {
      decrypt: function(body, seed, tmdbId) {
        var out = sendMessage('StreamCryptoDecrypt', JSON.stringify({
          body: String(body == null ? '' : body),
          seed: String(seed == null ? '' : seed),
          tmdbId: String(tmdbId == null ? '' : tmdbId)
        }));
        if (typeof out === 'string' && out.indexOf('ENGINE_DECRYPT_ERROR:') === 0) {
          throw new Error(out.substring('ENGINE_DECRYPT_ERROR:'.length));
        }
        return out;
      }
    }
  };
  Promise.resolve()
    .then(function(){ return fn(ctx); })
    .then(function(r){
      try { sendMessage('CaptureResult', JSON.stringify({id:$callId, body: JSON.stringify(r == null ? [] : r)})); }
      catch (e) { sendMessage('CaptureResult', JSON.stringify({id:$callId, body:'[]'})); }
    })
    .catch(function(e){
      var msg = (e && e.message) ? e.message : (e ? String(e) : 'unknown');
      sendMessage('Console', JSON.stringify({level:'error',msg:'[engine extract $pluginId] '+msg}));
      sendMessage('CaptureResult', JSON.stringify({id:$callId, body:'[]'}));
    });
})();
''';
      final r = rt.evaluate(invoker);
      if (r.isError) {
        _pendingResults.remove(callId);
        debugPrint('[engine] invoker error: ${r.stringResult}');
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
        try {
          rt.executePendingJob();
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 8));
      }
      if (!completer.isCompleted) {
        _pendingResults.remove(callId);
        if (!completer.isCompleted) completer.complete('[]');
        debugPrint('[engine] $pluginId timed out after ${timeout.inSeconds}s');
        return [];
      }

      final body = (await completer.future).trim();
      if (isCancelled?.call() == true) return [];
      if (body.isEmpty || body == 'null' || body == 'undefined') return [];
      try {
        final decoded = jsonDecode(body);
        if (decoded is! List) return [];
        return decoded
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      } catch (e) {
        debugPrint('[engine] result parse failed ($pluginId): $e');
        return [];
      }
    } finally {
      _pendingResults.remove(callId);
      _activeExtract = (_activeExtract - 1).clamp(0, 1 << 30);
      if (_activeExtract <= 0) _acceptingFetches = false;
    }
  }

  void abortPendingWork() {
    final hadWork = _acceptingFetches ||
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
    if (hadWork) _dropRuntime();
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
      if (body.isNotEmpty &&
          method != 'GET' &&
          method != 'HEAD' &&
          method != 'OPTIONS') {
        req.body = body;
      }
      final streamed =
          await _http.send(req).timeout(const Duration(seconds: 25));
      if (gen != _fetchGeneration) {
        _fetchGens.remove(id);
        return;
      }
      final bytes = await streamed.stream.toBytes();
      if (gen != _fetchGeneration) {
        _fetchGens.remove(id);
        return;
      }
      var text = utf8.decode(bytes, allowMalformed: true);
      const maxLen = 1024 * 1024;
      if (text.length > maxLen) text = text.substring(0, maxLen);
      final respHeaders = <String, dynamic>{};
      streamed.headers.forEach((k, v) => respHeaders[k.toLowerCase()] = v);
      envelope = {
        'ok': streamed.statusCode >= 200 && streamed.statusCode < 300,
        'status': streamed.statusCode,
        'statusText': streamed.reasonPhrase ?? '',
        'url': streamed.request?.url.toString() ?? url,
        'body': text,
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
    if (rt == null) return;
    try {
      rt.evaluate(
        'try { globalThis.__engineFetchResolve($id, ${jsonEncode(envelope)}); } catch (e) {}',
        sourceUrl: 'engine://fetch/$id',
      );
    } catch (_) {}
  }

  static const _hostJs = r'''
(function(){
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
        resolve({
          ok: !!env.ok,
          status: env.status | 0,
          statusText: env.statusText || '',
          url: env.url || url,
          headers: { get: function(name){ return lowered[String(name).toLowerCase()] || null; } },
          text: function(){ return Promise.resolve(body); },
          json: function(){
            try { return Promise.resolve(body ? JSON.parse(body) : null); }
            catch (e) { return Promise.resolve(null); }
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
  if (typeof globalThis.queueMicrotask !== 'function') {
    globalThis.queueMicrotask = function(cb){ Promise.resolve().then(cb); };
  }
})();
''';
}
