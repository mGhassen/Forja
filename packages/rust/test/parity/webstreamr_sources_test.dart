import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

List<dynamic> _resolve(String sourceId, Map<String, dynamic> req) {
  final json = ForjaRust.instance.resolveWebstreamrSourceJson(
    sourceId,
    jsonEncode(req),
  );
  return jsonDecode(json) as List<dynamic>;
}

List<dynamic> _parseHtml(String sourceId, String html, String contextJson) {
  final json = ForjaRust.instance.parseWebstreamrSourceHtmlJson(
    sourceId,
    html,
    contextJson,
  );
  return jsonDecode(json) as List<dynamic>;
}

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('vidsrc source movie tmdb via FFI', () {
    final rows = _resolve('vidsrc', {
      'tmdb_id': 550,
      'media_type': 'movie',
    });
    expect(rows[0]['url'], 'https://vidsrc-embed.ru/embed/movie/550');
    expect(rows[0]['country_codes'], ['multi']);
  });

  test('vidsrc source series imdb via FFI', () {
    final rows = _resolve('vidsrc', {
      'imdb_id': 'tt0944947',
      'media_type': 'series',
      'season': 1,
      'episode': 1,
    });
    expect(rows[0]['url'], 'https://vidsrc-embed.ru/embed/tv/tt0944947/1-1');
  });

  test('vixsrc source movie via FFI', () {
    final rows = _resolve('vixsrc', {
      'tmdb_id': 550,
      'media_type': 'movie',
      'title': 'Fight Club',
      'year': 1999,
    });
    expect(rows[0]['url'], 'https://vixsrc.to/movie/550');
    expect(rows[0]['title'], 'Fight Club (1999)');
    expect(rows[0]['priority'], 1);
  });

  test('rgshows source series via FFI', () {
    final rows = _resolve('rgshows', {
      'tmdb_id': 1399,
      'media_type': 'series',
      'season': 2,
      'episode': 5,
      'title': 'Game of Thrones',
      'year': 2011,
    });
    expect(rows[0]['url'], 'https://api.rgshows.ru/main/tv/1399/2/5');
    expect(rows[0]['title'], 'Game of Thrones S02E05');
    expect(rows[0]['priority'], -1);
  });

  test('meinecloud HTML parse via FFI', () {
    const html = '<div data-link="//embed.example/a"></div>';
    final rows = _parseHtml('meinecloud', html, '{"referer":"https://meinecloud.click"}');
    expect(rows[0]['url'], 'https://embed.example/a');
    expect(rows[0]['country_codes'], ['de']);
  });

  test('verhdlink HTML parse via FFI', () {
    const html =
        '<div class="_player-mirrors latino"><a data-link="https://cdn.example/lat"></a></div>';
    final rows = _parseHtml('verhdlink', html, '{"referer":"https://verhdlink.cam"}');
    expect(rows[0]['country_codes'], ['mx']);
  });

  test('megakino HTML parse via FFI', () {
    const html =
        '<meta property="og:title" content="Film"><div class="video-inside"><iframe src="https://embed.example/x"></iframe></div>';
    final rows =
        _parseHtml('megakino', html, '{"referer":"https://megakino.example/p"}');
    expect(rows[0]['url'], 'https://embed.example/x');
    expect(rows[0]['title'], 'Film');
  });

  test('homecine HTML parse via FFI', () {
    const html =
        '<div class="les-content"><a>Latino<iframe src="https://embed.example/lat"></iframe></a></div>';
    final rows = _parseHtml(
      'homecine',
      html,
      '{"referer":"https://homecine.example/p","title":"Film (2020)"}',
    );
    expect(rows[0]['url'], 'https://embed.example/lat');
    expect(rows[0]['country_codes'], ['mx']);
    expect(rows[0]['title'], 'Film (2020)');
  });

  test('mostraguarda HTML parse via FFI', () {
    const html = '<div data-link="https://embed.example/a"></div>';
    final rows =
        _parseHtml('mostraguarda', html, '{"referer":"https://mostraguarda.stream"}');
    expect(rows[0]['url'], 'https://embed.example/a');
    expect(rows[0]['country_codes'], ['it']);
  });

  test('eurostreaming HTML parse via FFI', () {
    const html =
        '<div><span data-num="2x3"></span><div class="mirrors"><a data-link="https://embed.example/it"></a></div></div>';
    final rows = _parseHtml(
      'eurostreaming',
      html,
      '{"referer":"https://eurostreaming.luxe/p","title":"Show S02E03","season":2,"episode":3}',
    );
    expect(rows[0]['url'], 'https://embed.example/it');
    expect(rows[0]['country_codes'], ['it']);
  });

  test('cinehdplus HTML parse via FFI', () {
    const html = '''
<meta property="og:title" content="Show">
<div class="details__langs">Latino</div>
<div><span data-num="1x1"></span><div class="mirrors"><a data-link="//embed.example/lat"></a></div></div>
''';
    final rows = _parseHtml(
      'cinehdplus',
      html,
      '{"referer":"https://cinehdplus.gratis/p","season":1,"episode":1}',
    );
    expect(rows[0]['url'], 'https://embed.example/lat');
    expect(rows[0]['country_codes'], ['mx']);
    expect(rows[0]['title'], 'Show S01E01');
  });

  test('streamkiste HTML parse via FFI', () {
    const html = '''
<meta property="og:title" content="Serie">
<div><span data-num="3x4"></span><div class="mirrors"><a data-link="//embed.example/de"></a></div></div>
''';
    final rows = _parseHtml(
      'streamkiste',
      html,
      '{"referer":"https://streamkiste.taxi/p","season":3,"episode":4}',
    );
    expect(rows[0]['url'], 'https://embed.example/de');
    expect(rows[0]['country_codes'], ['de']);
    expect(rows[0]['title'], 'Serie S03E04');
  });

  test('frenchcloud HTML parse via FFI', () {
    const html = '<div data-link="//embed.example/fr"></div>';
    final rows = _parseHtml('frenchcloud', html, '{"referer":"https://frenchcloud.cam"}');
    expect(rows[0]['url'], 'https://embed.example/fr');
    expect(rows[0]['country_codes'], ['fr']);
  });

  test('cuevana HTML parse via FFI', () {
    const html =
        '<div class="open_submenu">Español Latino<a data-tr="https://embed.example/lat"></a></div>';
    final rows = _parseHtml(
      'cuevana',
      html,
      '{"referer":"https://cuevana.example/p","title":"Film S01E01"}',
    );
    expect(rows[0]['url'], 'https://embed.example/lat');
    expect(rows[0]['country_codes'], ['mx']);
  });

  test('hdhub4u HTML parse via FFI', () {
    const html = '<a href="https://hubdrive.example/dl">Download</a>';
    final rows = _parseHtml(
      'hdhub4u',
      html,
      '{"referer":"https://hdhub4u.example/p","country_codes":["hi","multi"]}',
    );
    expect(rows[0]['url'], 'https://hubdrive.example/dl');
  });

  test('einschalten JSON parse via FFI', () {
    const body =
        '{"streamUrl":"https://cdn.example/movie.m3u8","releaseName":"Film"}';
    final rows = _parseHtml(
      'einschalten',
      body,
      '{"referer":"https://einschalten.in/movies/123"}',
    );
    expect(rows[0]['url'], 'https://cdn.example/movie.m3u8');
    expect(rows[0]['country_codes'], ['de']);
  });

  test('movix JSON parse via FFI', () {
    const body =
        '{"player_links":[{"decoded_url":"https://embed.example/a"}],"tmdb_details":{"title":"Film"}}';
    final rows = _parseHtml(
      'movix',
      body,
      '{"referer":"https://api.movix.site","is_series":false,"year":2020}',
    );
    expect(rows[0]['url'], 'https://embed.example/a');
    expect(rows[0]['title'], 'Film (2020)');
  });

  test('frembed JSON parse via FFI', () {
    const body = '{"title":"Film","link1":"/embed/a"}';
    final rows = _parseHtml(
      'frembed',
      body,
      '{"referer":"https://frembed.work","is_series":false,"year":2020}',
    );
    expect(rows[0]['url'], 'https://frembed.work/embed/a');
  });

  test('kokoshka page parse via FFI', () {
    const html =
        '<div class="dooplay_player_option" data-post="1" data-type="movie" data-nume="0"></div>';
    final rows = _parseHtml(
      'kokoshka',
      html,
      '{"referer":"https://kokoshka.digital/p","base_url":"https://kokoshka.digital"}',
    );
    expect(rows[0]['url'], contains('/wp-json/dooplayer/v2/'));
  });

  test('4khdhub HTML parse via FFI', () {
    const html =
        '<div class="download-item"><span class="file-title">Film</span> Hindi 1080p <a href="https://hubcloud.example/x">HubCloud</a></div>';
    final rows = _parseHtml(
      '4khdhub',
      html,
      '{"referer":"https://4khdhub.example/p","is_series":false}',
    );
    expect(rows[0]['url'], 'https://hubcloud.example/x');
    expect(rows[0]['height'], 1080);
  });

  test('vegamovies HTML parse via FFI', () {
    const html = '<a href="https://vcloud.example/a.zip">DL</a>';
    final rows = _parseHtml(
      'vegamovies',
      html,
      '{"referer":"https://nexdrive.example/p","title":"1080p"}',
    );
    expect(rows[0]['url'], 'https://vcloud.example/a.zip');
    expect(rows[0]['height'], 1080);
  });

  test('kinoger show.js episode URLs via FFI', () {
    const html =
        r'<script>$(".ep").show([["https://cdn.example/ep1.m3u8","x"],["https://cdn.example/s2e1.m3u8"]])</script>';
    final json = ForjaRust.instance.extractKinogerEpisodeUrlsJson(html, 1, 0);
    final urls = jsonDecode(json) as List<dynamic>;
    expect(urls, ['https://cdn.example/s2e1.m3u8']);
  });
}
