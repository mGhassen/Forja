import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:sqflite/sqflite.dart';

/// Disk image cache shared by every network cover.
///
/// A hit is a memory lookup. The SQLite row is not rewritten on each view —
/// that exclusive write is what locked `libCachedImageData.db` for 10s when a
/// details page opened a pile of covers at once.
class ForjaImageCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'libCachedImageData';

  static final ForjaImageCacheManager _instance = ForjaImageCacheManager._();

  factory ForjaImageCacheManager() => _instance;

  ForjaImageCacheManager._()
      : super(Config(key, repo: ForjaCacheIndex(databaseName: key)));
}

class ForjaCacheIndex extends CacheInfoRepository
    with CacheInfoRepositoryHelperMethods {
  ForjaCacheIndex({required String databaseName})
      : _disk = CacheObjectProvider(databaseName: databaseName);

  final CacheObjectProvider _disk;
  final Map<String, CacheObject> _byKey = {};
  final Set<String> _dirty = {};
  Timer? _flushTimer;
  Future<void> _diskTail = Future<void>.value();

  @override
  Future<bool> open() async {
    if (!shouldOpenOnNewConnection()) {
      return openCompleter!.future;
    }
    await _disk.open();
    await _disk.db?.rawQuery('PRAGMA journal_mode=WAL');
    for (final object in await _disk.getAllObjects()) {
      _byKey[object.key] = object;
    }
    return opened();
  }

  @override
  Future<bool> exists() => _disk.exists();

  @override
  Future<CacheObject?> get(String key) async {
    await _ready;
    return _byKey[key];
  }

  Future<bool> get _ready => openCompleter?.future ?? Future<bool>.value(false);

  @override
  Future<CacheObject> insert(
    CacheObject cacheObject, {
    bool setTouchedToNow = true,
  }) {
    return _onDisk(() async {
      final stored = await _disk.insert(
        cacheObject,
        setTouchedToNow: setTouchedToNow,
      );
      _byKey[stored.key] = stored;
      return stored;
    });
  }

  @override
  Future<dynamic> updateOrInsert(CacheObject cacheObject) {
    if (cacheObject.id == null) return insert(cacheObject);
    return update(cacheObject);
  }

  @override
  Future<int> update(CacheObject cacheObject, {bool setTouchedToNow = true}) async {
    final touched = setTouchedToNow ? DateTime.now() : cacheObject.touched;
    final next = CacheObject(
      cacheObject.url,
      key: cacheObject.key,
      id: cacheObject.id,
      relativePath: cacheObject.relativePath,
      validTill: cacheObject.validTill,
      eTag: cacheObject.eTag,
      length: cacheObject.length,
      touched: touched,
    );
    _byKey[next.key] = next;
    if (next.id != null) _scheduleFlush(next.key);
    return 1;
  }

  void _scheduleFlush(String key) {
    _dirty.add(key);
    _flushTimer ??= Timer(const Duration(seconds: 2), () {
      _flushTimer = null;
      final keys = _dirty.toList(growable: false);
      _dirty.clear();
      if (keys.isEmpty) return;
      unawaited(_onDisk(() => _flush(keys)));
    });
  }

  Future<void> _flush(List<String> keys) async {
    final db = _disk.db;
    if (db == null) return;
    await db.transaction((Transaction txn) async {
      for (final key in keys) {
        final object = _byKey[key];
        if (object?.id == null) continue;
        await txn.update(
          'cacheObject',
          object!.toMap(setTouchedToNow: false),
          where: '${CacheObject.columnId} = ?',
          whereArgs: [object.id],
        );
      }
    });
  }

  Future<T> _onDisk<T>(Future<T> Function() action) {
    final run = _diskTail.then((_) => action());
    _diskTail = run.then((_) {}, onError: (_, _) {});
    return run;
  }

  @override
  Future<int> delete(int id) {
    return _onDisk(() async {
      _byKey.removeWhere((_, object) => object.id == id);
      return _disk.delete(id);
    });
  }

  @override
  Future<int> deleteAll(Iterable<int> ids) {
    final list = ids.toList(growable: false);
    if (list.isEmpty) return Future<int>.value(0);
    return _onDisk(() async {
      final drop = list.toSet();
      _byKey.removeWhere((_, object) => drop.contains(object.id));
      return _disk.deleteAll(list);
    });
  }

  @override
  Future<List<CacheObject>> getAllObjects() async {
    await _ready;
    return _byKey.values.toList(growable: false);
  }

  @override
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) async {
    await _ready;
    final cutoff = DateTime.now().subtract(const Duration(days: 1));
    final old = _byKey.values
        .where((object) => object.touched != null && object.touched!.isBefore(cutoff))
        .toList()
      ..sort((a, b) => b.touched!.compareTo(a.touched!));
    if (old.length <= capacity) return const [];
    return old.skip(capacity).take(100).toList(growable: false);
  }

  @override
  Future<List<CacheObject>> getOldObjects(Duration maxAge) async {
    await _ready;
    final cutoff = DateTime.now().subtract(maxAge);
    return _byKey.values
        .where((object) => object.touched != null && object.touched!.isBefore(cutoff))
        .toList(growable: false);
  }

  @override
  Future<bool> close() async {
    if (!shouldClose()) return false;
    _flushTimer?.cancel();
    final keys = _dirty.toList(growable: false);
    _dirty.clear();
    if (keys.isNotEmpty) await _onDisk(() => _flush(keys));
    return _disk.close();
  }

  @override
  Future<void> deleteDataFile() async {
    _byKey.clear();
    _dirty.clear();
    await _disk.deleteDataFile();
  }
}
