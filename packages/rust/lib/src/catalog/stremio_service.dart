import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';

class _StremioHttpResponse {
  const _StremioHttpResponse(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

bool stremioErrorIsTimeout(Object error) {
  final m = error.toString().toLowerCase();
  return m.contains('timeout') ||
      m.contains('timed out') ||
      m.contains('deadline');
}

bool stremioStatusIsNoRetry(int statusCode) {
  if (statusCode == 404 ||
      statusCode == 401 ||
      statusCode == 403 ||
      statusCode == 429) {
    return true;
  }
  return statusCode >= 400 && statusCode < 500;
}

bool stremioStatusShouldCooldown(int statusCode) {
  return statusCode == 403 || statusCode == 429 || statusCode >= 500;
}

({String baseUrl, String? queryParams}) _splitStremioAddonUrl(String url) {
  final m = jsonDecode(RustLib.instance.splitStremioAddonUrlJson(url))
      as Map<String, dynamic>;
  return (
    baseUrl: m['base_url'] as String,
    queryParams: m['query_params'] as String?,
  );
}

String _buildStremioResourceUrl(String addonUrl, String resourcePath) =>
    RustLib.instance.buildStremioResourceUrl(addonUrl, resourcePath);

String _normalizeStremioManifestUrl(String url) =>
    RustLib.instance.normalizeStremioManifestUrl(url);

Map<String, dynamic> _parseStremioManifest(String body) =>
    jsonDecode(RustLib.instance.parseStremioManifestJson(body))
        as Map<String, dynamic>;

List<dynamic> _parseStremioStreams(String body) {
  final parsed =
      jsonDecode(RustLib.instance.parseStremioStreamsJson(body))
          as Map<String, dynamic>;
  if (parsed.containsKey('error')) return const [];
  final streams = parsed['streams'];
  return streams is List ? streams : const [];
}

List<Map<String, dynamic>> _parseStremioSubtitles(String body) {
  final parsed =
      jsonDecode(RustLib.instance.parseStremioSubtitlesJson(body))
          as Map<String, dynamic>;
  if (parsed.containsKey('error')) return const [];
  final subs = parsed['subtitles'];
  if (subs is! List) return const [];
  return subs
      .whereType<Map>()
      .map((s) => Map<String, dynamic>.from(s))
      .toList();
}

List<Map<String, dynamic>> _parseStremioCatalog(String body) {
  final parsed =
      jsonDecode(RustLib.instance.parseStremioCatalogJson(body))
          as Map<String, dynamic>;
  if (parsed.containsKey('error')) return const [];
  final metas = parsed['metas'];
  if (metas is! List) return const [];
  return metas
      .whereType<Map>()
      .map((m) => Map<String, dynamic>.from(m))
      .toList();
}

Map<String, dynamic>? _parseStremioMeta(String body) {
  final parsed = jsonDecode(RustLib.instance.parseStremioMetaJson(body))
      as Map<String, dynamic>;
  if (parsed.containsKey('error')) return null;
  final meta = parsed['meta'];
  if (meta is! Map) return null;
  return Map<String, dynamic>.from(meta);
}

class StremioService {
  static final StremioService _instance = StremioService._internal();
  factory StremioService() => _instance;
  StremioService._internal();

  final SettingsService _settings = SettingsService();

  /// Retry a GET via Rust engine with exponential backoff.
  /// Does NOT retry on 404/401/403/429, other 4xx, or timeouts.
  Future<_StremioHttpResponse> _retryGet(
    Uri uri, {
    int retries = 1,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    _StremioHttpResponse? lastResponse;
    Object? lastError;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final response = await _rustGet(uri, timeout: timeout);
        if (response.statusCode == 200) return response;
        lastResponse = response;
        if (stremioStatusIsNoRetry(response.statusCode)) {
          break;
        }
      } catch (e) {
        lastError = e;
        if (stremioErrorIsTimeout(e)) break;
      }
      if (attempt < retries) {
        await Future.delayed(Duration(milliseconds: 500 * (1 << attempt)));
      }
    }
    if (lastResponse != null) return lastResponse;
    throw lastError ?? Exception('Request failed after $retries retries');
  }

  Future<_StremioHttpResponse> _rustGet(
    Uri uri, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final raw = await runStremioHttpGet(
      uri.toString(),
      timeoutSecs: timeout.inSeconds.clamp(1, 120),
    );
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    if (parsed.containsKey('error')) {
      throw Exception(parsed['error']);
    }
    return _StremioHttpResponse(
      parsed['status'] as int,
      parsed['body'] as String,
    );
  }

  /// Extracts a clean base URL and optional query parameters from an addon URL.
  /// Handles addons that embed config as query params (e.g. ?apikey=...).
  static ({String baseUrl, String? queryParams}) _splitAddonUrl(String url) {
    return _splitStremioAddonUrl(url);
  }

  @visibleForTesting
  static ({String baseUrl, String? queryParams}) debugSplitAddonUrl(String url) =>
      _splitAddonUrl(url);

  /// Builds a full resource URL, correctly re-appending any addon query params.
  String _buildResourceUrl(String addonBaseUrl, String resourcePath) {
    return _buildStremioResourceUrl(addonBaseUrl, resourcePath);
  }

  /// Fetches and validates an addon manifest from a URL
  Future<Map<String, dynamic>?> fetchManifest(String url) async {
    String manifestUrl = url.trim();
    if (manifestUrl.isEmpty) return null;

    manifestUrl = _normalizeStremioManifestUrl(manifestUrl);

    try {
      final response =
          await _rustGet(Uri.parse(manifestUrl), timeout: const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = response.body;
        final parsed = _parseStremioManifest(body);
        if (parsed.containsKey('error')) return null;
        final manifest = parsed;
        final parts = _splitAddonUrl(manifestUrl);
        final baseUrl = parts.queryParams != null
            ? '${parts.baseUrl}?${parts.queryParams}'
            : parts.baseUrl;

        return {
          'baseUrl': baseUrl,
          'manifest': manifest,
          'name': manifest['name'] ?? 'Unknown Addon',
          'icon': manifest['logo'] ?? '',
          'features': StremioAddonFeatures.inferFromManifest(manifest),
        };
      }
    } catch (e) {
      debugPrint('[StremioService] Manifest fetch error: $e');
    }
    return null;
  }

  /// Fetches streams from a specific addon (with retry)
  Future<List<dynamic>> getStreams({
    required String baseUrl,
    required String type, // 'movie' or 'series'
    required String id,   // tt... or tt...:s:e
  }) async {
    final encodedId = id.contains('/') ? Uri.encodeComponent(id) : id;
    final resourcePath = '/stream/$type/$encodedId.json';
    final url = _buildResourceUrl(baseUrl, resourcePath);
    final now = DateTime.now();
    _streamFailedUntil.removeWhere((_, until) => until.isBefore(now));
    final failedUntil = _streamFailedUntil[url];
    if (failedUntil != null && failedUntil.isAfter(now)) {
      return [];
    }
    debugPrint('[StremioService.getStreams] URL: $url');
    try {
      final response = await _retryGet(Uri.parse(url));
      if (response.statusCode == 200) {
        _streamFailedUntil.remove(url);
        return _parseStremioStreams(response.body);
      }
      if (stremioStatusShouldCooldown(response.statusCode)) {
        _streamFailedUntil[url] = now.add(_failTtl);
      }
      debugPrint('[StremioService] Stream fetch HTTP ${response.statusCode} ($url)');
    } catch (e) {
      _streamFailedUntil[url] = now.add(_failTtl);
      debugPrint('[StremioService] Stream fetch error ($url): $e');
    }
    return [];
  }

  /// Fetches subtitles from a specific addon (with retry)
  Future<List<Map<String, dynamic>>> getSubtitles({
    required String baseUrl,
    required String type,
    required String id,
    String? addonName,
  }) async {
    final List<Map<String, dynamic>> results = [];
    final encodedId = id.contains('/') ? Uri.encodeComponent(id) : id;
    final resourcePath = '/subtitles/$type/$encodedId.json';
    final url = _buildResourceUrl(baseUrl, resourcePath);
    try {
      final response = await _retryGet(Uri.parse(url));
      if (response.statusCode == 200) {
        for (final s in _parseStremioSubtitles(response.body)) {
          results.add({
            'id': s['id'] ?? s['url'],
            'url': s['url'],
            'language': s['lang'] ?? 'Unknown',
            'display':
                '${(s['lang'] as String?)?.toUpperCase() ?? '??'} - ${addonName ?? 'Addon'}',
            'sourceName': addonName ?? 'Stremio Addon',
          });
        }
        return results;
      }
    } catch (e) {
      debugPrint('[StremioService] Subtitle fetch error ($url): $e');
    }
    return results;
  }

  /// Avoid hammering dead lean rows; TTL so a transient fail can recover.
  final Map<String, DateTime> _hydrateFailedUntil = {};
  final Map<String, DateTime> _streamFailedUntil = {};
  /// Host-level catalog cooldown (429 / 5xx) so Search does not stampede.
  final Map<String, DateTime> _catalogFailedUntil = {};
  static const _failTtl = Duration(seconds: 45);
  static const _hydrateConcurrency = 4;
  Future<List<Map<String, dynamic>>>? _hydrateInFlight;
  Future<void> _hydratePersistChain = Future.value();

  static bool _hasManifestResources(Map<String, dynamic> addon) {
    final manifest = addon['manifest'];
    if (manifest is! Map) return false;
    final resources = manifest['resources'];
    return resources is List && resources.isNotEmpty;
  }

  static bool _hasCatalogs(Map<String, dynamic> addon) {
    final manifest = addon['manifest'];
    if (manifest is! Map) return false;
    final cats = manifest['catalogs'];
    return cats is List && cats.isNotEmpty;
  }

  /// Lean sync rows need a full manifest. Also re-fetch when `resources` exist
  /// but `catalogs` is missing (Home/Search browse broken for Cinemeta).
  static bool _needsManifestHydrate(Map<String, dynamic> addon) {
    if (!_hasManifestResources(addon)) return true;
    // Catalog/meta addons are useless for Home without a catalogs list.
    final manifest = addon['manifest'];
    if (manifest is! Map) return true;
    final resources = manifest['resources'];
    if (resources is! List) return true;
    final claimsCatalog = resources.any((r) {
      if (r is String) return r == 'catalog';
      if (r is Map) return r['name'] == 'catalog';
      return false;
    });
    if (claimsCatalog && !_hasCatalogs(addon)) return true;
    return false;
  }

  /// Cloud sync stores lean rows (`baseUrl` + name). Re-fetch manifests so
  /// Sources can filter by `resources` and Home can read `catalogs`.
  ///
  /// Persists without per-row [SettingsService.addonChangeNotifier] bumps —
  /// Home listens to that and would otherwise reload catalogs forever.
  Future<List<Map<String, dynamic>>> hydrateInstalledAddons() {
    return _hydrateInFlight ??= _hydrateInstalledAddonsImpl().whenComplete(() {
      _hydrateInFlight = null;
    });
  }

  Future<List<Map<String, dynamic>>> _hydrateInstalledAddonsImpl() async {
    final all = await _settings.getStremioAddons();
    if (all.isEmpty) return const [];
    final now = DateTime.now();
    _hydrateFailedUntil.removeWhere((_, until) => until.isBefore(now));
    final out = List<Map<String, dynamic>?>.filled(all.length, null);
    var next = 0;
    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= all.length) return;
        out[i] = await _hydrateOneAddon(all[i], now);
      }
    }
    final n = all.length < _hydrateConcurrency
        ? all.length
        : _hydrateConcurrency;
    await Future.wait([for (var w = 0; w < n; w++) worker()]);
    return out.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>?> _hydrateOneAddon(
    Map<String, dynamic> addon,
    DateTime now,
  ) async {
    if (!_needsManifestHydrate(addon)) return addon;
    final baseUrl = SettingsService.normalizeStremioAddonBaseUrl(
      addon['baseUrl']?.toString() ?? '',
    );
    if (baseUrl.isEmpty) return null;
    final failedUntil = _hydrateFailedUntil[baseUrl];
    if (failedUntil != null && failedUntil.isAfter(now)) return addon;
    try {
      final fresh = await fetchManifest(baseUrl);
      if (fresh != null && _hasManifestResources(fresh)) {
        final kept = StremioAddonFeatures.normalize(
          addon['features'],
          manifest: fresh['manifest'] is Map
              ? Map<String, dynamic>.from(fresh['manifest'] as Map)
              : null,
        );
        fresh['features'] = kept;
        final prev = _hydratePersistChain;
        final persist = prev.then(
          (_) => _settings.saveStremioAddon(fresh, notify: false),
        );
        _hydratePersistChain = persist.catchError((_) {});
        await persist;
        _hydrateFailedUntil.remove(baseUrl);
        return fresh;
      }
      _hydrateFailedUntil[baseUrl] = now.add(_failTtl);
    } catch (e) {
      _hydrateFailedUntil[baseUrl] = now.add(_failTtl);
      debugPrint('[StremioService] hydrate failed ($baseUrl): $e');
    }
    return addon;
  }

  /// Helper to get all installed addons that support a specific resource.
  /// Optionally filters by content [type] (e.g. 'movie', 'series').
  ///
  /// [feature] defaults to [StremioAddonFeatures.vod] so Live-only sports
  /// addons never leak into Details / Home stream chips.
  Future<List<Map<String, dynamic>>> getAddonsForResource(
    String resourceName, {
    String? type,
    String feature = StremioAddonFeatures.vod,
  }) async {
    final allAddons = await hydrateInstalledAddons();
    return allAddons.where((addon) {
      if (!StremioAddonFeatures.read(addon).contains(feature)) return false;
      final manifest = addon['manifest'];
      if (manifest is! Map) return false;
      final resources = manifest['resources'] as List?;
      if (resources == null) return false;
      return resources.any((r) {
        if (r is String) {
          if (r != resourceName) return false;
          // Simple string resource — check manifest-level types if filtering
          if (type != null) {
            final types = manifest['types'] as List?;
            return types != null && types.contains(type);
          }
          return true;
        }
        if (r is Map && r['name'] == resourceName) {
          if (type != null) {
            final types = r['types'] as List?;
            if (types != null && types.isNotEmpty) return types.contains(type);
            // No types on resource → fall back to manifest-level
            final mTypes = manifest['types'] as List?;
            return mTypes == null || mTypes.contains(type);
          }
          return true;
        }
        return false;
      });
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CATALOG
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns all catalogs from installed addons, each annotated with the
  /// parent addon's baseUrl and name.
  /// Handles both the detailed `extra` format (objects) and the legacy
  /// `extraSupported` / `extraRequired` flat string arrays.
  /// Catalogs for Home / Search. Defaults to [StremioAddonFeatures.vod].
  Future<List<Map<String, dynamic>>> getAllCatalogs({
    String feature = StremioAddonFeatures.vod,
  }) async {
    // Use all installed addons that declare at least one catalog.
    // We intentionally do NOT filter by getAddonsForResource('catalog')
    // because many addons omit 'catalog' from their resources array even
    // when they provide catalogs.  The presence of a non-empty 'catalogs'
    // list in the manifest is the authoritative signal.
    final allAddons = await hydrateInstalledAddons();
    final catalogAddons = allAddons.where((addon) {
      if (!StremioAddonFeatures.read(addon).contains(feature)) return false;
      final manifest = addon['manifest'];
      if (manifest is! Map) return false;
      final cats = manifest['catalogs'];
      return cats is List && cats.isNotEmpty;
    }).toList();
    final List<Map<String, dynamic>> result = [];
    for (final addon in catalogAddons) {
      final manifest = addon['manifest'] as Map<String, dynamic>;
      final catalogs = manifest['catalogs'] as List? ?? [];
      for (final cat in catalogs) {
        if (cat is! Map) continue;

        // ── Determine supported / required extras from both formats ──────
        final extra = cat['extra'] as List? ?? [];
        final extraSupportedRaw = cat['extraSupported'] as List?;
        final extraRequiredRaw = cat['extraRequired'] as List?;

        // Build canonical sets using detailed `extra` objects first,
        // then falling back to `extraSupported` / `extraRequired`.
        final Set<String> supported = {};
        final Set<String> required = {};

        for (final e in extra) {
          if (e is Map) {
            final name = e['name']?.toString() ?? '';
            if (name.isNotEmpty) supported.add(name);
            if (e['isRequired'] == true) required.add(name);
          } else if (e is String) {
            supported.add(e);
          }
        }

        // Merge legacy flat arrays if they provide additional info
        if (extraSupportedRaw != null) {
          for (final s in extraSupportedRaw) {
            if (s is String) supported.add(s);
          }
        }
        if (extraRequiredRaw != null) {
          for (final r in extraRequiredRaw) {
            if (r is String) required.add(r);
          }
        }

        // Skip catalogs that REQUIRE special extras we can't provide
        // (e.g. Cinemeta's lastVideosIds / calendarVideosIds)
        final unfulfillable = required.where((n) => n != 'genre' && n != 'search');
        if (unfulfillable.isNotEmpty) continue;

        // ── Genres: prefer top-level, fall back to extra[genre].options ──
        List<String> genres = (cat['genres'] as List?)?.cast<String>() ?? <String>[];
        if (genres.isEmpty) {
          for (final e in extra) {
            if (e is Map && e['name'] == 'genre' && e['options'] is List) {
              genres = (e['options'] as List).cast<String>();
              break;
            }
          }
        }

        result.add({
          'addonBaseUrl': addon['baseUrl'],
          'addonName': addon['name'] ?? manifest['name'] ?? 'Unknown',
          'addonIcon': addon['icon'] ?? manifest['logo'] ?? '',
          'catalogId': cat['id'],
          'catalogName': cat['name'] ?? cat['id'],
          'catalogType': cat['type'],
          'genres': genres,
          'extra': extra,
          'supportsSearch': supported.contains('search'),
          'searchRequired': required.contains('search'),
          'genreRequired': required.contains('genre'),
          'supportsGenre': supported.contains('genre'),
          'supportsSkip': supported.contains('skip'),
        });
      }
    }
    return result;
  }

  /// Fetches a catalog feed.
  /// [genre] and [skip] are optional extra params.
  /// Extra args are placed in the URL path per the Stremio protocol:
  ///   /{resource}/{type}/{id}/{extraArgs}.json
  Future<List<Map<String, dynamic>>> getCatalog({
    required String baseUrl,
    required String type,
    required String id,
    String? genre,
    int? skip,
    String? search,
  }) async {
    final parts = <String>[];
    if (search != null && search.isNotEmpty) {
      parts.add('search=${Uri.encodeComponent(search)}');
    }
    if (genre != null && genre.isNotEmpty) {
      parts.add('genre=${Uri.encodeComponent(genre)}');
    }
    if (skip != null && skip > 0) {
      parts.add('skip=$skip');
    }
    final extra = parts.isNotEmpty ? '/${parts.join('&')}' : '';
    final resourcePath = '/catalog/$type/$id$extra.json';
    final url = _buildResourceUrl(baseUrl, resourcePath);
    final host = Uri.tryParse(url)?.host ?? '';
    final now = DateTime.now();
    _catalogFailedUntil.removeWhere((_, until) => until.isBefore(now));
    if (host.isNotEmpty) {
      final failedUntil = _catalogFailedUntil[host];
      if (failedUntil != null && failedUntil.isAfter(now)) {
        debugPrint(
          '[StremioService.getCatalog] cooldown ($host until $failedUntil)',
        );
        return [];
      }
    }
    debugPrint('[StremioService.getCatalog] URL: $url');

    try {
      final response = await _retryGet(Uri.parse(url));
      if (response.statusCode == 200) {
        if (host.isNotEmpty) _catalogFailedUntil.remove(host);
        final items = _parseStremioCatalog(response.body);
        debugPrint(
          '[StremioService.getCatalog] ${response.statusCode} → ${items.length} metas',
        );
        return items;
      }
      if (stremioStatusShouldCooldown(response.statusCode) && host.isNotEmpty) {
        _catalogFailedUntil[host] = now.add(_failTtl);
      }
      debugPrint(
        '[StremioService.getCatalog] HTTP ${response.statusCode} ($url)',
      );
    } catch (e) {
      if (host.isNotEmpty) {
        _catalogFailedUntil[host] = now.add(_failTtl);
      }
      debugPrint('[StremioService] Catalog fetch error ($url): $e');
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  METADATA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetches full meta for a specific item (with retry).
  /// GET {baseUrl}/meta/{type}/{id}.json
  /// Supports both regular content and collections (which have a 'videos' array).
  Future<Map<String, dynamic>?> getMeta({
    required String baseUrl,
    required String type,
    required String id,
  }) async {
    final encodedId = id.contains('/') ? Uri.encodeComponent(id) : id;
    final resourcePath = '/meta/$type/$encodedId.json';
    final url = _buildResourceUrl(baseUrl, resourcePath);
    try {
      final response = await _retryGet(Uri.parse(url));
      if (response.statusCode == 200) {
        return _parseStremioMeta(response.body);
      }
    } catch (e) {
      debugPrint('[StremioService] Meta fetch error ($url): $e');
    }
    return null;
  }

  /// Fetches meta from ALL installed addons that can handle this id and type.
  /// Returns the first successful non-null response.
  Future<Map<String, dynamic>?> getMetaFromAny({
    required String type,
    required String id,
  }) async {
    final addons = await getAddonsForResource('meta', type: type);
    for (final addon in addons) {
      final manifest = addon['manifest'] as Map<String, dynamic>;
      // Check idPrefixes filter
      final idPrefixes = _getIdPrefixes(manifest, 'meta');
      if (idPrefixes.isNotEmpty && !idPrefixes.any((p) => id.startsWith(p))) {
        continue;
      }
      final meta = await getMeta(baseUrl: addon['baseUrl'], type: type, id: id);
      if (meta != null && meta.isNotEmpty && meta['id'] != null) return meta;
    }
    return null;
  }

  /// Extracts idPrefixes for a specific resource from a manifest.
  List<String> _getIdPrefixes(Map<String, dynamic> manifest, String resourceName) {
    final resources = manifest['resources'] as List? ?? [];
    // Check resource-level idPrefixes first
    for (final r in resources) {
      if (r is Map && r['name'] == resourceName && r['idPrefixes'] != null) {
        return (r['idPrefixes'] as List).cast<String>();
      }
    }
    // Fallback to manifest-level
    final prefixes = manifest['idPrefixes'] as List?;
    return prefixes?.cast<String>() ?? [];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SEARCH (catalog-based)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Searches across ALL installed addons that have catalogs with search support.
  /// Returns a flat list of meta preview objects with addon info attached.
  Future<List<Map<String, dynamic>>> searchAllAddons(String query) async {
    if (query.trim().isEmpty) return [];
    final catalogs = await getAllCatalogs();
    final searchable = catalogs.where((c) => c['supportsSearch'] == true).toList();

    final List<Map<String, dynamic>> allResults = [];
    final futures = <Future>[];

    for (final cat in searchable) {
      futures.add(
        getCatalog(
          baseUrl: cat['addonBaseUrl'],
          type: cat['catalogType'],
          id: cat['catalogId'],
          search: query,
        ).then((metas) {
          for (final m in metas) {
            m['_addonName'] = cat['addonName'];
            m['_addonBaseUrl'] = cat['addonBaseUrl'];
            m['_catalogType'] = cat['catalogType'];
          }
          allResults.addAll(metas);
        }).catchError((_) {}),
      );
    }
    await Future.wait(futures);
    return allResults;
  }

  /// Searches a specific addon's catalog.
  Future<List<Map<String, dynamic>>> searchAddonCatalog({
    required String baseUrl,
    required String type,
    required String catalogId,
    required String query,
  }) async {
    return getCatalog(baseUrl: baseUrl, type: type, id: catalogId, search: query);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  META LINK PARSING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Parses a Stremio meta link URL and returns an action descriptor.
  /// Supported formats:
  ///   stremio:///detail/{type}/{id}
  ///   stremio:///detail/{type}/{id}/{videoId}
  ///   stremio:///search?search={query}
  ///   stremio:///discover/{transportUrl}/{type}/{catalogId}?{extra}
  static Map<String, dynamic>? parseMetaLink(String url) {
    // Normalize
    String u = url.trim();
    if (u.startsWith('stremio://')) {
      u = u.replaceFirst('stremio://', 'stremio:///');
      // Fix triple slashes if already had them
      u = u.replaceAll('stremio:////', 'stremio:///');
    }

    // detail link
    final detailMatch = RegExp(r'stremio:///detail/([^/]+)/([^/?]+)(?:/([^/?]+))?').firstMatch(u);
    if (detailMatch != null) {
      return {
        'action': 'detail',
        'type': detailMatch.group(1),
        'id': detailMatch.group(2),
        'videoId': detailMatch.group(3),
      };
    }

    // search link
    final searchMatch = RegExp(r'stremio:///search\?search=(.+)').firstMatch(u);
    if (searchMatch != null) {
      return {
        'action': 'search',
        'query': Uri.decodeComponent(searchMatch.group(1)!),
      };
    }

    // discover link
    final discoverMatch = RegExp(r'stremio:///discover/([^/]+)/([^/]+)/([^/?]+)(.*)').firstMatch(u);
    if (discoverMatch != null) {
      return {
        'action': 'discover',
        'transportUrl': Uri.decodeComponent(discoverMatch.group(1)!),
        'type': discoverMatch.group(2),
        'catalogId': discoverMatch.group(3),
        'extra': discoverMatch.group(4),
      };
    }

    return null;
  }

  /// Resolves a Stremio meta ID to a TMDB Movie object.
  /// Handles: tt1234567 (IMDB), tmdb:12345, kitsu:12345, and custom IDs.
  /// For IMDB IDs, uses TMDB find-by-external-id endpoint.
  /// For others, fetches meta from addons and maps to Movie.
  Future<Map<String, dynamic>?> resolveIdToMeta(String id, String type) async {
    // Already an IMDB ID → let TMDB handle it
    if (id.startsWith('tt')) {
      return {'action': 'tmdb_lookup', 'imdbId': id, 'type': type};
    }
    // Try to get full meta from addons
    final meta = await getMetaFromAny(type: type, id: id);
    if (meta != null) {
      return {'action': 'stremio_meta', 'meta': meta, 'type': type};
    }
    return null;
  }

  /// Installed addons targeting [feature] (after hydrate).
  Future<List<Map<String, dynamic>>> getAddonsForFeature(String feature) async {
    final all = await hydrateInstalledAddons();
    return all
        .where((a) => StremioAddonFeatures.read(a).contains(feature))
        .toList();
  }

  /// Prefer live/today sport catalogs; else every `type: sport` catalog.
  static List<Map<String, dynamic>> sportCatalogsForLive(
    Map<String, dynamic> addon,
  ) {
    final manifest = addon['manifest'];
    if (manifest is! Map) return const [];
    final catalogs = manifest['catalogs'];
    if (catalogs is! List) return const [];
    final sport = <Map<String, dynamic>>[];
    for (final c in catalogs) {
      if (c is! Map) continue;
      final type = c['type']?.toString() ?? '';
      if (type != 'sport') continue;
      sport.add(Map<String, dynamic>.from(c));
    }
    if (sport.isEmpty) return const [];
    final preferred = sport
        .where((c) {
          final id = c['id']?.toString() ?? '';
          return id == 'sports_live' || id == 'sports_today';
        })
        .toList();
    return preferred.isNotEmpty ? preferred : sport;
  }

  /// True when a stream URL looks playable in the native IPTV player.
  static bool isPlayableLiveUrl(String? url) {
    final u = url?.trim() ?? '';
    if (u.isEmpty) return false;
    final lower = u.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return false;
    }
    if (lower.contains('google.com')) return false;
    if (lower.contains('upgrade to watch')) return false;
    return true;
  }

  /// HTTP headers for native IPTV play of a Stremio live stream.
  ///
  /// Prefer addon `behaviorHints.proxyHeaders.request`. When missing, Highfly
  /// Streamed-backed leaf CDNs (`recaps.dev` / `strmd.st`) still need a
  /// browser UA + streamed.pk Referer on Exo (same as Live Matches Streamed).
  static Map<String, String> liveStreamRequestHeaders(Map stream) {
    final headers = <String, String>{};
    final hints = stream['behaviorHints'];
    final proxy = hints is Map ? hints['proxyHeaders'] : null;
    final request = proxy is Map ? proxy['request'] : null;
    if (request is Map) {
      request.forEach((key, value) {
        if (key == null || value == null) return;
        final k = key.toString().trim();
        final v = value.toString().trim();
        if (k.isEmpty || v.isEmpty) return;
        headers[k] = v;
      });
    }

    final url = (stream['url']?.toString() ?? '').toLowerCase();
    final needsStreamedCatalog = url.contains('recaps.dev') ||
        url.contains('strmd.st');
    if (!needsStreamedCatalog) return headers;

    final hasReferer = headers.keys.any((k) => k.toLowerCase() == 'referer');
    if (!hasReferer) {
      headers['Referer'] = 'https://streamed.pk/';
      headers.putIfAbsent('Origin', () => 'https://streamed.pk');
    }
    final hasUa = headers.keys.any((k) => k.toLowerCase() == 'user-agent');
    if (!hasUa) {
      headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    }
    return headers;
  }
}
