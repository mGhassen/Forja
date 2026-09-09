import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/blocks/details/kit_details_screen.dart';
import 'package:forja/shared/foundation/protocol/protocol.dart';
import 'package:forja/shared/foundation/services/nav/plugin_nav.dart';
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

/// Engine type token for resolving the TMDB catalog plugin from a meta row.
String tmdbCatalogTypeToken(MetaItem item) {
  final media = (item.tmdbMediaType ?? item.type).trim().toLowerCase();
  return media == 'tv' ? 'tv' : 'movie';
}

/// When [item.open.surface] is `tmdb`, prefer the TMDB catalog plugin even if
/// the caller still passes a browse hub id (Asian Drama More Like This, etc.).
Future<String> resolveOpenPluginId({
  required String pluginId,
  required MetaItem item,
}) async {
  final surface = item.open?.surface.trim() ?? '';
  if (surface != 'tmdb') return pluginId;
  final resolved =
      await PluginNavRegistry.pluginIdForEngineType(tmdbCatalogTypeToken(item));
  if (resolved != null && resolved.isNotEmpty) return resolved;
  return pluginId;
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
  final effectivePluginId =
      await resolveOpenPluginId(pluginId: pluginId, item: item);
  final key = '$effectivePluginId\x1f${item.id}';
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
      pluginId: effectivePluginId,
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
