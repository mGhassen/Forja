import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shell/routing/shell_overlay_navigator.dart';
import 'package:forja/shared/engine/portals/guide/portal_channel_guide_open.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/network/portal_network.dart';
import 'package:forja/shared/engine/portals/portals_host.dart';
import 'package:forja/shared/engine/portals/store/storage.dart';
import 'package:forja/shared/engine/runtime/actions/category_bar/category_bar_action_host.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/iptv_catalog_land.dart';
import 'package:forja/shared/engine/runtime/open/meta_surface_open.dart';
import 'package:forja/shared/engine/unlock/live_plugin_engine.dart';
import 'package:forja/shared/player/live/hooks/live_play.dart';
import 'package:forja/shared/player/live/pt_player_screen.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja_foundation/widgets/guide/channel_guide.dart';
import 'package:rust/rust.dart' show BuiltInPlayerContext;

/// Generic `ctx.host.playback.open` + `open.surface: stream` (RFC-109 Wave C).
///
/// Packs pass opaque stream URLs; host opens the native live/IPTV player
/// ([PtPlayerScreen]). Catalog VOD (Home/Anime/…) stays on [AppRouter.openPlayer].
abstract final class HostPlaybackOpen {
  HostPlaybackOpen._();

  static const surface = 'stream';

