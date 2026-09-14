import 'package:flutter/widgets.dart';
import 'package:forja/shared/playback/play_context.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:rust/rust.dart' show BuiltInPlayerContext;

typedef KitStreamHubDetailsParams = Map<String, dynamic> Function(MetaItem seed);

typedef KitStreamPortalPlayFromContext = Future<void> Function({
  required BuildContext context,
  required PlayContext ctx,
});

typedef KitLiveNativePlayerOpener = Future<void> Function(
  BuildContext context, {
  required List<dynamic> sources,
  required String title,
  String? subtitle,
  String? logoUrl,
  BuiltInPlayerContext engineContext,
  dynamic liveSourceKind,
  dynamic liveEngineResolveSource,
  bool titleTracksSource,
  bool vodPlayback,
  bool onlineSubtitles,
});

/// Stream / live playback hooks — host registers; foundation never imports packs.
abstract final class KitStreamPlayHooks {
  KitStreamPlayHooks._();

  static KitStreamHubDetailsParams? hubDetailsParams;
  static KitStreamPortalPlayFromContext? playPortalFromContext;
  static KitLiveNativePlayerOpener? openLiveNativePlayer;
  static Future<Object?> Function()? loadActiveLiveShelf;

  static void clear() {
    hubDetailsParams = null;
    playPortalFromContext = null;
    openLiveNativePlayer = null;
    loadActiveLiveShelf = null;
  }
}
