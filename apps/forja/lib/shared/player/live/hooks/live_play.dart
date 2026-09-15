import 'package:flutter/material.dart';
import 'package:forja/shared/player/live/pt_player_screen.dart';
import 'package:forja/shared/platform/platform_channel.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja_foundation/widgets/guide/channel_guide.dart';
import 'package:rust/rust.dart' show BuiltInPlayerContext;

/// Forja platform service: open the shared native live player.
///
/// Live Sports (and any sports hub that resolves to [LivePlaySource]) uses this
/// instead of embedding a feature-private player. Peer of portal play in
/// [iptv_play.dart].
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
}) async {
  if (sources.isEmpty) return;
  if (!context.mounted) return;

  try {
    if (PlatformInfo.isAndroidTv) {
      await PlatformChannel.releaseUnderlayPlatformViewFocus();
    }
    if (!context.mounted) return;
    PtPlayerScreen buildPlayer(ChannelGuide? guide) => PtPlayerScreen(
          sources: sources,
          title: title,
          subtitle: subtitle,
          logoUrl: logoUrl,
          channelGuide: guide,
          titleTracksSource: titleTracksSource,
          engineContext: engineContext,
          liveSourceKind: liveSourceKind ?? sources.first.liveSourceKind,
          liveEngineResolveSource: liveEngineResolveSource,
          vodPlayback: vodPlayback,
          onlineSubtitles: onlineSubtitles,
        );
    final Widget player;
    if (channelGuideFuture != null) {
      player = _DeferredChannelGuidePtPlayer(
        guideFuture: channelGuideFuture,
        initialGuide: channelGuide,
        builder: buildPlayer,
      );
    } else {
      player = buildPlayer(channelGuide);
    }
    await PtPlayerScreen.open(context, player);
  } catch (_) {}
}

/// Opens [PtPlayerScreen] now; swaps in [guideFuture] without remounting playback.
class _DeferredChannelGuidePtPlayer extends StatefulWidget {
  const _DeferredChannelGuidePtPlayer({
    required this.guideFuture,
    required this.builder,
    this.initialGuide,
  });

  final Future<ChannelGuide?> guideFuture;
  final ChannelGuide? initialGuide;
  final PtPlayerScreen Function(ChannelGuide? guide) builder;

  @override
  State<_DeferredChannelGuidePtPlayer> createState() =>
      _DeferredChannelGuidePtPlayerState();
}

class _DeferredChannelGuidePtPlayerState
    extends State<_DeferredChannelGuidePtPlayer> {
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
