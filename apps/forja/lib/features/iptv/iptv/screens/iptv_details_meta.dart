import 'package:flutter/material.dart';
import 'package:forja/shared/widgets/hero/hero_meta_line.dart';
import 'package:forja/shared/widgets/hero/hero_utils.dart';
import 'package:forja/shared/widgets/media_details/media_details_recommendations_section.dart';
import 'package:forja/shared/widgets/media_details_cast_section.dart';
import 'package:forja/shared/widgets/media_details_trailers_section.dart';
import 'package:forja/shell/app_router.dart';
import 'package:rust/rust.dart';

/// Portal-only fallback when TMDB match is missing.
List<MapEntry<String, String>> iptvPortalFacts({
  int? year,
  int? seasons,
  int? episodes,
  String? portal,
  int? runtimeMinutes,
}) {
  return [
    if (year != null) MapEntry('Year', '$year'),
    if (runtimeMinutes != null && runtimeMinutes > 0)
      MapEntry('Runtime', '${runtimeMinutes}m'),
    if (seasons != null && seasons > 0) MapEntry('Seasons', '$seasons'),
    if (episodes != null && episodes > 0) MapEntry('Episodes', '$episodes'),
    if (portal != null && portal.trim().isNotEmpty)
      MapEntry('Portal', portal.trim()),
  ];
}

/// Same row set as [HeroFactsPanel] on Home details (TMDB-first).
List<MapEntry<String, String>> iptvTmdbFacts(
  RichMediaDetails? rich, {
  List<MapEntry<String, String>> fallback = const [],
  bool? preferTv,
}) {
  if (rich == null) return fallback;
  final movie = rich.movie;
  final extras = rich.extras;
  final isTv = preferTv ?? (movie.mediaType == 'tv');
  final status = extras.status.trim();
  final language = () {
    final code = extras.originalLanguage.trim();
    if (code.isNotEmpty) return code.toUpperCase();
    if (extras.spokenLanguages.isNotEmpty) {
      final first = extras.spokenLanguages.first;
      return first.length <= 3 ? first.toUpperCase() : first;
    }
    return '';
  }();
  final firstAired = _formatIptvFactDate(movie.releaseDate);
  final lastAired = isTv ? _formatIptvFactDate(extras.lastAirDate) : '';
  final runtime = !isTv && movie.runtime > 0
      ? HeroMetaLine.formatRuntime(movie.runtime)
      : '';
  final networks = extras.networks.where((s) => s.trim().isNotEmpty).toList();
  final companies =
      extras.productionCompanies.where((s) => s.trim().isNotEmpty).toList();
  final origins =
      extras.originCountries.where((s) => s.trim().isNotEmpty).toList();
  final creators = extras.creators.where((s) => s.trim().isNotEmpty).toList();
  final director = pickDirectorFromCrew(extras.crew);

  final rows = <MapEntry<String, String>>[
    if (status.isNotEmpty) MapEntry('Status', status),
    if (language.isNotEmpty) MapEntry('Language', language),
    if (isTv) ...[
      if (firstAired.isNotEmpty) MapEntry('First Aired', firstAired),
      if (lastAired.isNotEmpty) MapEntry('Last Aired', lastAired),
      if (movie.numberOfSeasons > 0)
        MapEntry('Seasons', '${movie.numberOfSeasons}'),
      if (movie.numberOfEpisodes > 0)
        MapEntry('Episodes', '${movie.numberOfEpisodes}'),
      if (networks.isNotEmpty) MapEntry('Network', networks.join(', ')),
    ] else ...[
      if (firstAired.isNotEmpty) MapEntry('Release Date', firstAired),
      if (runtime.isNotEmpty) MapEntry('Runtime', runtime),
    ],
    if (companies.isNotEmpty) MapEntry('Production', companies.join(', ')),
    if (origins.isNotEmpty) MapEntry('Origin', origins.join(', ')),
    if (isTv && creators.isNotEmpty)
      MapEntry('Created by', creators.join(', ')),
    if (!isTv && director != null && director.isNotEmpty)
      MapEntry('Director', director),
    if (!isTv && extras.budget > 0)
      MapEntry('Budget', _formatIptvMoney(extras.budget)),
    if (!isTv && extras.revenue > 0)
      MapEntry('Revenue', _formatIptvMoney(extras.revenue)),
  ];
  return rows.isEmpty ? fallback : rows;
}

String _formatIptvFactDate(String iso) {
  if (iso.length < 10) return iso.trim();
  try {
    final d = DateTime.parse(iso);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  } catch (_) {
    return iso.trim();
  }
}

String _formatIptvMoney(int amount) {
  if (amount <= 0) return '';
  final s = amount.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '\$${buf.toString()}';
}

List<Map<String, String>> iptvCrewAsCast(List<Map<String, String>> crew) {
  return [
    for (final c in crew)
      if ((c['name'] ?? '').trim().isNotEmpty)
        {
          'name': c['name']!,
          'character': (c['job'] ?? '').trim(),
          'profilePath': (c['profilePath'] ?? '').trim(),
        },
  ];
}

/// Cast / Crew / Trailers / Recommendations — same rows as home details.
List<Widget> buildIptvDetailsMetaSections({
  required BuildContext context,
  required RichMediaDetails? rich,
  required bool tvFocus,
  required String tvTabId,
  required int tvRowOrderBase,
  VoidCallback? tvFocusUp,
  String castTitle = 'Cast',
}) {
  if (rich == null) return const [];
  final cast = rich.extras.cast;
  final crew = iptvCrewAsCast(rich.extras.crew);
  final trailers = rich.extras.trailers;
  final recommendations = rich.extras.recommendations;
  final showCast = cast.isNotEmpty;
  final showCrew = crew.isNotEmpty;
  final showTrailers = trailers.isNotEmpty;
  final showRecs = recommendations.isNotEmpty;
  if (!showCast && !showCrew && !showTrailers && !showRecs) {
    return const [];
  }

  var order = tvRowOrderBase;
  final castOrder = showCast ? order++ : null;
  final crewOrder = showCrew ? order++ : null;
  final trailersOrder = showTrailers ? order++ : null;
  final recsOrder = showRecs ? order : null;

  return [
    if (showCast)
      MediaDetailsCastSection(
        cast: cast,
        title: castTitle,
        tvTabId: tvFocus ? tvTabId : null,
        tvRowId: 'cast',
        tvRowOrder: castOrder!,
        tvFocusUp: tvFocusUp,
      ),
    if (showCrew)
      MediaDetailsCastSection(
        cast: crew,
        title: 'Crew',
        tvTabId: tvFocus ? tvTabId : null,
        tvRowId: 'crew',
        tvRowOrder: crewOrder!,
        tvFocusUp: showCast ? null : tvFocusUp,
      ),
    if (showTrailers)
      MediaDetailsTrailersSection(
        trailers: trailers,
        tvTabId: tvFocus ? tvTabId : null,
        tvRowId: 'trailers',
        tvRowOrder: trailersOrder!,
        tvFocusUp: (showCast || showCrew) ? null : tvFocusUp,
      ),
    if (showRecs)
      MediaDetailsRecommendationsSection(
        movies: recommendations,
        onMovieTap: (movie) => AppRouter.openDetails(context, movie: movie),
        tvTabId: tvFocus ? tvTabId : null,
        tvRowId: 'recommendations',
        tvRowOrder: recsOrder!,
        tvFocusUp: (showCast || showCrew || showTrailers) ? null : tvFocusUp,
      ),
  ];
}
