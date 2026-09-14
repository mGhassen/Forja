import 'package:flutter/widgets.dart';
import 'package:forja/shared/player/live/hooks/live_play.dart';
import 'package:forja/shared/player/live/hooks/resolve_streams_adapter.dart';
import 'package:forja/shared/player/live/lazy_url_health.dart';
import 'package:forja/shared/player/live/pt_player_screen.dart';
import 'package:forja/shared/player/sources/pack_stream_play_hooks.dart';
import 'package:forja/shared/player/sources/resolve_streams_hooks.dart';
import 'package:forja/shared/player/sources/stream_play_hooks.dart';
import 'package:rust/rust.dart' show BuiltInPlayerContext;

/// Boots generic stream / live play + resolve hooks (no IPTV product screens).
abstract final class LiveKitHooksRegister {
  LiveKitHooksRegister._();

  static void ensureRegistered() {
    PackStreamPlayHooks.ensureRegistered();

    KitStreamPlayHooks.openLiveNativePlayer = _openLiveNativePlayer;

    KitResolveStreamsHooks.loadTab = ResolveStreamsAdapter.loadTab;
    KitResolveStreamsHooks.playRow = ResolveStreamsAdapter.playRow;
    KitResolveStreamsHooks.createHealthProbe = ({onResult}) =>
        LazyUrlHealthProbe(onResult: onResult);
  }

  static Future<void> _openLiveNativePlayer(
    BuildContext context, {
    required List<dynamic> sources,
    required String title,
    String? subtitle,
    String? logoUrl,
    BuiltInPlayerContext engineContext = BuiltInPlayerContext.live,
    dynamic liveSourceKind,
    dynamic liveEngineResolveSource,
    bool titleTracksSource = true,
    bool vodPlayback = false,
    bool onlineSubtitles = false,
  }) async {
    final typed = <LivePlaySource>[
      for (final s in sources)
        if (s is LivePlaySource) s,
    ];
    await openForjaLiveNativePlayer(
      context,
      sources: typed,
      title: title,
      subtitle: subtitle,
      logoUrl: logoUrl,
      engineContext: engineContext,
      liveSourceKind: liveSourceKind is IptvLiveSourceKind
          ? liveSourceKind
          : null,
      liveEngineResolveSource:
          liveEngineResolveSource is IptvLiveEngineResolveSource
              ? liveEngineResolveSource
              : null,
      titleTracksSource: titleTracksSource,
      vodPlayback: vodPlayback,
      onlineSubtitles: onlineSubtitles,
    );
  }
}
