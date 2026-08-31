import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/kit/details/hub_details_screen.dart';
import 'package:forja/shared/catalog/protocol.dart';

/// In-flight opens keyed by `pluginId + item.id` — blocks stacked details from
/// double-tap / re-click while the first navigation is alive.
final Set<String> _catalogOpenInFlight = {};

/// TMDB details expect the relative `/abc.jpg` path, not the CDN URL a
/// catalog plugin ships for cards.
String catalogTmdbImagePath(String url) {
  if (url.isEmpty) return '';
  final m = RegExp(r'image\.tmdb\.org/t/p/[^/]+(/.+)$').firstMatch(url);
  return m?.group(1) ?? url;
}

bool catalogOpenUsesHubDetails(CatalogOpen open) =>
    !_openUsesFeatureDetailsRoute(open);

bool _openUsesFeatureDetailsRoute(CatalogOpen open) {
  final route = open.extraString('detailsRoute') ??
      open.extraString('featureRoute');
  return route != null && route.isNotEmpty;
}

/// Open details from hub meta already on the shell (rail / hero / search).
Future<void> openCatalogMetaItem(
  BuildContext context, {
  required String pluginId,
  required CatalogMetaItem item,
  int? initialSeason,
  int? initialEpisode,
  Duration? startPosition,
  bool autoPlay = false,
}) async {
  final key = '$pluginId\x1f${item.id}';
  if (!_catalogOpenInFlight.add(key)) return;
  try {
    if (!context.mounted) return;
    await openHubDetails(
      context,
      pluginId: pluginId,
      item: item,
      initialSeason: initialSeason,
      initialEpisode: initialEpisode,
      startPosition: startPosition,
      autoPlay: autoPlay,
    );
  } finally {
    _catalogOpenInFlight.remove(key);
  }
}
