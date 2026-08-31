import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:forja/features/iptv/data/models.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// One Live / Movies / Series shelf snapshot for disk.
class IptvCatalogShelfSnap {
  const IptvCatalogShelfSnap({
    required this.categories,
    required this.streams,
  });

  final List<IptvCategory> categories;
  final List<IptvStream> streams;
}

/// On-disk IPTV catalog shelves (one JSON file per portal + section).
///
/// Survives app restart so a warm shelf skips network. Portal keys
/// (url|user|pass) are hashed into filenames - never written raw.
abstract final class IptvCatalogDiskStore {
  static const _subdir = 'iptv_catalog_v1';
  static const _version = 1;

  static Directory? _dir;

  /// Cleared whenever [clearAll] runs (sign-out / Settings clear).
  static void Function()? onClearAll;

  static Future<Directory> _root() async {
    final cached = _dir;
    if (cached != null) return cached;
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, _subdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  static String _portalHash(String portalKey) =>
      sha256.convert(utf8.encode(portalKey)).toString();

  static Future<File> _file(String portalKey, IptvSection section) async {
    final root = await _root();
    return File(
      p.join(root.path, '${_portalHash(portalKey)}_${section.name}.json'),
    );
  }

  static Future<IptvCatalogShelfSnap?> load(
    String portalKey,
    IptvSection section,
  ) async {
    if (portalKey.isEmpty) return null;
    try {
      final file = await _file(portalKey, section);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.isEmpty) return null;
      return Isolate.run(() => _decode(raw));
    } catch (e) {
      debugPrint('IptvCatalogDiskStore.load failed: $e');
      return null;
    }
  }

  static Future<void> save(
    String portalKey,
    IptvSection section,
    List<IptvCategory> categories,
    List<IptvStream> streams,
  ) async {
    if (portalKey.isEmpty) return;
    try {
      final encoded = await Isolate.run(
        () => _encode(categories, streams),
      );
      final file = await _file(portalKey, section);
      await file.writeAsString(encoded, flush: true);
    } catch (e) {
      debugPrint('IptvCatalogDiskStore.save failed: $e');
    }
  }

  static Future<void> deleteShelf(
    String portalKey,
    IptvSection section,
  ) async {
    if (portalKey.isEmpty) return;
    try {
      final file = await _file(portalKey, section);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('IptvCatalogDiskStore.deleteShelf failed: $e');
    }
  }

  static Future<void> deletePortal(String portalKey) async {
    if (portalKey.isEmpty) return;
    for (final section in IptvSection.values) {
      await deleteShelf(portalKey, section);
    }
  }

  static Future<void> clearAll() async {
    try {
      onClearAll?.call();
      final root = await _root();
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
      _dir = null;
    } catch (e) {
      debugPrint('IptvCatalogDiskStore.clearAll failed: $e');
    }
  }

  static String _encode(
    List<IptvCategory> categories,
    List<IptvStream> streams,
  ) {
    return json.encode({
      'v': _version,
      'categories': [
        for (final c in categories) {'id': c.id, 'name': c.name},
      ],
      'streams': [
        for (final s in streams)
          {
            'stream_id': s.streamId,
            'name': s.name,
            'icon': s.icon,
            'category_id': s.categoryId,
            'container_ext': s.containerExt,
            'kind': s.kind,
            'epg_channel_id': s.epgChannelId,
          },
      ],
    });
  }

  static IptvCatalogShelfSnap? _decode(String raw) {
    final decoded = json.decode(raw);
    if (decoded is! Map) return null;
    final root = Map<String, dynamic>.from(decoded);
    final v = (root['v'] as num?)?.toInt() ?? 0;
    if (v != _version) return null;
    final catsRaw = root['categories'];
    final streamsRaw = root['streams'];
    if (catsRaw is! List || streamsRaw is! List) return null;
    final categories = <IptvCategory>[
      for (final e in catsRaw)
        if (e is Map)
          IptvCategory(
            id: e['id']?.toString() ?? '',
            name: e['name']?.toString() ?? '',
          ),
    ];
    final streams = <IptvStream>[
      for (final e in streamsRaw)
        if (e is Map)
          IptvStream(
            streamId: e['stream_id']?.toString() ?? '',
            name: e['name']?.toString() ?? '',
            icon: e['icon']?.toString() ?? '',
            categoryId: e['category_id']?.toString() ?? '',
            containerExt: e['container_ext']?.toString() ?? '',
            kind: e['kind']?.toString() ?? '',
            epgChannelId: e['epg_channel_id']?.toString() ?? '',
          ),
    ];
    return IptvCatalogShelfSnap(categories: categories, streams: streams);
  }

  @visibleForTesting
  static IptvCatalogShelfSnap? decodeForTest(String raw) => _decode(raw);

  @visibleForTesting
  static String encodeForTest(
    List<IptvCategory> categories,
    List<IptvStream> streams,
  ) =>
      _encode(categories, streams);
}
