import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('Enola Holmes 3 live resolve via FFI (same path as app)', () {
    final req = jsonEncode({
      'imdb_id': 'tt32278481',
      'tmdb_id': 1202033,
      'media_type': 'movie',
      'config': {
        'multi': 'on',
        'en': 'on',
        'de': 'on',
        'hi': 'on',
      },
      'enabled_sources': <String>[],
    });
    final raw = RustLib.instance.webstreamrGetStreamsJson(req);
    final arr = jsonDecode(raw) as List<dynamic>;
    // ignore: avoid_print
    print('\n=== FFI webstreamrGetStreamsJson: Enola Holmes 3 ===');
    // ignore: avoid_print
    print('Total: ${arr.length}');
    for (var i = 0; i < arr.length; i++) {
      final s = arr[i] as Map<String, dynamic>;
      final name = s['name'] ?? '?';
      final title = (s['title'] as String?)?.split('\n').first ?? '?';
      // ignore: avoid_print
      print('${i + 1}. $name | $title');
    }
    expect(arr.length, greaterThan(1));
    final titles = arr
        .map((s) => (s as Map)['title'] as String? ?? '')
        .join('\n');
    expect(titles.contains('HDHub4u'), isTrue);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
