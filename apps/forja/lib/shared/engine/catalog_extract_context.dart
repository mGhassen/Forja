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

  final String resolveType;
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

  /// Rust FFI bridge — reads keys from opaque [ctx] only.
  int? get malId => intVal('malId');
  int? get anilistId => intVal('anilistId');
  int? get kisskhId => intVal('kisskhId');
  int? get kisskhEpisodeId => intVal('kisskhEpisodeId');
  String? get arabicVideoId => strVal('arabicVideoId') ?? strVal('videoId');

  bool get hasAnimeIds => (anilistId ?? 0) > 0 || (malId ?? 0) > 0;
}

EngineExtractContext _mergeEpisodeIntoCtx(
  CatalogOpenExtract spec,
  int? episode,
  String? episodeVideoId,
  int? malId,
) {
  final ctx = Map<String, dynamic>.from(spec.ctx);
  if (malId != null && malId > 0) ctx['malId'] = malId;
  final epVid = (episodeVideoId ?? '').trim();
  if (epVid.isNotEmpty) {
    ctx['episodeVideoId'] = epVid;
    final epInt = int.tryParse(epVid);
    if (epInt != null) {
      ctx.putIfAbsent('kisskhEpisodeId', () => epInt);
    }
    ctx.putIfAbsent('arabicVideoId', () => epVid);
    ctx.putIfAbsent('videoId', () => epVid);
  }
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
  int? malId,
  String? panelCategoryHint,
}) {
  final open = catalogOpen;
  if (open != null) {
    return _mergeEpisodeIntoCtx(
      open.effectiveExtract,
      episode,
      episodeVideoId,
      malId,
    );
  }

  final panel = EngineCategories.panelCategoryFor(
    mediaType: movie.mediaType,
    panelCategory: panelCategoryHint,
    hasAnimeIds: false,
  );
  return EngineExtractContext(
    resolveType: _resolveTypeForPanelCategory(panel, movie),
    panelCategory: panel,
    ctx: malId != null && malId > 0 ? {'malId': malId} : const {},
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
  return id.isEmpty ? null : id;
}

/// Merges explicit extract ids with [catalogOpen] when present.
({String type, String panelCategory, Map<String, dynamic> ctx})
    resolveEngineExtractInputs({
  required String type,
  required Movie? movie,
  CatalogOpen? catalogOpen,
  String? episodeVideoId,
  int? episode,
  int? malId,
  Map<String, dynamic>? legacyCtx,
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
    final merged = Map<String, dynamic>.from(ctx.ctx);
    if (legacyCtx != null) {
      for (final e in legacyCtx.entries) {
        merged.putIfAbsent(e.key, () => e.value);
      }
    }
    return (
      type: ctx.resolveType,
      panelCategory: ctx.panelCategory,
      ctx: merged,
    );
  }
  return (
    type: type,
    panelCategory: panelCategoryHint ?? type,
    ctx: legacyCtx ?? const {},
  );
}

/// Bridge opaque [ctx] to legacy Rust extract param names (engine layer only).
({
  int? malId,
  int? anilistId,
  int? kisskhId,
  int? kisskhEpisodeId,
  String? arabicVideoId,
}) engineCtxToLegacyIds(Map<String, dynamic> ctx) {
  int? pickInt(String k) {
    final v = ctx[k];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  String? pickStr(String k) {
    final v = ctx[k];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  return (
    malId: pickInt('malId'),
    anilistId: pickInt('anilistId'),
    kisskhId: pickInt('kisskhId'),
    kisskhEpisodeId: pickInt('kisskhEpisodeId'),
    arabicVideoId: pickStr('arabicVideoId') ?? pickStr('videoId'),
  );
}
