import 'package:flutter/widgets.dart';
import 'package:forja/shared/playback/play_context.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:rust/rust.dart' show BuiltInPlayerContext, Movie;

/// Kit-facing stream recommendation row (feature fills [stream]).
class KitStreamRecHit {
  const KitStreamRecHit({required this.movie, required this.stream});

  final Movie movie;
  final Object stream;
}

typedef KitStreamPortalResolver = Future<Object?> Function(MetaItem meta);

typedef KitStreamCatalogRecsLoader = Future<List<KitStreamRecHit>> Function({
  required MetaItem meta,
  required Object portal,
  required Object? shelf,
  required Object? rich,
});

typedef KitStreamVodOpener = Future<void> Function(
  BuildContext context, {
  required Object stream,
  required Object portal,
});

typedef KitStreamPortalPlayFromContext = Future<void> Function({
  required BuildContext context,
  required PlayContext ctx,
});

typedef KitStreamHubDetailsParams = Map<String, dynamic> Function(MetaItem seed);

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

  static KitStreamPortalResolver? resolvePortalFromMeta;
  static KitStreamHubDetailsParams? hubDetailsParams;
  static KitStreamCatalogRecsLoader? loadCatalogRecs;
  static KitStreamVodOpener? openVodStream;
  static KitStreamPortalPlayFromContext? playPortalFromContext;
  static KitLiveNativePlayerOpener? openLiveNativePlayer;
  static Future<Object?> Function()? loadActiveLiveShelf;

  static void clear() {
    resolvePortalFromMeta = null;
    hubDetailsParams = null;
    loadCatalogRecs = null;
    openVodStream = null;
    playPortalFromContext = null;
    openLiveNativePlayer = null;
    loadActiveLiveShelf = null;
  }
}
