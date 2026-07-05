import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:forja_rust/forja_rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('vixsrc source movie via FFI', () {
    final json = ForjaRust.instance.resolveWebstreamrSourceJson(
      'vixsrc',
      jsonEncode({
        'tmdb_id': 550,
        'media_type': 'movie',
        'title': 'Fight Club',
        'year': 1999,
      }),
    );
    final rows = jsonDecode(json) as List<dynamic>;
    expect(rows.length, 1);
    expect(rows[0]['url'], 'https://vixsrc.to/movie/550');
    expect(rows[0]['title'], 'Fight Club (1999)');
  });

  test('vidsrc source series imdb via FFI', () {
    final json = ForjaRust.instance.resolveWebstreamrSourceJson(
      'vidsrc',
      jsonEncode({
        'imdb_id': 'tt0944947',
        'media_type': 'series',
        'season': 1,
        'episode': 1,
      }),
    );
    final rows = jsonDecode(json) as List<dynamic>;
    expect(rows[0]['url'], 'https://vidsrc-embed.ru/embed/tv/tt0944947/1-1');
  });
}
