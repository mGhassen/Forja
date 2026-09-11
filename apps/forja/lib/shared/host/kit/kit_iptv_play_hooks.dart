import 'package:flutter/widgets.dart';
import 'package:forja/shared/playback/play_context.dart';
import 'package:forja/shared/foundation/protocol/protocol.dart';
import 'package:rust/rust.dart' show BuiltInPlayerContext, Movie;

/// Kit-facing IPTV recommendation row (feature fills [stream]).
class KitIptvRecHit {
  const KitIptvRecHit({required this.movie, required this.stream});

  final Movie movie;
  final Object stream;
}

typedef KitIptvPortalResolver = Future<Object?> Function(MetaItem meta);

typedef KitIptvCatalogRecsLoader = Future<List<KitIptvRecHit>> Function({
  required MetaItem meta,
  required Object portal,
  required Object? shelf,
  required Object? rich,
});

typedef KitIptvVodOpener = Future<void> Function(
  BuildContext context, {
  required Object stream,
  required Object portal,
});

typedef KitIptvPortalPlayFromContext = Future<void> Function({
  required BuildContext context,
  required PlayContext ctx,
});

typedef KitIptvHubDetailsParams = Map<String, dynamic> Function(MetaItem seed);

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

/// IPTV / live playback hooks — features register; foundation never imports IPTV.
abstract final class KitIptvPlayHooks {
  KitIptvPlayHooks._();

  static KitIptvPortalResolver? resolvePortalFromMeta;
  static KitIptvHubDetailsParams? hubDetailsParams;
  static KitIptvCatalogRecsLoader? loadCatalogRecs;
  static KitIptvVodOpener? openVodStream;
  static KitIptvPortalPlayFromContext? playPortalFromContext;
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
