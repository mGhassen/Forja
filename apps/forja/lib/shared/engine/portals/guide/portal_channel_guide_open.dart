import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/portals/guide/channel_guides.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/network/portal_network.dart';
import 'package:forja/shared/engine/portals/portals_host.dart';
import 'package:forja/shared/engine/portals/store/iptv_catalog_db.dart';
import 'package:forja/shared/engine/portals/store/portal_catalog_shelf_store.dart';

/// Build in-player channel guide for IPTV live open (Search + grid chrome).
abstract final class PortalChannelGuideOpen {
  PortalChannelGuideOpen._();

  /// In-memory live catalog so guide attach does not re-hit the portal every open.
  static final Map<String, Future<PortalCatalogFetch>> _liveCatalogFutures = {};

  /// Pack `iptvPortalKey` shape: `url|username` (lowercased).
  static String packPortalKey(Portal p) =>
      '${p.url.trim().toLowerCase()}|${p.username.trim().toLowerCase()}';

  /// Pack keys are `url|username`; [Portal.key] is `platform|url|user|pass`.
  /// Vault-first — pack Add/Import never write [PortalStore] alone.
  static VerifiedPortal? matchPortal(
    List<VerifiedPortal> portals,
    String portalKey,
  ) {
    final key = portalKey.trim().toLowerCase();
    if (key.isEmpty) return null;
    for (final p in portals) {
      if (p.key.toLowerCase() == key) return p;
      if (p.credKey.toLowerCase() == key) return p;
      if (packPortalKey(p.portal) == key) return p;
    }
    for (final p in portals) {
      final pack = packPortalKey(p.portal);
      if (pack.isEmpty) continue;
      if (key.contains(pack) || pack.contains(key)) return p;
      final user = p.portal.username.trim().toLowerCase();
      if (user.isNotEmpty && (key.endsWith('|$user') || key == user)) {
        return p;
      }
    }
    return null;
  }

  /// One-channel guide so Search / Guide chrome paint before the full shelf.
  ///
  /// Sync — no vault / network. [build] replaces this with the full list.
  static ChannelGuide stub({
    required String streamId,
    required String title,
    String? logoUrl,
    String? categoryId,
    String? epgChannelId,
    String? playUrl,
  }) {
    final cat = (categoryId ?? '').trim().isEmpty
        ? 'all'
        : categoryId!.trim();
    final sid = streamId.trim().isNotEmpty
        ? streamId.trim()
        : (playUrl?.trim().isNotEmpty == true
            ? playUrl!.trim()
            : (title.trim().isEmpty ? 'channel' : title.trim()));
    final name = title.trim().isEmpty ? sid : title.trim();
    final stream = PortalStream(
      streamId: sid,
      name: name,
      icon: (logoUrl ?? '').trim(),
      categoryId: cat,
      containerExt: 'ts',
      kind: 'live',
      epgChannelId: (epgChannelId ?? '').trim(),
    );
    return ChannelGuide(
      groups: [
        GuideGroup(
          id: cat,
          name: cat == 'all' ? 'Live' : cat,
        ),
      ],
      channels: [
        GuideChannel(
          id: sid,
          name: name,
          logoUrl: (logoUrl ?? '').trim().isEmpty ? null : logoUrl!.trim(),
          groupId: cat,
          playUrl: playUrl?.trim().isEmpty == true ? null : playUrl?.trim(),
          payload: stream,
        ),
      ],
      initialChannelId: sid,
      initialGroupId: cat,
    );
  }

  static PortalCatalogFetch? _fetchFromShelf(
    String portalKey,
    String section,
  ) {
    final key = portalKey.trim();
    if (key.isEmpty) return null;
    final snap = PortalCatalogShelfStore.memoryGet(key, section);
    if (snap == null ||
        (snap.streams.isEmpty && snap.categories.isEmpty)) {
      return null;
    }
    return PortalCatalogFetch(
      categories: _categoriesFromShelf(snap.categories),
      streams: _streamsFromShelf(snap.streams, section),
    );
  }

  static Future<PortalCatalogFetch?> _loadShelf(
    String portalKey,
    String section,
  ) async {
    final mem = _fetchFromShelf(portalKey, section);
    if (mem != null) return mem;
    final exported = IptvCatalogDb.exportShelf(portalKey, section);
    if (exported != null) {
      final cats = _asMaps(exported['categories']);
      final streams = _asMaps(exported['streams']);
      if (cats.isNotEmpty || streams.isNotEmpty) {
        return PortalCatalogFetch(
          categories: _categoriesFromShelf(cats),
          streams: _streamsFromShelf(streams, section),
        );
      }
    }
    final snap = await PortalCatalogShelfStore.load(portalKey, section);
    if (snap == null ||
        (snap.streams.isEmpty && snap.categories.isEmpty)) {
      return null;
    }
    return PortalCatalogFetch(
      categories: _categoriesFromShelf(snap.categories),
      streams: _streamsFromShelf(snap.streams, section),
    );
  }

