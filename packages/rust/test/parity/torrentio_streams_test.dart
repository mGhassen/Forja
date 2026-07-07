import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('Rust HTTP + parse returns Toy Story 5 streams', () {
    const url =
        'https://torrentio.strem.fun/stream/movie/tt29355505.json';
    final raw = RustLib.instance.stremioHttpGet(url, timeoutSecs: 15);
    final http = jsonDecode(raw) as Map<String, dynamic>;
    expect(http.containsKey('error'), isFalse, reason: raw);
    expect(http['status'], 200);

    final parsedJson =
        RustLib.instance.parseStremioStreamsJson(http['body'] as String);
    final parsed = jsonDecode(parsedJson) as Map<String, dynamic>;
    expect(parsed.containsKey('error'), isFalse, reason: parsedJson);
    final streams = parsed['streams'] as List<dynamic>;
    expect(streams, isNotEmpty);
  });

  test('buildResourceUrl for installed torrentio base', () {
    const base = 'https://torrentio.strem.fun';
    const path = '/stream/movie/tt29355505.json';
    expect(
      RustLib.instance.buildStremioResourceUrl(base, path),
      'https://torrentio.strem.fun/stream/movie/tt29355505.json',
    );
  });
}
