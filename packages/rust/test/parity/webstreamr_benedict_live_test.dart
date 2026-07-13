import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('Benedict Society 104359 S1E1 live WebStreamr', () async {
    final config = <String, String>{'multi': 'on'};
    for (final cc in WebStreamrSettings.defaultCountryCodes) {
      config[cc] = 'on';
    }
    final req = jsonEncode({
      'tmdb_id': 104359,
      'media_type': 'series',
      'season': 1,
      'episode': 1,
      'title': 'The Mysterious Benedict Society',
      'config': config,
      'enabled_sources': <String>[],
    });
    final raw = await runWebstreamrGetStreamsJson(req);
    final arr = jsonDecode(raw);
    // ignore: avoid_print
    print('\n=== WebStreamr 104359 S1E1 ===');
    if (arr is List) {
      // ignore: avoid_print
      print('Total: ${arr.length}');
      for (var i = 0; i < arr.length && i < 20; i++) {
        final s = arr[i] as Map<String, dynamic>;
        final title = (s['title'] as String?)?.split('\n').first ?? '?';
        final url = s['url'] ?? s['externalUrl'] ?? s['ytId'];
        // ignore: avoid_print
        print('${i + 1}. ${s['name']} | $title | $url');
      }
    } else {
      // ignore: avoid_print
      print('Response: $arr');
    }
    expect(arr, isA<List>());
  }, timeout: const Timeout(Duration(minutes: 3)));
}
