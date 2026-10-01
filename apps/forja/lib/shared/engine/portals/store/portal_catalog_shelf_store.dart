import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rust/rust.dart';

/// One Live / Movies / Series shelf snapshot (opaque JSON maps).
class PortalCatalogShelfSnap {
  const PortalCatalogShelfSnap({
    required this.categories,
    required this.streams,
  });

  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> streams;
}

/// On-disk portal catalog shelves — file + [Isolate] encode/decode.
///
/// Layout: `{support}/portal_catalog_v1/accounts/{account}/profiles/{profile}/`
/// Filenames hash portal identity — credentials never written raw.
///
/// Generic host capability (RFC-109): packs page via `catalog_page`; full
/// shelves never cross flutter_js.
abstract final class PortalCatalogShelfStore {
  static const _subdir = 'portal_catalog_v1';
  static const _version = 1;

  static Directory? _dir;
  static String _accountId = LocalDataScope.guestAccountId;
  static String _profileId = LocalDataScope.guestProfileId;

  @visibleForTesting
  static Directory? debugRoot;

  @visibleForTesting
  static void resetForTest() {
    debugRoot = null;
    _dir = null;
    _accountId = LocalDataScope.guestAccountId;
    _profileId = LocalDataScope.guestProfileId;
    _memory.clear();
  }

  static Future<void> configureScope({
    required String? accountId,
    required String? profileId,
  }) async {
    final account = _sanitize(accountId ?? LocalDataScope.guestAccountId);
    final profile = _sanitize(profileId ?? LocalDataScope.guestProfileId);
    if (_accountId == account && _profileId == profile && _dir != null) {
      return;
    }
    _accountId = account;
    _profileId = profile;
    _dir = null;
    _memory.clear();
  }

  static String _sanitize(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return LocalDataScope.guestProfileId;
    return t.replaceAll(RegExp(r'[^\w\-.]'), '_');
  }

  static Future<Directory> _root() async {
    final cached = _dir;
    if (cached != null) return cached;
    final String basePath;
    if (debugRoot != null) {
      basePath = debugRoot!.path;
    } else {
      final support = await getApplicationSupportDirectory();
      basePath = p.join(support.path, _subdir);
    }
    final dir = Directory(
      p.join(basePath, 'accounts', _accountId, 'profiles', _profileId),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  static String shelfKey(String portalKey, String section) =>
      '${portalKey.trim()}|${section.trim().toLowerCase()}';

  static String _portalHash(String portalKey) =>
      sha256.convert(utf8.encode(portalKey)).toString();

  static Future<File> _file(String portalKey, String section) async {
    final root = await _root();
    final sec = section.trim().toLowerCase();
    return File(p.join(root.path, '${_portalHash(portalKey)}_$sec.json'));
  }

  /// In-memory LRU (max 10 shelves) — warm page without disk.
  static const maxMemoryShelves = 10;
  static final Map<String, PortalCatalogShelfSnap> _memory = {};
  static final List<String> _lru = [];

  static void _touchMemory(String key, PortalCatalogShelfSnap snap) {
    _memory[key] = snap;
    _lru.remove(key);
    _lru.add(key);
    while (_lru.length > maxMemoryShelves) {
      final victim = _lru.removeAt(0);
      _memory.remove(victim);
    }
  }

  static PortalCatalogShelfSnap? memoryGet(String portalKey, String section) {
    final key = shelfKey(portalKey, section);
    final snap = _memory[key];
    if (snap == null) return null;
    _lru.remove(key);
    _lru.add(key);
    return snap;
  }

  static void memoryPut(
    String portalKey,
    String section,
    PortalCatalogShelfSnap snap,
  ) {
    _touchMemory(shelfKey(portalKey, section), snap);
  }

  static Future<PortalCatalogShelfSnap?> load(
    String portalKey,
    String section,
  ) async {
    if (portalKey.isEmpty) return null;
    final mem = memoryGet(portalKey, section);
    if (mem != null) return mem;
    try {
      final file = await _file(portalKey, section);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.isEmpty) return null;
      final snap = await Isolate.run(() => _decode(raw));
      if (snap == null) return null;
      memoryPut(portalKey, section, snap);
      return snap;
    } catch (e) {
      debugPrint('[PortalCatalogShelfStore] load failed: $e');
      return null;
    }
  }

  static Future<void> save(
    String portalKey,
    String section,
    PortalCatalogShelfSnap snap,
  ) async {
    if (portalKey.isEmpty) return;
    memoryPut(portalKey, section, snap);
    try {
      final encoded = await Isolate.run(() => _encode(snap));
      final file = await _file(portalKey, section);
      await file.writeAsString(encoded, flush: true);
    } catch (e) {
      debugPrint('[PortalCatalogShelfStore] save failed: $e');
    }
  }

  static Future<void> deleteShelf(String portalKey, String section) async {
    final key = shelfKey(portalKey, section);
    _memory.remove(key);
    _lru.remove(key);
    try {
      final file = await _file(portalKey, section);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[PortalCatalogShelfStore] delete failed: $e');
    }
  }

  static Future<void> clearAll() async {
    _memory.clear();
    _lru.clear();
    try {
      final root = await _root();
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
      _dir = null;
    } catch (e) {
      debugPrint('[PortalCatalogShelfStore] clearAll failed: $e');
    }
  }

  static String _encode(PortalCatalogShelfSnap snap) {
    return jsonEncode({
      'v': _version,
      'categories': snap.categories,
      'streams': snap.streams,
    });
  }

  static PortalCatalogShelfSnap? _decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final m = Map<String, dynamic>.from(decoded);
    final cats = m['categories'];
    final streams = m['streams'];
    if (cats is! List || streams is! List) return null;
    return PortalCatalogShelfSnap(
      categories: [
        for (final e in cats)
          if (e is Map) Map<String, dynamic>.from(e),
      ],
      streams: [
        for (final e in streams)
          if (e is Map) Map<String, dynamic>.from(e),
      ],
    );
  }
}
