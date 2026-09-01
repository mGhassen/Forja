import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/engine/categories.dart';
import 'package:rust/rust.dart';

/// Resolved engine extract inputs from pack [CatalogOpen.extract].
class EngineExtractContext {
  const EngineExtractContext({
    required this.resolveType,
    required this.panelCategory,
    this.ctx = const {},
  });

  /// Opaque extract type from the pack (`movie`, `tv`, or any plugin type).
  final String resolveType;

  /// Opaque panel bucket from the pack — used for Sources chip prefs only.
  final String panelCategory;
  final Map<String, dynamic> ctx;

  int? intVal(String key) {
    final v = ctx[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  String? strVal(String key) {
    final v = ctx[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}

int? extractCtxInt(Map<String, dynamic> ctx, String key) {
  final v = ctx[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '');
}

EngineExtractContext _mergeEpisodeIntoCtx(
  CatalogOpenExtract spec,
  int? episode,
  String? episodeVideoId,
) {
  final ctx = Map<String, dynamic>.from(spec.ctx);
  final epVid = (episodeVideoId ?? '').trim();
  if (epVid.isNotEmpty) ctx['episodeVideoId'] = epVid;
  if (episode != null && episode > 0) {
    ctx.putIfAbsent('episode', () => episode);
  }
  return EngineExtractContext(
    resolveType: spec.resolveType,
    panelCategory: spec.panelCategory,
    ctx: ctx,
  );
}

/// Build extract + panel category from catalog open and/or movie/TV details hints.
EngineExtractContext engineExtractContext({
  CatalogOpen? catalogOpen,
  required Movie movie,
  int? episode,
  String? episodeVideoId,
  String? panelCategoryHint,
}) {
  final open = catalogOpen;
  if (open != null) {
    return _mergeEpisodeIntoCtx(
      open.effectiveExtract,
      episode,
      episodeVideoId,
    );
  }

  final hint = panelCategoryHint?.trim();
  final panel = (hint != null && hint.isNotEmpty)
      ? hint
      : EngineCategories.panelCategoryFor(mediaType: movie.mediaType);
  final resolveType = (hint != null && hint.isNotEmpty)
      ? hint
      : (movie.mediaType == 'tv' || movie.mediaType == 'series' ? 'tv' : 'movie');
  return EngineExtractContext(
    resolveType: resolveType,
    panelCategory: panel,
    ctx: const {},
  );
}

/// Opaque session-cache segment for a hub title/episode.
String catalogOpenCacheKey(
  CatalogOpen open, {
  required String pluginId,
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
  final vidSuffix = vid.isNotEmpty ? ':$vid' : '';
  return '$pluginId:$id:E$ep$audioSuffix$vidSuffix';
}

String? providerIdFromEpisodeVideoId(String videoId) {
  final i = videoId.indexOf(':');
  if (i <= 0) return null;
  final id = videoId.substring(0, i).trim();
  if (id.isEmpty) return null;
  // Home TMDB TV episodes use `{tmdbId}:S{n}E{m}` — not `provider:opaque`.
  if (RegExp(r'^\d+$').hasMatch(id)) return null;
  return id;
}

/// Merges [catalogOpen] extract when present; otherwise TMDB-details hints only.
({String type, String panelCategory, Map<String, dynamic> ctx})
    resolveEngineExtractInputs({
  required String type,
  required Movie? movie,
  CatalogOpen? catalogOpen,
  String? episodeVideoId,
  int? episode,
  String? panelCategoryHint,
}) {
  if (catalogOpen != null && movie != null) {
    final ctx = engineExtractContext(
      catalogOpen: catalogOpen,
      movie: movie,
      episode: episode,
      episodeVideoId: episodeVideoId,
      panelCategoryHint: panelCategoryHint ?? type,
    );
    return (
      type: ctx.resolveType,
      panelCategory: ctx.panelCategory,
      ctx: ctx.ctx,
    );
  }
  return (
    type: type,
    panelCategory: panelCategoryHint ?? type,
    ctx: const {},
  );
}
