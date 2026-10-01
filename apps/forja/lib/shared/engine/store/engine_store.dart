import 'package:rust/rust.dart';

/// Generic opaque-key store (RFC-109 Wave 2/3).
///
/// Thin wrapper over [BookmarkStore] — public API is key/status only (no hub /
/// anime / drama scent). [ListFollow] still owns Simkl sync; migrate callers
/// gradually to this surface for `ctx.host.store`.
class EngineStore {
  EngineStore._();
  static final EngineStore instance = EngineStore._();

  BookmarkStore get _bookmarks => BookmarkStore();

  Future<List<Map<String, dynamic>>> list({String? status}) async {
    await _bookmarks.ensureLoaded();
    final want = status?.trim() ?? '';
    return [
      for (final e in _bookmarks.items)
        if (want.isEmpty ||
            (e['listStatus']?.toString() ?? BookmarkStore.defaultStatus) ==
                want)
          Map<String, dynamic>.from(e),
    ];
  }

  /// Upsert by opaque [key] (`uniqueId`). Pass row fields in [data]
  /// (`title`, `posterPath`, `mediaType`, `listStatus`, optional `open` /
  /// `pluginId` / `tmdbId`).
  Future<void> upsert(String key, Map<String, dynamic> data) async {
    final uid = key.trim();
    if (uid.isEmpty) return;
    await _bookmarks.ensureLoaded();

    final openRaw = data['open'] ?? data['metaOpen'] ?? data['catalogOpen'];
    final open = openRaw is Map
        ? Map<String, dynamic>.from(openRaw)
        : null;
    final pluginId = data['pluginId']?.toString().trim() ?? '';
    final mediaType = data['mediaType']?.toString() ?? '';
    final title = data['title']?.toString() ?? '';
    final posterPath = data['posterPath']?.toString() ?? '';
    final listStatus = data['listStatus']?.toString() ??
        BookmarkStore.defaultStatus;
    final tmdbId = _asInt(data['tmdbId']);
    final tmdbMediaType = data['tmdbMediaType']?.toString();
    final voteAverage = (data['voteAverage'] as num?)?.toDouble() ?? 0;
    final releaseDate = data['releaseDate']?.toString() ?? '';

    if (pluginId.isNotEmpty && open != null) {
      await _bookmarks.upsertCatalog(
        pluginId: pluginId,
        open: open,
        uniqueId: uid,
        mediaType: mediaType,
        title: title,
        posterPath: posterPath,
        listStatus: listStatus,
        tmdbId: tmdbId,
        tmdbMediaType: tmdbMediaType,
        voteAverage: voteAverage,
        releaseDate: releaseDate,
      );
      return;
    }

    await _bookmarks.upsertHub(
      uniqueId: uid,
      mediaType: mediaType,
      title: title,
      posterPath: posterPath,
      listStatus: listStatus,
      open: open,
      tmdbId: tmdbId,
      tmdbMediaType: tmdbMediaType,
      voteAverage: voteAverage,
      releaseDate: releaseDate,
    );
  }

  Future<void> remove(String key) async {
    final uid = key.trim();
    if (uid.isEmpty) return;
    await _bookmarks.remove(uid);
  }

  /// Set list status for [key]. Empty [status] removes the row.
  Future<bool> setStatus(String key, String status) async {
    final uid = key.trim();
    if (uid.isEmpty) return false;
    await _bookmarks.ensureLoaded();
    if (status.trim().isEmpty) {
      await _bookmarks.remove(uid);
      return true;
    }
    final existing = _bookmarks.itemOf(uid);
    if (existing == null) return false;
    final patched = Map<String, dynamic>.from(existing)
      ..['listStatus'] = status.trim();
    await upsert(uid, patched);
    return true;
  }

  String? statusOf(String key) {
    final uid = key.trim();
    if (uid.isEmpty) return null;
    return _bookmarks.resolvedStatus(uniqueId: uid);
  }

  static int? _asInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw');
  }
}
