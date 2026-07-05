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

  test('meinecloud HTML parse via FFI', () {
    const html = '<div data-link="https://embed.example/stream"></div>';
    final json = ForjaRust.instance.parseWebstreamrSourceHtmlJson(
      'meinecloud',
      html,
      '{"referer":"https://meinecloud.click"}',
    );
    final rows = jsonDecode(json) as List<dynamic>;
    expect(rows[0]['url'], 'https://embed.example/stream');
    expect(rows[0]['country_codes'], ['de']);
  });

  test('homecine HTML parse via FFI', () {
    const html =
        '<div class="les-content"><a>Latino<iframe src="https://embed.example/lat"></iframe></a></div>';
    final json = ForjaRust.instance.parseWebstreamrSourceHtmlJson(
      'homecine',
      html,
      '{"referer":"https://homecine.example/p","title":"Film (2020)"}',
    );
    final rows = jsonDecode(json) as List<dynamic>;
    expect(rows[0]['url'], 'https://embed.example/lat');
    expect(rows[0]['country_codes'], ['mx']);
    expect(rows[0]['title'], 'Film (2020)');
  });

  test('mostraguarda HTML parse via FFI', () {
    const html = '<div data-link="https://embed.example/it"></div>';
    final json = ForjaRust.instance.parseWebstreamrSourceHtmlJson(
      'mostraguarda',
      html,
      '{"referer":"https://mostraguarda.stream"}',
    );
    final rows = jsonDecode(json) as List<dynamic>;
    expect(rows[0]['url'], 'https://embed.example/it');
    expect(rows[0]['country_codes'], ['it']);
  });

  test('streamkiste HTML parse via FFI', () {
    const html =
        '<meta property="og:title" content="Serie"><div><span data-num="1x2"></span><div class="mirrors"><a data-link="https://embed.example/de"></a></div></div>';
    final json = ForjaRust.instance.parseWebstreamrSourceHtmlJson(
      'streamkiste',
      html,
      '{"referer":"https://streamkiste.taxi/p","season":1,"episode":2}',
    );
    final rows = jsonDecode(json) as List<dynamic>;
    expect(rows[0]['url'], 'https://embed.example/de');
    expect(rows[0]['title'], 'Serie S01E02');
  });

  test('einschalten JSON parse via FFI', () {
    const body =
        '{"streamUrl":"https://cdn.example/movie.m3u8","releaseName":"Film"}';
    final json = ForjaRust.instance.parseWebstreamrSourceHtmlJson(
      'einschalten',
      body,
      '{"referer":"https://einschalten.in/movies/123"}',
    );
    final rows = jsonDecode(json) as List<dynamic>;
    expect(rows[0]['url'], 'https://cdn.example/movie.m3u8');
    expect(rows[0]['country_codes'], ['de']);
  });

  test('movix JSON parse via FFI', () {
    const body =
        '{"player_links":[{"decoded_url":"https://embed.example/a"}],"tmdb_details":{"title":"Film"}}';
    final json = ForjaRust.instance.parseWebstreamrSourceHtmlJson(
      'movix',
      body,
      '{"referer":"https://api.movix.site","is_series":false,"year":2020}',
    );
    final rows = jsonDecode(json) as List<dynamic>;
    expect(rows[0]['url'], 'https://embed.example/a');
    expect(rows[0]['title'], 'Film (2020)');
  });
}
