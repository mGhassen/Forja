import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/portals/guide/channel_guides.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/network/portal_network.dart';
import 'package:forja/shared/engine/portals/store/storage.dart';

/// Build in-player channel guide for IPTV live open (Search + grid chrome).
abstract final class PortalChannelGuideOpen {
  PortalChannelGuideOpen._();

  /// In-memory live catalog so guide attach does not re-hit the portal every open.
  static final Map<String, Future<PortalCatalogFetch>> _liveCatalogFutures = {};

  /// Pack `iptvPortalKey` shape: `url|username` (lowercased).
  static String packPortalKey(Portal p) =>
      '${p.url.trim().toLowerCase()}|${p.username.trim().toLowerCase()}';

  static Future<PortalCatalogFetch> _liveCatalog(VerifiedPortal verified) {
    final cacheKey = verified.key;
    final hit = _liveCatalogFutures[cacheKey];
    if (hit != null) return hit;
    final future = PortalClient.catalog(verified.portal, PortalSection.live);
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
      final portals = await PortalStore.load();
      VerifiedPortal? verified;
      for (final v in portals) {
        if (packPortalKey(v.portal) == key.toLowerCase()) {
          verified = v;
          break;
        }
        // Legacy / password-bearing keys.
        if (v.key == key || v.credKey == key) {
          verified = v;
          break;
        }
      }
      if (verified == null) {
        debugPrint('[PortalGuide] no portal for key=$key');
        return null;
      }

      final fetch = await _liveCatalog(verified);
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
