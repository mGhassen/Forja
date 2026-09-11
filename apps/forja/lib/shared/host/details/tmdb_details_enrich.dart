import 'package:forja/shared/foundation/blocks/details/kit_details_meta.dart';
import 'package:forja/shared/foundation/protocol/protocol.dart';
import 'package:forja/shared/foundation/services/registry/kit_details_host_hooks.dart';
import 'package:rust/rust.dart';

/// TMDB enrich for kit details — host-owned (RFC-106 G11).
///
/// Do not add more TmdbApi calls into foundation UI; extend this registrar.
abstract final class TmdbDetailsEnrich {
  TmdbDetailsEnrich._();

  static final _backdropCache = <String, List<String>>{};
  static final _richCache = <String, RichMediaDetails>{};

  static bool _registered = false;

  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;
    KitDetailsHostHooks.loadTmdbBackdropUrls = _loadBackdrops;
    KitDetailsHostHooks.loadTmdbRich = _loadRich;
    KitDetailsHostHooks.tmdbLogoUrl = _logoUrl;
  }

  static String _cacheKey(MetaItem meta) {
    final tmdbId = meta.numericId('tmdb');
    if (tmdbId == null) return meta.id;
    return '$tmdbId|${hubMetaTmdbMediaType(meta)}';
  }

  static Future<List<String>> _loadBackdrops(
    MetaItem meta, {
    required List<String> packUrls,
  }) async {
    final tmdbId = meta.numericId('tmdb');
    if (tmdbId == null) return packUrls;

    final cacheKey = _cacheKey(meta);
    final cached = _backdropCache[cacheKey];
    if (cached != null) return cached;

    final mediaType = hubMetaTmdbMediaType(meta);
    final api = TmdbApi();
    final urls = <String>[];

    void addUrl(String path) {
      if (path.isEmpty) return;
      final u = path.startsWith('http') ? path : TmdbApi.getBackdropUrl(path);
      if (u.isNotEmpty && !urls.contains(u)) urls.add(u);
    }

    for (final raw in packUrls) {
      addUrl(raw);
    }

    try {
      final paths = await api.getBackdrops(tmdbId, mediaType: mediaType);
      for (final p in paths) {
        addUrl(p);
      }
    } catch (_) {}

    final out = urls.take(12).toList();
    _backdropCache[cacheKey] = out;
    return out;
  }

  static Future<RichMediaDetails?> _loadRich(MetaItem meta) async {
    final tmdbId = meta.numericId('tmdb');
    if (tmdbId == null) return null;

    final cacheKey = _cacheKey(meta);
    final cached = _richCache[cacheKey];
    if (cached != null) return cached;

    try {
      final rich = await TmdbApi().getRichDetails(
        tmdbId,
        hubMetaTmdbMediaType(meta),
      );
      _richCache[cacheKey] = rich;
      return rich;
    } catch (_) {
      return null;
    }
  }

  static String? _logoUrl(RichMediaDetails? rich) {
    if (rich == null) return null;
    final path = rich.movie.logoPath.trim();
    if (path.isEmpty) return null;
    return path.startsWith('http') ? path : TmdbApi.getImageUrl(path);
  }
}