  static bool _registered = false;

  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;
    MetaSurfaceOpen.register(surface, openFromMeta);
  }

  static void openFromMeta(BuildContext context, MetaItem item) {
    final open = item.open;
    final url = (open?.extraString('url') ??
            open?.extraString('streamUrl') ??
            open?.id ??
            '')
        .trim();
    if (url.isEmpty) return;
    final headers = _headersFromOpen(open);
    final title = item.name.trim().isEmpty ? 'Stream' : item.name.trim();
    final logo = item.poster.trim().isEmpty
        ? (item.logo.trim().isEmpty ? null : item.logo.trim())
        : item.poster.trim();
    final streamId = (open?.extraString('streamId') ?? '').trim();
    final epg = (open?.extraString('epgChannelId') ?? '').trim();
    final portalKey = (open?.extraString('portalKey') ?? '').trim();
    final categoryId = (open?.extraString('categoryId') ?? '').trim();
    final vod = _vodFromOpen(open);
    final subtitleRaw =
        (open?.extraString('subtitle') ?? item.description).trim();
    unawaited(
      openUrl(
        context: context,
        url: url,
        title: title,
        headers: headers,
        logoUrl: logo,
        streamId: streamId.isEmpty ? null : streamId,
        epgChannelId: epg.isEmpty ? null : epg,
        portalKey: portalKey.isEmpty ? null : portalKey,
        categoryId: categoryId.isEmpty ? null : categoryId,
        liveSourceKind: _liveSourceKindFromOpen(open, vod: vod),
        engineContext: _engineContext(open: open, vod: vod),
        vodPlayback: vod,
        onlineSubtitles: vod,
        subtitle: subtitleRaw.isEmpty ? null : subtitleRaw,
      ),
    );
  }

  /// Bridge entry — [context] optional when overlay navigator is mounted.
  static Future<bool> openUrl({
    BuildContext? context,
    required String url,
    String title = 'Stream',
    String? subtitle,
    String? logoUrl,
    String? streamId,
    String? epgChannelId,
    String? portalKey,
    String? categoryId,
    Map<String, String>? headers,
    PortalLiveSourceKind? liveSourceKind,
    BuiltInPlayerContext engineContext = BuiltInPlayerContext.iptv,
    bool vodPlayback = false,
    bool onlineSubtitles = false,
    ChannelGuide? channelGuide,
  }) async {
    final u = url.trim();
    if (u.isEmpty) return false;
    final ctx = context ?? shellOverlayNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return false;
    final t = title.trim().isEmpty ? 'Stream' : title.trim();
    try {
      final playUrl = await _resolveStalkerPlayUrl(
        url: u,
        liveSourceKind: liveSourceKind,
        streamId: streamId,
        portalKey: portalKey,
      );
      if (liveSourceKind == PortalLiveSourceKind.iptvStalker &&
          !_stalkerHandoffReady(playUrl)) {
        LivePluginEngine.engineResolveFailed();
        return false;
      }
      if (!ctx.mounted) return false;

      // Open player immediately. Stub guide paints Search/Guide chrome now;
      // full shelf attaches in the background (shelf-first, then network).
      ChannelGuide? guide = channelGuide;
      Future<ChannelGuide?>? guideFuture;
      if (guide == null &&
          !vodPlayback &&
          portalKey != null &&
          portalKey.trim().isNotEmpty) {
        guide = PortalChannelGuideOpen.stub(
          streamId: streamId ?? '',
          title: t,
          logoUrl: logoUrl,
          categoryId: categoryId,
          epgChannelId: epgChannelId,
          playUrl: playUrl,
        );
        guideFuture = PortalChannelGuideOpen.build(
          portalKey: portalKey,
          streamId: streamId ?? '',
          title: t,
          logoUrl: logoUrl,
          categoryId: categoryId,
          epgChannelId: epgChannelId,
          playUrl: playUrl,
        );
      }
      final sid = (streamId ?? '').trim();
      final pk = (portalKey ?? '').trim();
      final cat = (categoryId ?? '').trim();
      if (!vodPlayback && sid.isNotEmpty && pk.isNotEmpty) {
        unawaited(
          CategoryBarActionHost.recordWatched(
            portalKeyOrVaultKey: pk,
            streamId: sid,
          ),
        );
        final portal = await _portalForKey(pk);
        if (portal != null) {
          IptvCatalogLand.bindPortalKey(PortalAliveStore.portalKey(portal));
        } else {
          IptvCatalogLand.bindPortalKey(pk);
        }
        unawaited(IptvCatalogLand.rememberChannel(sid));
        IptvCatalogLand.armPostPlayerRestore(
          streamId: sid,
          categoryId: cat,
        );
      }
      var focusStreamId = sid;
      var focusCategoryId = cat;
      if (!ctx.mounted) return false;
      await openForjaLiveNativePlayer(
        ctx,
        sources: [
          LivePlaySource(
            url: playUrl,
            label: t,
            logoUrl: logoUrl,
            streamId: streamId,
            epgChannelId: epgChannelId,
            headers: headers ?? const {},
            liveSourceKind: liveSourceKind,
          ),
        ],
        title: t,
        subtitle: subtitle,
        logoUrl: logoUrl,
        channelGuide: guide,
        channelGuideFuture: guideFuture,
        engineContext: engineContext,
        liveSourceKind: liveSourceKind,
        titleTracksSource: false,
        vodPlayback: vodPlayback,
        onlineSubtitles: onlineSubtitles,
        onChannelChanged: vodPlayback
            ? null
            : (next) {
                final nid = next.streamId.trim();
                if (nid.isEmpty) return;
                focusStreamId = nid;
                focusCategoryId = next.categoryId.trim();
                unawaited(IptvCatalogLand.rememberChannel(nid));
                IptvCatalogLand.armPostPlayerRestore(
                  streamId: nid,
                  categoryId: focusCategoryId,
                );
              },
      );
      if (!vodPlayback && focusStreamId.isNotEmpty) {
        final restoreCtx =
            shellOverlayNavigatorKey.currentContext ??
            (ctx.mounted ? ctx : null);
        if (restoreCtx != null && restoreCtx.mounted) {
          _restoreCatalogAfterPlayer(
            context: restoreCtx,
            streamId: focusStreamId,
            categoryId: focusCategoryId,
          );
        } else {
          IptvCatalogLand.armPostPlayerRestore(
            streamId: focusStreamId,
            categoryId: focusCategoryId,
          );
          IptvCatalogLand.preferCategoryFocusOnLand = false;
          IptvCatalogLand.landEpoch.value++;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Stalker catalog rows ship `pending:` until create_link; mint before open.
  static Future<String> _resolveStalkerPlayUrl({
    required String url,
    PortalLiveSourceKind? liveSourceKind,
    String? streamId,
    String? portalKey,
  }) async {
    if (liveSourceKind != PortalLiveSourceKind.iptvStalker) return url;
    if (_stalkerHandoffReady(url)) return url;
    final cmd = (streamId ?? '').trim();
    final pk = (portalKey ?? '').trim();
    if (cmd.isEmpty || pk.isEmpty) return url;
    final portal = await _portalForKey(pk);
    if (portal == null) {
      debugPrint('[IPTV] stalker create_link: no portal for key=$pk');
      return url;
    }
    try {
      final fresh = await PortalClient.createLink(
        portal,
        cmd: cmd,
        section: 'live',
      );
      if (fresh == null || fresh.isEmpty) {
        debugPrint('[IPTV] stalker create_link empty for cmd=$cmd');
        return url;
      }
      return fresh;
    } catch (e) {
      debugPrint('[IPTV] stalker create_link failed: $e');
      return url;
    }
  }

  /// Stalker CDN links are often `.ts` / php — not m3u8/mp4.
  static bool _stalkerHandoffReady(String url) {
    final u = url.trim();
    if (u.isEmpty || u.startsWith('pending:')) return false;
    return u.startsWith('http://') || u.startsWith('https://');
  }

  static Future<Portal?> _portalForKey(String portalKey) async {
    final key = portalKey.trim();
    if (key.isEmpty) return null;
    // Vault-first — pack Add/Import never write [PortalStore] alone.
    final portals = await PortalsHost.loadVaultVerifiedPortals();
    return PortalChannelGuideOpen.matchPortal(portals, key)?.portal;
  }

  static bool _vodFromOpen(MetaOpen? open) {
    if (open == null) return false;
    if (open.extras['movie'] == true) return true;
    final kind = (open.extraString('kind') ?? '').trim().toLowerCase();
    return kind == 'vod' || kind == 'series' || kind == 'movie';
  }

  static BuiltInPlayerContext _engineContext({
    required MetaOpen? open,
    required bool vod,
  }) {
    if (vod) return BuiltInPlayerContext.vod;
    final profile = (open?.extraString('playerProfile') ??
            open?.extraString('engineContext') ??
            '')
        .trim()
        .toLowerCase();
    if (profile == 'live') return BuiltInPlayerContext.live;
    return BuiltInPlayerContext.iptv;
  }

  static PortalLiveSourceKind? _liveSourceKindFromOpen(
    MetaOpen? open, {
    required bool vod,
  }) {
    if (vod || open == null) return null;
    final platform = (open.extraString('platform') ?? '').trim().toLowerCase();
    if (platform == 'stalker') return PortalLiveSourceKind.iptvStalker;
    if (platform == 'xtream' ||
        platform == 'm3u' ||
        platform == 'm3u8' ||
        platform.isEmpty) {
      // IPTV live rows default to Xtream-style recovery when platform omitted.
      return PortalLiveSourceKind.iptvXtream;
    }
    return null;
  }

  static Map<String, String>? _headersFromOpen(MetaOpen? open) {
    if (open == null) return null;
    final raw = open.extras['headers'] ?? open.extras['requestHeaders'];
    if (raw is! Map) return null;
    final out = <String, String>{};
    for (final e in raw.entries) {
      final k = e.key.toString().trim();
      final v = e.value?.toString() ?? '';
      if (k.isEmpty || v.isEmpty) continue;
      out[k] = v;
    }
    return out.isEmpty ? null : out;
  }

  /// Scroll/highlight (and TV-focus) the Live channel after the player pops.
  static void _restoreCatalogAfterPlayer({
    required BuildContext context,
    required String streamId,
    required String categoryId,
  }) {
    IptvCatalogLand.takePendingRestore();
    void selectCategory(String id) {
      final scope = LayoutScope.maybeOf(context);
      scope?.onSelect(IptvCatalogLand.catsRowId, id, toggle: false);
    }

    final selected =
        LayoutScope.maybeOf(context)?.selectedId(IptvCatalogLand.catsRowId);
    IptvCatalogLand.restoreAfterPlayback(
      streamId: streamId,
      categoryId: categoryId,
      selectCategory: selectCategory,
      // Keep Favorites / Already watched / search when the channel is still
      // in the painted filter; otherwise open the channel's real group.
      streamVisibleInFilter: IptvCatalogLand.streamVisibleInFilter,
      selectedCategoryId: selected,
    );
  }
}
