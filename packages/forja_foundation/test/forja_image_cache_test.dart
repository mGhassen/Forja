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

  test('same-key inserts coalesce into one pending flush', () async {
    final index = ForjaCacheIndex(databaseName: 'forja_test_insert_coalesce');
    final until = DateTime.now().add(const Duration(days: 1));
    final first = index.insert(
      CacheObject(
        'https://example.test/a',
        relativePath: 'a.jpg',
        validTill: until,
      ),
    );
    final second = index.insert(
      CacheObject(
        'https://example.test/a',
        relativePath: 'a2.jpg',
        validTill: until,
      ),
    );
    expect(index.debugPendingInsertCount, 1);
    expect(second, same(first));
    // No opened sqflite DB in this unit test — flush errors; coalescing is the assert.
    await expectLater(first, throwsA(isA<StateError>()));
    expect(index.debugPendingInsertCount, 0);
  });
}
