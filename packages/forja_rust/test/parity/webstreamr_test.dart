import 'dart:convert';
import 'dart:io';

import '../helpers/rust_engine.dart';
import 'package:forja_rust/forja_rust.dart';
import 'package:flutter_test/flutter_test.dart';

String _fixture(String name) =>
    File('${_repoRoot()}/crates/forja-webstreamr/tests/fixtures/$name')
        .readAsStringSync();

String _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/crates/forja-ffi').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  return Directory.current.parent.parent.path;
}

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('streamembed golden via FFI', () {
    final html = _fixture('streamembed.html');
    final json = ForjaRust.instance.extractEmbedHtmlJson(
      'streamembed',
      html,
      'https://bullstream.example/embed/xyz',
    );
    final m = jsonDecode(json) as Map<String, dynamic>;
    expect(m['url'], contains('/m3u8/abc123/deadbeef/master.txt'));
    expect(m['format'], 'hls');
    expect(m['title'], 'Test Movie');
    expect(m['height'], 720);
  });

  test('savefiles golden via FFI', () {
    final html = _fixture('savefiles.html');
    final json = ForjaRust.instance.extractEmbedHtmlJson(
      'savefiles',
      html,
      'https://savefiles.example/v/1',
    );
    final m = jsonDecode(json) as Map<String, dynamic>;
    expect(m['url'], 'https://cdn.savefiles.example/playlist.m3u8');
    expect(m['height'], 1080);
  });

  test('dropload golden via FFI', () {
    final html = _fixture('dropload.html');
    final json = ForjaRust.instance.extractEmbedHtmlJson(
      'dropload',
      html,
      'https://dropload.example/x',
    );
    final m = jsonDecode(json) as Map<String, dynamic>;
    expect(m['url'], 'https://cdn.dropload.example/master.m3u8');
    expect(m['request_headers'], isA<Map>());
  });

  test('unknown extractor returns error object', () {
    final json = ForjaRust.instance.extractEmbedHtmlJson(
      'mixdrop',
      '<html></html>',
      'https://x',
    );
    final m = jsonDecode(json) as Map<String, dynamic>;
    expect(m['error'], 'not_found');
  });

  test('hubcloud links golden via FFI', () {
    final html = _fixture('hubcloud_links.html');
    final json = ForjaRust.instance.extractHubcloudLinksJson(
      html,
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
}
