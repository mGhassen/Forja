import 'package:flutter/material.dart';
import 'package:forja/features/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/shared/platform/platform_channel.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:rust/rust.dart' show BuiltInPlayerContext;

/// Forja platform service: open the shared native live player.
///
/// Live Sports (and any sports hub that resolves to [IptvPlaySource]) uses this
/// instead of embedding a feature-private player. Peer of portal play in
/// [iptv_play.dart].
Future<void> openForjaLiveNativePlayer(
  BuildContext context, {
  required List<IptvPlaySource> sources,
  required String title,
  String? subtitle,
  String? logoUrl,
  BuiltInPlayerContext engineContext = BuiltInPlayerContext.live,
  IptvLiveSourceKind? liveSourceKind,
  IptvLiveEngineResolveSource? liveEngineResolveSource,
  bool titleTracksSource = true,
  bool vodPlayback = false,
  bool onlineSubtitles = false,
}) async {
  if (sources.isEmpty) return;
  if (!context.mounted) return;

  try {
    if (PlatformInfo.isAndroidTv) {
      await PlatformChannel.releaseUnderlayPlatformViewFocus();
    }
    if (!context.mounted) return;
    await IptvPtPlayerScreen.open(
      context,
      IptvPtPlayerScreen(
        sources: sources,
        title: title,
        subtitle: subtitle,
        logoUrl: logoUrl,
        titleTracksSource: titleTracksSource,
        engineContext: engineContext,
        liveSourceKind: liveSourceKind ?? sources.first.liveSourceKind,
        liveEngineResolveSource: liveEngineResolveSource,
        vodPlayback: vodPlayback,
        onlineSubtitles: onlineSubtitles,
      ),
    );
  } catch (_) {}
}
