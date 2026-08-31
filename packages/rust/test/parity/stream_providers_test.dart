import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  tearDown(() {
    RustLib.instance.setProviderRuntimeOverlay(
      jsonEncode({'schema': 1, 'templates': {}}),
    );
  });

  const tmdbId = 550;

  test('legacy embed ids return empty without overlay', () {
    RustLib.instance.setProviderRuntimeOverlay(
      jsonEncode({'schema': 1, 'templates': {}}),
    );
    for (final id in ['vidlink', 'vidsrc', 'videasy', 'vixsrc']) {
      expect(RustLib.instance.buildMovieUrl(id, tmdbId), '');
    }
  });

  test('overlay template expands movie URL', () {
    RustLib.instance.setProviderRuntimeOverlay(
      jsonEncode({
        'schema': 1,
        'templates': {
          'vidlink': {'movie': 'https://ops.test/movie/{tmdb}'},
        },
      }),
    );
    expect(
      RustLib.instance.buildMovieUrl('vidlink', tmdbId),
      'https://ops.test/movie/550',
    );
  });

  test('listProvidersJson is empty without builtins', () {
    final rows =
        (jsonDecode(RustLib.instance.listProvidersJson()) as List)
            .cast<Map<String, dynamic>>();
    expect(rows, isEmpty);
  });
}
