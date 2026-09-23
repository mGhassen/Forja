import 'package:flutter/material.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/player/live/pt_player_screen.dart';
import 'package:forja/shared/player/live_sports/live_sports_player_screen.dart';
import 'package:forja/shared/platform/platform_channel.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja_foundation/widgets/guide/channel_guide.dart';
import 'package:rust/rust.dart' show BuiltInPlayerContext;

/// Forja platform service: open the native live player for the right surface.
///
/// Live Sports (`BuiltInPlayerContext.live`, Stremio / liveEngine) →
/// [LiveSportsPlayerScreen]. IPTV / VOD → [PtPlayerScreen].
Future<void> openForjaLiveNativePlayer(
  BuildContext context, {
  required List<LivePlaySource> sources,
  required String title,
  String? subtitle,
  String? logoUrl,
  ChannelGuide? channelGuide,
  /// When set, player opens immediately; guide attaches when the future completes.
  Future<ChannelGuide?>? channelGuideFuture,
  BuiltInPlayerContext engineContext = BuiltInPlayerContext.live,
  PortalLiveSourceKind? liveSourceKind,
  PortalLiveEngineResolveSource? liveEngineResolveSource,
  bool titleTracksSource = true,
  bool vodPlayback = false,
  bool onlineSubtitles = false,
  ValueChanged<PortalStream>? onChannelChanged,
}) async {
  if (sources.isEmpty) return;
  if (!context.mounted) return;

  final kind = liveSourceKind ?? sources.first.liveSourceKind;
  final sportsSurface = !vodPlayback &&
      (engineContext == BuiltInPlayerContext.live ||
          kind == PortalLiveSourceKind.stremio ||
          kind == PortalLiveSourceKind.liveEngine);

  try {
    if (PlatformInfo.isAndroidTv) {
      await PlatformChannel.releaseUnderlayPlatformViewFocus();
    }
    if (!context.mounted) return;

    if (sportsSurface) {
      LiveSportsPlayerScreen buildSports(ChannelGuide? guide) =>
          LiveSportsPlayerScreen(
            sources: sources,
            title: title,
            subtitle: subtitle,
            logoUrl: logoUrl,
            channelGuide: guide,
            titleTracksSource: titleTracksSource,
            engineContext: BuiltInPlayerContext.live,
            liveSourceKind: kind,
            liveEngineResolveSource: liveEngineResolveSource,
            vodPlayback: false,
            onlineSubtitles: onlineSubtitles,
            onChannelChanged: onChannelChanged,
          );
      final Widget player;
      if (channelGuideFuture != null) {
        player = _DeferredChannelGuideLivePlayer(
          guideFuture: channelGuideFuture,
          initialGuide: channelGuide,
          builder: buildSports,
        );
      } else {
        player = buildSports(channelGuide);
      }
      await LiveSportsPlayerScreen.open(context, player);
      return;
    }

    PtPlayerScreen buildIptv(ChannelGuide? guide) => PtPlayerScreen(
          sources: sources,
          title: title,
          subtitle: subtitle,
          logoUrl: logoUrl,
          channelGuide: guide,
          titleTracksSource: titleTracksSource,
          engineContext: engineContext,
          liveSourceKind: kind,
          liveEngineResolveSource: liveEngineResolveSource,
          vodPlayback: vodPlayback,
          onlineSubtitles: onlineSubtitles,
          onChannelChanged: onChannelChanged,
        );
    final Widget player;
    if (channelGuideFuture != null) {
      player = _DeferredChannelGuideLivePlayer(
        guideFuture: channelGuideFuture,
        initialGuide: channelGuide,
        builder: buildIptv,
      );
    } else {
      player = buildIptv(channelGuide);
    }
    await PtPlayerScreen.open(context, player);
  } catch (_) {}
}

/// Opens a live player now; swaps in [guideFuture] without remounting playback.
class _DeferredChannelGuideLivePlayer extends StatefulWidget {
  const _DeferredChannelGuideLivePlayer({
    required this.guideFuture,
    required this.builder,
    this.initialGuide,
  });

  final Future<ChannelGuide?> guideFuture;
  final ChannelGuide? initialGuide;
  final Widget Function(ChannelGuide? guide) builder;

  @override
  State<_DeferredChannelGuideLivePlayer> createState() =>
      _DeferredChannelGuideLivePlayerState();
}

class _DeferredChannelGuideLivePlayerState
    extends State<_DeferredChannelGuideLivePlayer> {
  ChannelGuide? _guide;

  @override
  void initState() {
    super.initState();
    _guide = widget.initialGuide;
    widget.guideFuture.then((g) {
      if (!mounted || g == null) return;
      setState(() => _guide = g);
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(_guide);
}
