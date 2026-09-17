import 'package:flutter/material.dart';
import 'package:forja/shared/engine/details/pack_details_host.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shared/engine/runtime/open/meta_surface_open.dart';

/// In-flight opens keyed by `pluginId + item.id` — blocks stacked details from
/// double-tap / re-click while the first navigation is alive.
final Set<String> _metaOpenInFlight = {};

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

/// Engine type used to pick the details hub for [item.open].
@visibleForTesting
String? detailsEngineTypeForOpen(MetaItem item) {
  final surface = item.open?.surface.trim() ?? '';
  if (surface == 'tmdb') return tmdbCatalogTypeToken(item);
  if (surface.isNotEmpty && surface != 'live') return surface;
  final t = item.type.trim().toLowerCase();
  if (t.isEmpty || t == 'list') return null;
  return t;
}

/// Remap away from the tap source when it cannot serve details, or when open
/// is TMDB (cross-hub rails / My List).
@visibleForTesting
bool shouldResolveOpenPluginAwayFromCaller({
  required bool callerHasDetails,
  required MetaItem item,
}) {
  final surface = item.open?.surface.trim() ?? '';
  if (surface == 'tmdb') return true;
  if (!callerHasDetails && detailsEngineTypeForOpen(item) != null) {
    return true;
  }
  return false;
}

/// Resolve the pack that should run `action: details` for [item].
///
/// Kit feeds (My List) pass their own plugin id on tap — remap to the hub that
/// owns [item.open.surface] when the caller has no `details` capability.
/// TMDB open always remaps (Asian Drama More Like This, etc.).
Future<String> resolveOpenPluginId({
  required String pluginId,
  required MetaItem item,
}) async {
  final callerHasDetails =
      await PluginNavRegistry.pluginHasDetails(pluginId);
  if (!shouldResolveOpenPluginAwayFromCaller(
    callerHasDetails: callerHasDetails,
    item: item,
  )) {
    return pluginId;
  }
  final engineType = detailsEngineTypeForOpen(item);
  if (engineType == null || engineType.isEmpty) return pluginId;
  final resolved =
      await PluginNavRegistry.pluginIdForEngineType(engineType);
  if (resolved == null || resolved.isEmpty) return pluginId;
  if (await PluginNavRegistry.pluginHasDetails(resolved)) return resolved;
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
