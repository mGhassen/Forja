import 'dart:convert';
import 'dart:io';

import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

const _mfp =
    '{"base_url":"mfp.example","password":"pw","headers":{"Referer":"https://ref.example/"}}';

String _fixture(String name) =>
    File('${_repoRoot()}/crates/webstreamr/tests/fixtures/$name')
        .readAsStringSync();

String _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/crates/ffi').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  return Directory.current.parent.parent.path;
}

Map<String, dynamic> _embed(String id, String html, String pageUrl) {
  final json = RustLib.instance.extractEmbedHtmlJson(id, html, pageUrl);
  return jsonDecode(json) as Map<String, dynamic>;
}

Map<String, dynamic> _mfpEmbed(
  String id,
  String html,
  String pageUrl, {
  String extraHtml = '',
}) {
  final json = RustLib.instance.extractMfpEmbedHtmlJson(
    id,
    html,
    pageUrl,
    _mfp,
    extraHtml: extraHtml,
  );
  return jsonDecode(json) as Map<String, dynamic>;
}

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('streamembed golden via FFI', () {
    final m = _embed(
      'streamembed',
      _fixture('streamembed.html'),
      'https://bullstream.example/embed/xyz',
    );
    expect(m['url'], contains('/m3u8/abc123/deadbeef/master.txt'));
    expect(m['format'], 'hls');
    expect(m['title'], 'Test Movie');
    expect(m['height'], 720);
  });

  test('savefiles golden via FFI', () {
    final m = _embed(
      'savefiles',
      _fixture('savefiles.html'),
      'https://savefiles.example/v/1',
    );
    expect(m['url'], 'https://cdn.savefiles.example/playlist.m3u8');
    expect(m['title'], 'SaveFiles Title');
    expect(m['height'], 1080);
  });

  test('dropload golden via FFI', () {
    final m = _embed(
      'dropload',
      _fixture('dropload.html'),
      'https://dropload.example/x',
    );
    expect(m['url'], 'https://cdn.dropload.example/master.m3u8');
    expect(m['title'], 'Dropload Title');
    expect(m['request_headers'], isA<Map>());
  });

  test('supervideo golden via FFI', () {
    final m = _embed(
      'supervideo',
      _fixture('supervideo.html'),
      'https://supervideo.cc/e/1',
    );
    expect(m['url'], 'https://cdn.supervideo.example/master.m3u8');
    expect(m['title'], 'SuperVideo Title');
    expect(m['height'], 1080);
  });

  test('vidora golden via FFI', () {
    final m = _embed(
      'vidora',
      _fixture('vidora.html'),
      'https://vidora.example/embed/1',
    );
    expect(m['url'], 'https://cdn.vidora.example/stream.m3u8');
    expect(m['title'], 'Vidora Title');
    expect((m['request_headers'] as Map)['Origin'], 'https://vidora.example');
  });

  test('fsst golden via FFI', () {
    final m = _embed(
      'fsst',
      _fixture('fsst.html'),
      'https://fsst.example/v/1',
    );
    expect(m['url'], 'https://cdn.fsst.example/video.mp4');
    expect(m['format'], 'mp4');
    expect(m['title'], 'Fsst Movie');
    expect(m['height'], 1080);
    expect((m['request_headers'] as Map)['Referer'], 'https://fsst.example/');
    expect((m['request_headers'] as Map)['Origin'], 'https://fsst.example');
  });

  test('vixsrc embed golden via FFI', () {
    final m = _embed(
      'vixsrc',
      _fixture('vixsrc.html'),
      'https://vixsrc.example/embed/1',
    );
    expect(m['url'], contains('stream.vixsrc.example'));
    expect(m['url'], contains('.m3u8'));
    expect(m['url'], contains('token=abc123'));
    expect(m['format'], 'hls');
  });

  test('youtube golden via FFI', () {
    final m = _embed(
      'youtube',
      _fixture('youtube.html'),
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    );
    expect(m['yt_id'], 'dQw4w9WgXcQ');
    expect(m['title'], 'YouTube Title');
    expect(m['format'], 'unknown');
  });

  test('vidsrc chain golden via FFI', () {
    final json = RustLib.instance.extractVidsrcChainJson(
      _fixture('vidsrc_outer.html'),
      _fixture('vidsrc_rcp.html'),
      _fixture('vidsrc_prorcp.html'),
    );
    expect(json, contains('cloudorchestranova.com/hls/movie.m3u8'));
  });

  test('resolve_vidsrc_embed_json returns error for bad id', () {
    final raw = RustLib.instance.resolveVidsrcEmbedJson(
      jsonEncode({'tmdb_id': 0, 'is_movie': true}),
    );
    final m = jsonDecode(raw) as Map<String, dynamic>;
    expect(m['error'], isNotNull);
  });

  test('filemoon iframe redirect via FFI', () {
    final m = _embed(
      'filemoon',
      _fixture('filemoon_iframe.html'),
      'https://filemoon.example/d/1',
    );
    expect(m['next_url'], 'https://cdn.filemoon.example/embed/real');
  });

  test('hubdrive redirect via FFI', () {
    final m = _embed(
      'hubdrive',
      _fixture('hubdrive.html'),
      'https://hubdrive.example/x',
    );
    expect(m['next_url'], 'https://hubcloud.example/links/1');
  });

  test('rgshows JSON via FFI', () {
    final m = _embed(
      'rgshows',
      _fixture('rgshows.json'),
      'https://rgshows.example/api',
    );
    expect(m['url'], 'https://cdn.rgshows.example/master.m3u8');
    expect(m['format'], 'hls');
  });

  test('hubcloud redirect via FFI', () {
    final m = _embed(
      'hubcloud',
      _fixture('hubcloud_redirect.html'),
      'https://hubcloud.example/x',
    );
    expect(m['next_url'], 'https://hubcloud.example/links/abc123');
  });

  test('filelions embed redirect via FFI', () {
    final m = _embed(
      'filelions',
      _fixture('filelions_embed_only.html'),
      'https://filelions.example/f/abc',
    );
    expect(m['next_url'], 'https://filelions.example/v/abc');
  });

  test('voe redirect via FFI', () {
    final m = _embed(
      'voe',
      _fixture('voe_redirect.html'),
      'https://voe.example/start',
    );
    expect(m['next_url'], 'https://voe.example/final-page');
  });

  test('external golden via FFI', () {
    final m = _embed('external', '', 'https://example.com/page');
    expect(m['url'], 'https://example.com/page');
    expect(m['is_external'], isTrue);
  });

  test('kinoger golden via FFI', () {
    final m = _embed(
      'kinoger',
      _fixture('kinoger_encrypted.hex'),
      'https://kinoger.re/api/v1/video?id=x',
    );
    expect(m['url'], 'https://cdn.kinoger.example/stream.m3u8');
    expect(m['title'], 'KinoGer Title');
    expect(m['format'], 'hls');
  });

  test('unknown extractor returns error object', () {
    final m = _embed('mixdrop', '<html></html>', 'https://x');
    expect(m['error'], 'not_found');
  });

  test('hubcloud links golden via FFI', () {
    final json = RustLib.instance.extractHubcloudLinksJson(
      _fixture('hubcloud_links.html'),
      'https://hubcloud.example/origin',
    );
    final rows = jsonDecode(json) as List<dynamic>;
    expect(rows.length, 3);
    expect(rows[0]['url'], 'https://fsl.example/stream/1');
    expect(rows[0]['label'], 'HubCloud (FSL)');
    expect(rows[0]['meta_extractor_id'], 'hubcloud_fsl');
    expect(rows[0]['height'], 1080);
    expect(rows[2]['url'], 'https://pixel.example/api/file/abc?download=');
  });

  test('mixdrop MFP golden via FFI', () {
    final m = _mfpEmbed(
      'mixdrop',
      _fixture('mixdrop.html'),
      'https://mixdrop.example/e/abc',
    );
    expect(m['url'], contains('host=Mixdrop'));
    expect(m['url'], contains('redirect_stream=true'));
    expect(m['title'], 'Mixdrop Title');
    expect(m['format'], 'mp4');
    expect(m['bytes'], 1610612736);
  });

  test('streamtape MFP golden via FFI', () {
    final m = _mfpEmbed(
      'streamtape',
      _fixture('streamtape.html'),
      'https://streamtape.example/v/abc',
    );
    expect(m['url'], contains('host=Streamtape'));
    expect(m['title'], 'Streamtape Title');
    expect(m['bytes'], 1288490189);
  });

  test('uqload MFP golden via FFI', () {
    final m = _mfpEmbed(
      'uqload',
      _fixture('uqload.html'),
      'https://uqload.example/embed-xyz',
    );
    expect(m['url'], contains('host=Uqload'));
    expect(m['title'], 'Uqload Title');
    expect(m['height'], 1080);
  });

  test('doodstream MFP golden via FFI', () {
    final m = _mfpEmbed(
      'doodstream',
      _fixture('doodstream_embed.html'),
      'http://dood.to/e/abc',
      extraHtml: _fixture('doodstream_download.html'),
    );
    expect(m['url'], contains('host=Doodstream'));
    expect(m['title'], 'Movie Name');
    expect(m['bytes'], 1932735283);
  });

  test('get_streams_json returns stremio-shaped array', () {
    final req = jsonEncode({
      'imdb_id': 'tt0944947',
      'tmdb_id': 1399,
      'media_type': 'series',
      'season': 1,
      'episode': 1,
      'enabled_sources': ['vidsrc'],
      'config': {'multi': 'on'},
    });
    final raw = RustLib.instance.webstreamrGetStreamsJson(req);
    final decoded = jsonDecode(raw);
    expect(decoded, isA<List>());
  });
}
