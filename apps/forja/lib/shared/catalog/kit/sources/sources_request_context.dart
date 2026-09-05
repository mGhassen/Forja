import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/engine/catalog_extract_context.dart';
import 'package:forja/shared/playback/torrent_js_search.dart';
import 'package:rust/rust.dart';

/// Engine extract projection from [SourcesRequestContext].
class EngineExtractSlice {
  const EngineExtractSlice({
    required this.resolveType,
    required this.panelCategory,
    required this.ctx,
    this.tmdbId,
  });

  final String resolveType;
  final String panelCategory;
  final Map<String, dynamic> ctx;

  /// Numeric TMDB id string for `runPlugin` — null when bag has no tmdb.
  final String? tmdbId;
}

/// Torrent indexer search projection.
class TorrentSearchSlice {
  const TorrentSearchSlice({
    required this.query,
    this.imdbId,
    this.season,
    this.episode,
    this.ids = const {},
  });

  final String query;
  final String? imdbId;
  final int? season;
  final int? episode;
  final Map<String, String> ids;
}

/// Nuvio scraper projection — host-fixed TMDB contract.
class NuvioRequestSlice {
  const NuvioRequestSlice({
    required this.tmdbId,
    required this.type,
    this.season,
    this.episode,
  });

  final String tmdbId;
  final String type; // movie | tv
  final int? season;
  final int? episode;
}

/// Stremio bag view + optional custom open extras (not per-addon id pick).
class StremioBagSlice {
  const StremioBagSlice({
    required this.ids,
    this.customAddonBaseUrl,
    this.customStremioId,
    this.mediaType = 'movie',
    this.season,
    this.episode,
  });

  final Map<String, String> ids;
  final String? customAddonBaseUrl;
  final String? customStremioId;
  final String mediaType;
  final int? season;
  final int? episode;

  bool get hasCustomAddon {
    final base = (customAddonBaseUrl ?? '').trim();
    final id = (customStremioId ?? '').trim();
    return base.isNotEmpty && id.isNotEmpty;
  }
}

/// Merged catalog → Sources kind projections (no pack/hub switches).
class SourcesRequestContext {
  const SourcesRequestContext({
    required this.ids,
    required this.title,
    this.year,
    this.season,
    this.episode,
    this.episodeVideoId,
    this.engine,
    this.torrent,
    this.nuvio,
    this.stremioBag,
  });

  final Map<String, String> ids;
  final String title;
  final String? year;
  final int? season;
  final int? episode;
  final String? episodeVideoId;

  final EngineExtractSlice? engine;
  final TorrentSearchSlice? torrent;
  final NuvioRequestSlice? nuvio;
  final StremioBagSlice? stremioBag;

  bool get hasTmdb {
    final n = int.tryParse(ids['tmdb'] ?? '');
    return n != null && n > 0;
  }

  bool get hasImdb {
    final imdb = normalizeTorrentImdbId(ids['imdb']);
    return imdb != null && imdb.isNotEmpty;
  }

  bool get hasTitle => title.trim().isNotEmpty;
}

/// Known extract/ctx key → bag scheme.
const _ctxKeyToScheme = <String, String>{
  'tmdbId': 'tmdb',
  'tmdb': 'tmdb',
  'imdbId': 'imdb',
  'imdb': 'imdb',
  'anilistId': 'anilist',
  'anilist': 'anilist',
  'malId': 'mal',
  'mal': 'mal',
  'kisskhId': 'kisskh',
  'kisskh': 'kisskh',
};

/// Bag scheme → engine first-class ctx key.
const _schemeToEngineKey = <String, String>{
  'tmdb': 'tmdbId',
  'imdb': 'imdbId',
  'anilist': 'anilistId',
  'mal': 'malId',
};

String? _stringifyId(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  return s.isEmpty ? null : s;
}

void _putId(Map<String, String> bag, String scheme, dynamic raw) {
  final key = scheme.trim().toLowerCase();
  if (key.isEmpty) return;
  final v = _stringifyId(raw);
  if (v == null) return;
  bag.putIfAbsent(key, () => v);
}

/// Overlay extract ctx id-like keys into [bag] without deleting pack ctx keys.
void _overlayExtractIds(Map<String, String> bag, Map<String, dynamic> ctx) {
  for (final e in ctx.entries) {
    final mapped = _ctxKeyToScheme[e.key];
    if (mapped != null) {
      _putId(bag, mapped, e.value);
      continue;
    }
    final k = e.key;
    if (k.endsWith('Id') && k.length > 2) {
      final scheme = k.substring(0, k.length - 2);
      if (scheme.isNotEmpty) _putId(bag, scheme, e.value);
    }
  }
}

String? _yearFromMovie(Movie movie) {
  final d = movie.releaseDate.trim();
  return d.length >= 4 ? d.substring(0, 4) : null;
}

String? _yearFromMeta(CatalogMetaItem? meta) {
  if (meta == null) return null;
  final release = meta.releaseInfo.trim();
  if (release.isEmpty) return null;
  final head = release.contains(' • ')
      ? release.split(' • ').first.trim()
      : release;
  if (head.length >= 4 && RegExp(r'^\d{4}').hasMatch(head)) {
    return head.substring(0, 4);
  }
  return null;
}

