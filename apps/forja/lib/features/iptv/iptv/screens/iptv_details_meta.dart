import 'package:flutter/material.dart';
import 'package:forja/shared/widgets/hero/hero_utils.dart';
import 'package:forja/shared/widgets/media_details/media_details_recommendations_section.dart';
import 'package:forja/shared/widgets/media_details_cast_section.dart';
import 'package:forja/shared/widgets/media_details_trailers_section.dart';
import 'package:forja/shell/app_router.dart';
import 'package:rust/rust.dart';

List<MapEntry<String, String>> iptvTmdbFacts(
  RichMediaDetails? rich, {
  List<MapEntry<String, String>> base = const [],
}) {
  final extras = rich?.extras;
  final director = extras == null ? null : pickDirectorFromCrew(extras.crew);
  final creators = extras?.creators ?? const <String>[];
  final networks = extras?.networks ?? const <String>[];
  final languages = extras?.spokenLanguages ?? const <String>[];
  final companies = extras?.productionCompanies ?? const <String>[];
  return [
    ...base,
    if (director != null && director.isNotEmpty)
      MapEntry('Director', director),
    if (creators.isNotEmpty)
      MapEntry('Created by', creators.take(3).join(', ')),
    if (networks.isNotEmpty)
      MapEntry('Network', networks.take(2).join(', ')),
    if (languages.isNotEmpty)
      MapEntry('Language', languages.take(2).join(', ')),
    if (companies.isNotEmpty)
      MapEntry('Studio', companies.take(2).join(', ')),
  ];
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
