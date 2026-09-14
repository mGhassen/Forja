import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shell/routing/shell_overlay_navigator.dart';
import 'package:forja/shared/engine/runtime/open/meta_surface_open.dart';
import 'package:forja/shared/player/live/hooks/live_play.dart';
import 'package:forja/shared/player/live/pt_player_screen.dart';
import 'package:forja_foundation/protocol/protocol.dart';
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
    Map<String, String>? headers,
    PortalLiveSourceKind? liveSourceKind,
    BuiltInPlayerContext engineContext = BuiltInPlayerContext.iptv,
    bool vodPlayback = false,
    bool onlineSubtitles = false,
  }) async {
    final u = url.trim();
    if (u.isEmpty) return false;
    final ctx = context ?? shellOverlayNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return false;
    final t = title.trim().isEmpty ? 'Stream' : title.trim();
    try {
      await openForjaLiveNativePlayer(
        ctx,
        sources: [
          LivePlaySource(
            url: u,
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
        engineContext: engineContext,
        liveSourceKind: liveSourceKind,
        titleTracksSource: false,
        vodPlayback: vodPlayback,
        onlineSubtitles: onlineSubtitles,
      );
      return true;
    } catch (_) {
      return false;
    }
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
}
