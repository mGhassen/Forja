// Thin Dart wrapper around the Rust seek111477 local proxy (crates/proxy).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path_provider/path_provider.dart';
import 'package:rust/rust.dart';

import '../../library_path.dart';

Future<void>? _stopFuture;

/// Serializes concurrent [start111477Proxy] calls (double-tap / failover).
Future<void> _startChain = Future<void>.value();

/// When true, [stop111477Proxy] is a no-op so an external player can keep
/// reading the localhost seek proxy after the built-in player disposes.
bool retainForExternalHandoff = false;

bool is111477UpstreamUrl(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  return host.contains('111477');
}

bool is111477LocalProxyUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (uri.host != '127.0.0.1' && uri.host != 'localhost') return false;
  final proxyPort = site111477ProxyPort;
  return proxyPort > 0 && uri.port == proxyPort;
}

/// Starts the seek proxy on a one-shot isolate — not subject to
/// [Engine.cancelPendingResolve] aborting in-flight EngineJobs.
Future<String> _seek111477StartIsolated(String requestJson) {
  final libraryPath =
      RustLib.loadedLibraryPath ?? firstExistingRustLibrary();
  if (libraryPath == null) {
    throw StateError('Rust library not loaded');
  }
  return Isolate.run(() {
    RustLib.initSync(libraryPath);
    return RustLib.instance.seek111477StartJson(requestJson);
  });
}

Future<String> _start111477ProxyImpl(
  String upstreamUrl, {
  Map<String, String>? headers,
}) async {
  if (_stopFuture != null) {
    try {
      await _stopFuture!.timeout(const Duration(seconds: 12));
    } catch (_) {
      _stopFuture = null;
    }
  }
  if (is111477ProxyRunning) {
    await stop111477Proxy();
  }

  final tmp = await getTemporaryDirectory();
  final cacheDir = '${tmp.path}${Platform.pathSeparator}site111477_cache';

  final raw = await _seek111477StartIsolated(
    jsonEncode({
      'upstream_url': upstreamUrl,
      'headers': headers ?? <String, String>{},
      'cache_dir': cacheDir,
    }),
  );

  final map = jsonDecode(raw) as Map<String, dynamic>;
  final error = map['error'] as String?;
  if (error != null) {
    throw StateError('111477 proxy: $error');
  }
  final url = map['url'] as String?;
  if (url == null || url.isEmpty) {
    throw StateError('111477 proxy: no url in response');
  }
  return url;
}

Future<String> start111477Proxy(
  String upstreamUrl, {
  Map<String, String>? headers,
}) async {
  late final String proxiedUrl;
  final task = _startChain.then((_) async {
    proxiedUrl = await _start111477ProxyImpl(
      upstreamUrl,
      headers: headers,
    );
  });
  _startChain = task.catchError((_) {});
  await task;
  return proxiedUrl;
}

int get site111477ProxyPort => RustLib.instance.seek111477Port();

String? get site111477ProxyUrl {
  final port = site111477ProxyPort;
  return port == 0 ? null : 'http://127.0.0.1:$port/';
}

Future<void> stop111477Proxy({bool force = false}) async {
  if (retainForExternalHandoff && !force) return;
  if (_stopFuture != null) return _stopFuture;
  if (!is111477ProxyRunning) return;
  final c = Completer<void>();
  _stopFuture = c.future;
  try {
    RustLib.instance.seek111477Stop();
  } finally {
    c.complete();
    _stopFuture = null;
  }
}

bool get is111477ProxyRunning =>
    RustLib.instance.seek111477IsRunning() || _stopFuture != null;

Future<void> purge111477Cache() async {
  try {
    final tmp = await getTemporaryDirectory();
    final dirPath = '${tmp.path}${Platform.pathSeparator}site111477_cache';
    RustLib.instance.seek111477PurgeCacheJson(dirPath);
  } catch (_) {}
}
