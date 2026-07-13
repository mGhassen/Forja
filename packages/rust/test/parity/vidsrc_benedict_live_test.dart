import 'dart:convert';
import '../helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUpAll(() async { await initRustForTests(); });

  test('vidsrc only webstreamr', () async {
    final req = jsonEncode({
      'tmdb_id': 104359,
      'media_type': 'series',
      'season': 1,
      'episode': 1,
      'config': {'multi': 'on'},
      'enabled_sources': ['vidsrc'],
    });
    final raw = await runWebstreamrGetStreamsJson(req);
    print('vidsrc-only: $raw');
    final arr = jsonDecode(raw) as List;
    print('count=${arr.length}');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('resolve_vidsrc_embed direct', () async {
    final req = jsonEncode({
      'tmdb_id': 104359,
      'is_movie': false,
      'season': 1,
      'episode': 1,
    });
    final raw = await runResolveVidsrcEmbedJson(req);
    print('direct vidsrc: $raw');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
