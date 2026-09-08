import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/blocks/details/kit_details_screen.dart';
import 'package:forja/shared/foundation/protocol/protocol.dart';
import 'package:forja/shared/foundation/services/registry/meta_surface_open.dart';

/// In-flight opens keyed by `pluginId + item.id` — blocks stacked details from
/// double-tap / re-click while the first navigation is alive.
final Set<String> _metaOpenInFlight = {};

/// TMDB details expect the relative `/abc.jpg` path, not the CDN URL a
/// catalog plugin ships for cards.
String catalogTmdbImagePath(String url) {
  if (url.isEmpty) return '';
  final m = RegExp(r'image\.tmdb\.org/t/p/[^/]+(/.+)$').firstMatch(url);
  return m?.group(1) ?? url;
}

bool metaOpenUsesKitDetails(MetaOpen open) =>
    !_openUsesFeatureDetailsRoute(open) &&
    MetaSurfaceOpen.resolve(open.surface) == null;

bool _openUsesFeatureDetailsRoute(MetaOpen open) {
  final route = open.extraString('detailsRoute') ??
      open.extraString('featureRoute');
  return route != null && route.isNotEmpty;
}

/// Open details from hub meta already on the shell (rail / hero / search).
Future<void> openMetaItem(
  BuildContext context, {
  required String pluginId,
  required MetaItem item,
  String? shellTabId,
  int? initialSeason,
  int? initialEpisode,
  Duration? startPosition,
  bool autoPlay = false,
}) async {
  final key = '$pluginId\x1f${item.id}';
  if (!_metaOpenInFlight.add(key)) return;
  try {
    if (!context.mounted) return;
    final surface = item.open?.surface.trim() ?? '';
    final surfaceHandler =
        surface.isEmpty ? null : MetaSurfaceOpen.resolve(surface);
    if (surfaceHandler != null) {
      surfaceHandler(context, item);
      return;
    }
    // Opaque type token some packs use without `open.surface`.
    if (item.type == 'live_match') {
      final live = MetaSurfaceOpen.resolve('live');
      if (live != null) {
        live(context, item);
        return;
      }
    }
    await openKitDetails(
      context,
      pluginId: pluginId,
      item: item,
      shellTabId: shellTabId,
      initialSeason: initialSeason,
      initialEpisode: initialEpisode,
      startPosition: startPosition,
      autoPlay: autoPlay,
    );
  } finally {
    _metaOpenInFlight.remove(key);
  }
}
