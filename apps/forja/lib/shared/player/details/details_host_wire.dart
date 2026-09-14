import 'package:forja/shared/player/details/poster_cards.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/open/meta_movie.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shared/engine/runtime/meta/plugin_actions.dart';
import 'package:forja/shared/engine/runtime/open/catalog_open.dart';
import 'package:forja/shared/shell/tv/media_details_tv_scope.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/widgets/details/details_rails.dart';
import 'package:forja_foundation/widgets/details/facts_panel.dart';
import 'package:forja_foundation/widgets/details/pack_detail_meta.dart';
import 'package:rust/rust.dart';

export 'package:forja/shared/player/details/details_meta.dart';
export 'package:forja_foundation/widgets/details/pack_detail_meta.dart';

String? hubShellTabIdForPlugin(String pluginId) =>
    PluginNavRegistry.tabIdForPluginSync(pluginId);

/// Shell tab for the hub that owns [item].
///
/// Used when opening details so the nav rail matches the content hub, not the
/// browse tab you tapped from (e.g. My List → Anime).
Future<String?> resolveDetailsShellTabId({
  required String pluginId,
  required MetaItem item,
}) async {
  final fromPlugin = hubShellTabIdForPlugin(pluginId);
  if (fromPlugin != null && fromPlugin.isNotEmpty) return fromPlugin;

  final surface = item.open?.surface.trim() ?? '';
  String? engineType;
  if (surface == 'tmdb') {
    final media = (item.tmdbMediaType ?? item.type).trim().toLowerCase();
    engineType = media == 'tv' ? 'tv' : 'movie';
  } else if (surface.isNotEmpty && surface != 'live') {
    engineType = surface;
  } else {
    final t = item.type.trim();
    if (t.isNotEmpty) engineType = t;
  }
  if (engineType == null || engineType.isEmpty) return null;
  final hubPlugin =
      await PluginNavRegistry.pluginIdForEngineType(engineType);
  if (hubPlugin == null || hubPlugin.isEmpty) return null;
  return hubShellTabIdForPlugin(hubPlugin);
}

/// Same contract as [MetaRuntime.metaTmdbEnriched] for a parsed meta.
bool hubMetaTmdbEnriched(MetaItem meta) => MetaRuntime.metaTmdbEnriched(
      {
        ...meta.ids.isEmpty ? const <String, dynamic>{} : {'ids': meta.ids},
        'background': meta.background,
      },
    );

List<Widget> buildKitDetailRailSections({
  required BuildContext context,
  required String pluginId,
  required List<KitDetailRailSection> rails,
  required bool tvFocus,
  int tvRowOrderBase = 0,
  VoidCallback? firstMetaFocusUp,
}) {
  if (rails.isEmpty) return const [];

  var order = tvRowOrderBase;
  final sections = <Widget>[];
  for (final rail in rails) {
    final rowOrder = order++;
    // Prefix so pack `recommendations` cannot collide with TMDB row ids.
    final rowId = 'pack:${rail.id}';
    final cards = <Widget>[
      for (var index = 0; index < rail.items.length; index++)
        KitPosterCard(
          imageUrl: rail.items[index].poster,
          title: rail.items[index].name,
          subtitle: kitPosterSubtitle(rail.items[index]),
          rating: rail.items[index].rating,
          badge: kitPosterBadge(rail.items[index], pluginId: pluginId),
          listIndex: index,
          onTap: () => openMetaItem(
            context,
            pluginId: pluginId,
            item: rail.items[index],
          ),
          tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
          tvRowId: rowId,
        ),
    ];
    Widget section = DetailsRailSection(
      title: rail.title,
      cards: cards,
      rowHeight: KitPosterCard.cardHeight(context),
      compactTop: true,
    );
    if (tvFocus) {
      section = TvKitRow(
        tabId: MediaDetailsTv.tabId,
        rowId: rowId,
        sortOrder: rowOrder,
        itemCount: cards.length,
        onFocusUp: sections.isEmpty ? firstMetaFocusUp : null,
        child: section,
      );
    }
    sections.add(section);
  }
  return sections;
}

List<MediaTrailer> hubMetaTrailers(MetaItem meta) {
  if (meta.trailers.isEmpty) return const [];
  final out = <MediaTrailer>[];
  final seen = <String>{};
  for (final raw in meta.trailers) {
    final key = (raw['key'] ?? '').toString().trim();
    if (key.isEmpty || !seen.add(key)) continue;
    out.add(
      MediaTrailer(
        key: key,
        name: (raw['name'] ?? 'Trailer').toString(),
        type: (raw['type'] ?? 'Trailer').toString(),
        official: raw['official'] == true,
        site: (raw['site'] ?? 'YouTube').toString(),
      ),
    );
  }
  return out;
}

/// Host [RichMediaDetails] → foundation fact rows for [DetailsHero].
List<MapEntry<String, String>> kitRichFactRows(
  RichMediaDetails? rich, {
  int? positionMs,
  int? durationMs,
}) {
  if (rich == null) return const [];
  final rows = factsRowsFromFields(
    title: rich.movie.title,
    mediaType: rich.movie.mediaType,
    runtimeMinutes: rich.movie.runtime,
    releaseDate: rich.movie.releaseDate,
    seasonCount: rich.movie.numberOfSeasons,
    episodeCount: rich.movie.numberOfEpisodes,
    status: rich.extras.status,
    budget: rich.extras.budget,
    revenue: rich.extras.revenue,
    languageCode: rich.extras.originalLanguage,
    spokenLanguages: rich.extras.spokenLanguages,
    productionCompanies: rich.extras.productionCompanies,
    originCountries: rich.extras.originCountries,
    lastAirDate: rich.extras.lastAirDate,
    networks: rich.extras.networks,
    creators: rich.extras.creators,
    positionMs: positionMs,
    durationMs: durationMs,
  );
  return [for (final r in rows) MapEntry(r.label, r.value)];
}