String _nuvioMediaType({
  required Movie movie,
  CatalogOpen? open,
  CatalogMetaItem? meta,
}) {
  final extract = open?.effectiveExtract;
  final rt = (extract?.resolveType ?? '').toLowerCase();
  if (rt == 'movie') return 'movie';
  if (rt == 'tv' || rt == 'series') return 'tv';
  final hint = (meta?.tmdbMediaType ?? '').toLowerCase();
  if (hint == 'movie') return 'movie';
  if (hint == 'tv') return 'tv';
  final mt = movie.mediaType.toLowerCase();
  if (mt == 'tv' || mt == 'series' || mt == 'show') return 'tv';
  return 'movie';
}

/// Build Sources request context from catalog meta / open / movie.
SourcesRequestContext buildSourcesRequestContext({
  required Movie movie,
  CatalogMetaItem? catalogMeta,
  CatalogOpen? catalogOpen,
  int? season,
  int? episode,
  String? episodeVideoId,
  String? panelCategoryHint,
  String? queryOverride,
}) {
  final open = catalogOpen ?? catalogMeta?.open;
  final bag = <String, String>{};

  final metaIds = catalogMeta?.ids;
  if (metaIds != null) {
    for (final e in metaIds.entries) {
      _putId(bag, e.key.toString(), e.value);
    }
  }

  final extract = engineExtractContext(
    catalogOpen: open,
    movie: movie,
    episode: episode,
    episodeVideoId: episodeVideoId,
    panelCategoryHint: panelCategoryHint,
  );
  _overlayExtractIds(bag, extract.ctx);

  final movieImdb = normalizeTorrentImdbId(movie.imdbId);
  if (movieImdb != null) _putId(bag, 'imdb', movieImdb);

  // Legacy TMDB details: no catalog meta/open → movie.id is TMDB.
  // When catalog is present, never invent tmdb from movie.id (hub open id collision).
  final hasCatalog = catalogMeta != null || open != null;
  if (!hasCatalog && movie.id > 0 && !bag.containsKey('tmdb')) {
    _putId(bag, 'tmdb', movie.id.toString());
  }

  final imdb = normalizeTorrentImdbId(bag['imdb']);
  if (imdb != null) bag['imdb'] = imdb;

  final title = movie.title.trim().isNotEmpty
      ? movie.title.trim()
      : (catalogMeta?.name.trim() ?? '');
  final year = _yearFromMovie(movie) ?? _yearFromMeta(catalogMeta);

  final tmdbRaw = bag['tmdb'];
  final tmdbN = int.tryParse(tmdbRaw ?? '');
  final tmdbOk = tmdbN != null && tmdbN > 0;
  final tmdbIdStr = tmdbOk ? tmdbN.toString() : null;

  final engineCtx = Map<String, dynamic>.from(extract.ctx);
  for (final e in _schemeToEngineKey.entries) {
    final v = bag[e.key];
    if (v == null || v.isEmpty) continue;
    engineCtx.putIfAbsent(e.value, () => v);
  }
  if (tmdbIdStr != null) {
    engineCtx.putIfAbsent('tmdbId', () => tmdbIdStr);
  }

  final engine = EngineExtractSlice(
    resolveType: extract.resolveType,
    panelCategory: extract.panelCategory,
    ctx: engineCtx,
    tmdbId: tmdbIdStr,
  );

  final queryBase = (queryOverride ?? title).trim();
  final torrentQuery = queryBase.isEmpty
      ? ''
      : (year != null &&
              year.isNotEmpty &&
              !queryBase.contains(year) &&
              season == null
          ? '$queryBase $year'
          : queryBase);

  final torrent = torrentQuery.isEmpty
      ? null
      : TorrentSearchSlice(
          query: torrentQuery,
          imdbId: imdb,
          season: season,
          episode: episode,
          ids: Map<String, String>.from(bag),
        );

  final nuvioType = _nuvioMediaType(movie: movie, open: open, meta: catalogMeta);
  final nuvio = tmdbIdStr == null
      ? null
      : NuvioRequestSlice(
          tmdbId: tmdbIdStr,
          type: nuvioType,
          season: nuvioType == 'tv' ? season : null,
          episode: nuvioType == 'tv' ? episode : null,
        );

  final customBase = open?.extraString('stremioAddonBaseUrl');
  final customId =
      open?.extraString('stremioId') ?? (open?.surface == 'stremio' ? open?.id : null);
  final stremioBag = StremioBagSlice(
    ids: Map<String, String>.from(bag),
    customAddonBaseUrl: customBase,
    customStremioId: customId,
    mediaType: nuvioType == 'tv' ? 'tv' : 'movie',
    season: season,
    episode: episode,
  );

  return SourcesRequestContext(
    ids: Map<String, String>.unmodifiable(bag),
    title: title,
    year: year,
    season: season,
    episode: episode,
    episodeVideoId: episodeVideoId,
    engine: engine,
    torrent: torrent,
    nuvio: nuvio,
    stremioBag: stremioBag,
  );
}
