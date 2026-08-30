import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/engine/categories.dart';
import 'package:rust/rust.dart';

/// Resolved engine extract inputs — only layer that interprets [CatalogOpen.surface].
class EngineExtractContext {
  const EngineExtractContext({
    required this.resolveType,
    required this.panelCategory,
    this.anilistId,
    this.malId,
    this.kisskhId,
    this.kisskhEpisodeId,
    this.arabicVideoId,
  });

  /// `movie` | `tv` | `anime` | `drama` | `arabic` for plugin extract.
  final String resolveType;
  final String panelCategory;
  final int? anilistId;
  final int? malId;
  final int? kisskhId;
  final int? kisskhEpisodeId;
  final String? arabicVideoId;

  bool get hasAnimeIds => (anilistId ?? 0) > 0 || (malId ?? 0) > 0;
}

String _panelCategoryForSurface(String surface) {
  switch (surface) {
    case 'anime':
      return EngineCategories.anime;
    case 'drama':
      return EngineCategories.drama;
    case 'arabic':
      return EngineCategories.arabic;
    default:
      return EngineCategories.movie;
  }
}

String _resolveTypeForSurface(String surface, Movie movie) {
  switch (surface) {
    case 'anime':
      return 'anime';
    case 'drama':
      return 'drama';
    case 'arabic':
      return 'arabic';
    default:
      return movie.mediaType == 'tv' ? 'tv' : 'movie';
  }
}

/// Build extract + panel category from catalog open and/or movie/TV details hints.
EngineExtractContext engineExtractContext({
  CatalogOpen? catalogOpen,
  required Movie movie,
  int? episode,
  String? episodeVideoId,
  int? malId,
  String? panelCategoryHint,
}) {
  final open = catalogOpen;
  if (open != null) {
    final ep = episode ?? 1;
    final epVid = (episodeVideoId ?? '').trim();
    final surface = open.surface;
    final panel = _panelCategoryForSurface(surface);
    final resolveType = _resolveTypeForSurface(surface, movie);
    final resolvedMal =
        malId ?? int.tryParse(open.extraString('mal') ?? '');
    switch (surface) {
      case 'anime':
        return EngineExtractContext(
          resolveType: resolveType,
          panelCategory: panel,
          anilistId: open.idInt,
          malId: resolvedMal,
        );
      case 'drama':
        return EngineExtractContext(
          resolveType: resolveType,
          panelCategory: panel,
          kisskhId: open.idInt,
          kisskhEpisodeId: int.tryParse(epVid),
        );
      case 'arabic':
        final vid = epVid.isNotEmpty ? epVid : open.id.trim();
        return EngineExtractContext(
          resolveType: resolveType,
          panelCategory: panel,
          arabicVideoId: vid.isNotEmpty ? vid : null,
        );
      default:
        return EngineExtractContext(
          resolveType: resolveType,
          panelCategory: panel,
        );
    }
  }

  final panel = EngineCategories.panelCategoryFor(
    mediaType: movie.mediaType,
    panelCategory: panelCategoryHint,
    hasAnimeIds: false,
  );
  return EngineExtractContext(
    resolveType: _resolveTypeForPanelCategory(panel, movie),
    panelCategory: panel,
    malId: malId,
  );
}

String _resolveTypeForPanelCategory(String panelCategory, Movie movie) {
  if (panelCategory == EngineCategories.anime) return 'anime';
  if (panelCategory == EngineCategories.drama) return 'drama';
  if (panelCategory == EngineCategories.arabic) return 'arabic';
  return movie.mediaType == 'tv' ? 'tv' : 'movie';
}

/// Opaque session-cache segment for a hub title/episode.
String catalogOpenCacheKey(
  CatalogOpen open, {
  int? episode,
  String? audioCategory,
  String? episodeVideoId,
}) {
  final ep = (episode == null || episode < 1) ? 1 : episode;
  final audio = (audioCategory ?? '').trim().toLowerCase();
  final audioSuffix =
      (audio == 'sub' || audio == 'dub') ? ':$audio' : '';
  final id = open.id.trim();
  final vid = (episodeVideoId ?? '').trim();
  if (open.surface == 'arabic' && vid.isNotEmpty) {
    return 'arabic:$vid';
  }
  return '${open.surface}:$id:E$ep$audioSuffix';
}

String? providerIdFromEpisodeVideoId(String videoId) {
  final i = videoId.indexOf(':');
  if (i <= 0) return null;
  final id = videoId.substring(0, i).trim();
  return id.isEmpty ? null : id;
}

/// Merges explicit extract ids with [catalogOpen] when present.
({String type, int? malId, int? anilistId, int? kisskhId, int? kisskhEpisodeId, String? arabicVideoId})
    resolveEngineExtractInputs({
  required String type,
  required Movie? movie,
  CatalogOpen? catalogOpen,
  String? episodeVideoId,
  int? episode,
  int? malId,
  int? anilistId,
  int? kisskhId,
  int? kisskhEpisodeId,
  String? arabicVideoId,
  String? panelCategoryHint,
}) {
  if (catalogOpen != null && movie != null) {
    final ctx = engineExtractContext(
      catalogOpen: catalogOpen,
      movie: movie,
      episode: episode,
      episodeVideoId: episodeVideoId,
      malId: malId,
      panelCategoryHint: panelCategoryHint ?? type,
    );
    return (
      type: ctx.resolveType,
      malId: ctx.malId ?? malId,
      anilistId: ctx.anilistId ?? anilistId,
      kisskhId: ctx.kisskhId ?? kisskhId,
      kisskhEpisodeId: ctx.kisskhEpisodeId ?? kisskhEpisodeId,
      arabicVideoId: ctx.arabicVideoId ?? arabicVideoId,
    );
  }
  return (
    type: type,
    malId: malId,
    anilistId: anilistId,
    kisskhId: kisskhId,
    kisskhEpisodeId: kisskhEpisodeId,
    arabicVideoId: arabicVideoId,
  );
}
