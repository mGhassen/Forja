import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/components/forja_image_cache.dart';

void main() {
  test('SQLite index only where sqflite ships a plugin', () {
    expect(
      ForjaImageCacheManager.cacheIndexFor(sqflite: true),
      isA<ForjaCacheIndex>(),
    );
    expect(
      ForjaImageCacheManager.cacheIndexFor(sqflite: false),
      isA<JsonCacheInfoRepository>(),
    );
  });

  test('sqflite is only available on Android, iOS and macOS', () {
    final expected = Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
    expect(ForjaImageCacheManager.sqfliteAvailable, expected);
  });
}
