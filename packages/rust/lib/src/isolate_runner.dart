import 'dart:async';
import 'dart:isolate';

import 'engine.dart';
import 'library_path.dart';

/// Runs sync Rust FFI on a worker isolate so the UI isolate stays responsive.
Future<T> runRustIsolate<T>(
  FutureOr<T> Function() fn, {
  String? libraryPath,
}) {
  final path = libraryPath ??
      RustLib.loadedLibraryPath ??
      firstExistingRustLibrary();
  if (path == null) {
    return Future.error(
      StateError(
        'Rust library path unknown — call Engine.init() on the main isolate first',
      ),
    );
  }
  return Isolate.run(() async {
    RustLib.initSync(path);
    return fn();
  });
}

// ── WebStreamr ──────────────────────────────────────────────────────────────

Future<String> runWebstreamrGetStreamsJson(String requestJson) =>
    runRustIsolate(
      () => RustLib.instance.webstreamrGetStreamsJson(requestJson),
    );

// ── Stremio ─────────────────────────────────────────────────────────────────

Future<String> runStremioHttpGet(String url, {int timeoutSecs = 15}) =>
    runRustIsolate(
      () => RustLib.instance.stremioHttpGet(url, timeoutSecs: timeoutSecs),
    );

// ── Stream extractors ───────────────────────────────────────────────────────

Future<String> runResolveVidsrcEmbedJson(String requestJson) =>
    runRustIsolate(
      () => RustLib.instance.resolveVidsrcEmbedJson(requestJson),
    );

Future<String> runOpensslAesDecryptJson(
  String intermediate, {
  String passphrase = '',
}) =>
    runRustIsolate(
      () => RustLib.instance.opensslAesDecryptJson(
        intermediate,
        passphrase: passphrase,
      ),
    );

// ── Torrent search / filter ─────────────────────────────────────────────────

Future<String> runSearchTorrentsJson(String query) => runRustIsolate(
      () => RustLib.instance.searchTorrentsJson(query),
    );

Future<String> runFilterTorrentsJson(
  String resultsJson,
  String showTitle, {
  int requiredSeason = -1,
  int requiredEpisode = -1,
}) =>
    runRustIsolate(
      () => RustLib.instance.filterTorrentsJson(
        resultsJson,
        showTitle,
        requiredSeason: requiredSeason,
        requiredEpisode: requiredEpisode,
      ),
    );

Future<String> runSortTorrentsJson(String resultsJson, String preference) =>
    runRustIsolate(
      () => RustLib.instance.sortTorrentsJson(resultsJson, preference),
    );

// ── Parsers / decrypt ───────────────────────────────────────────────────────

Future<String> runParseM3uJson(String content) => runRustIsolate(
      () => RustLib.instance.parseM3uJson(content),
    );

Future<String> runParseHlsMasterJson(String masterUrl, String body) =>
    runRustIsolate(
      () => RustLib.instance.parseHlsMasterJson(masterUrl, body),
    );

Future<String> runDecryptKisskhBody(String body, {String? sourceUrl}) =>
    runRustIsolate(
      () => RustLib.instance.decryptKisskhBody(body, sourceUrl: sourceUrl),
    );