  static List<Map<String, dynamic>> _asMaps(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  static List<PortalCategory> _categoriesFromShelf(
    List<Map<String, dynamic>> raw,
  ) {
    return [
      for (final e in raw)
        PortalCategory(
          id: (e['id'] ?? e['category_id'] ?? '').toString(),
          name: (e['name'] ?? e['category_name'] ?? '').toString(),
        ),
    ];
  }

  static List<PortalStream> _streamsFromShelf(
    List<Map<String, dynamic>> raw,
    String sectionName,
  ) {
    return [
      for (final e in raw)
        PortalStream(
          streamId: (e['stream_id'] ?? e['streamId'] ?? e['id'] ?? '')
              .toString(),
          name: (e['name'] ?? e['title'] ?? '').toString(),
          icon: (e['icon'] ?? e['stream_icon'] ?? e['logo'] ?? '').toString(),
          categoryId:
              (e['category_id'] ?? e['categoryId'] ?? 'all').toString(),
          containerExt:
              (e['container_ext'] ?? e['containerExt'] ?? e['ext'] ?? '')
                  .toString(),
          epgChannelId:
              (e['epg_channel_id'] ?? e['epgChannelId'] ?? '').toString(),
          kind: (e['kind'] ?? sectionName).toString(),
        ),
    ];
  }

  static Future<PortalCatalogFetch> _liveCatalog(
    VerifiedPortal verified, {
    required String openPortalKey,
  }) {
    final cacheKey = verified.key;
    final hit = _liveCatalogFutures[cacheKey];
    if (hit != null) return hit;

    final future = () async {
      // Prefer the hub shelf (already browsed) — avoid a second full catalog
      // decode under MediaKit (ATV ANR).
      for (final key in <String>{
        openPortalKey.trim(),
        packPortalKey(verified.portal),
        verified.key,
        verified.credKey,
      }) {
        if (key.isEmpty) continue;
        final shelf = await _loadShelf(key, 'live');
        if (shelf != null && shelf.streams.isNotEmpty) {
          debugPrint(
            '[PortalGuide] shelf hit key=$key streams=${shelf.streams.length}',
          );
          return shelf;
        }
      }
      debugPrint('[PortalGuide] shelf miss — network catalog');
      return PortalClient.catalog(verified.portal, PortalSection.live);
    }();

    _liveCatalogFutures[cacheKey] = future;
    future.then((fetch) {
      if (fetch.error != null && fetch.streams.isEmpty) {
        _liveCatalogFutures.remove(cacheKey);
      }
    }).catchError((_) {
      _liveCatalogFutures.remove(cacheKey);
    });
    return future;
  }

  /// Drop cached catalog (portal switch / Refresh).
  static void invalidateLiveCatalog({String? portalKey}) {
    final key = (portalKey ?? '').trim();
    if (key.isEmpty) {
      _liveCatalogFutures.clear();
      return;
    }
    final lower = key.toLowerCase();
    _liveCatalogFutures.removeWhere(
      (k, _) => k == key || k.toLowerCase() == lower,
    );
  }

  static Future<ChannelGuide?> build({
    required String portalKey,
    required String streamId,
    required String title,
    String? logoUrl,
    String? categoryId,
    String? epgChannelId,
    String? playUrl,
  }) async {
    final key = portalKey.trim();
    if (key.isEmpty) return null;
    try {
      debugPrint('[PortalGuide] build start key=$key');
      final portals = await PortalsHost.loadVaultVerifiedPortals();
      final verified = matchPortal(portals, key);
      if (verified == null) {
        debugPrint('[PortalGuide] no portal for key=$key');
        return null;
      }

      final fetch = await _liveCatalog(verified, openPortalKey: key);
      var streams = fetch.streams.where((s) => s.kind == 'live').toList();
      final categories = fetch.categories;

      PortalStream? initial;
      final sid = streamId.trim();
      if (sid.isNotEmpty) {
        for (final s in streams) {
          if (s.streamId == sid) {
            initial = s;
            break;
          }
        }
      }
      // M3U: stream id is often the play URL.
      if (initial == null && playUrl != null && playUrl.trim().isNotEmpty) {
        final u = playUrl.trim();
        for (final s in streams) {
          if (s.streamId == u) {
            initial = s;
            break;
          }
        }
      }
      initial ??= PortalStream(
        streamId: sid.isNotEmpty
            ? sid
            : (playUrl?.trim().isNotEmpty == true ? playUrl!.trim() : title),
        name: title,
        icon: (logoUrl ?? '').trim(),
        categoryId: (categoryId ?? '').trim().isEmpty
            ? 'all'
            : categoryId!.trim(),
        containerExt: verified.platform == PortalPlatform.m3u ? '' : 'ts',
        kind: 'live',
        epgChannelId: (epgChannelId ?? '').trim(),
      );
      if (streams.isEmpty ||
          !streams.any((s) => s.streamId == initial!.streamId)) {
        streams = [...streams, initial];
      }

      debugPrint(
        '[PortalGuide] build ok streams=${streams.length} cats=${categories.length}',
      );
      return ChannelGuides.fromXtreamLive(
        portal: verified,
        categories: categories,
        streams: streams,
        initialStream: initial,
      );
    } catch (e, st) {
      debugPrint('[PortalGuide] build failed: $e\n$st');
      return null;
    }
  }
}
