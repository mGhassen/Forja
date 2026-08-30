/// Catalog hub protocol v1 — envelope, errors, meta, filter AST, layout. RFC-070.
library;

const int hostKitVersion = 1;
const int hostProtocolVersion = 1;

enum CatalogErrorCode {
  invalidAction('INVALID_ACTION'),
  invalidParams('INVALID_PARAMS'),
  notFound('NOT_FOUND'),
  authRequired('AUTH_REQUIRED'),
  authExpired('AUTH_EXPIRED'),
  rateLimit('RATE_LIMIT'),
  upstream('UPSTREAM'),
  parse('PARSE'),
  unsupportedKit('UNSUPPORTED_KIT'),
  cancelled('CANCELLED');

  const CatalogErrorCode(this.wire);
  final String wire;

  static CatalogErrorCode? tryParse(String? raw) {
    if (raw == null) return null;
    final n = raw.trim().toUpperCase().replaceAll('-', '_');
    for (final c in CatalogErrorCode.values) {
      if (c.wire == n || c.name.toUpperCase() == n) return c;
    }
    // snake aliases
    final snake = n;
    for (final c in CatalogErrorCode.values) {
      if (_camelToSnake(c.name).toUpperCase() == snake) return c;
    }
    return null;
  }

  static String _camelToSnake(String s) {
    return s.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (m) => '_${m[0]!.toLowerCase()}',
    ).replaceFirst(RegExp(r'^_'), '');
  }

  bool get isAuth =>
      this == authRequired || this == authExpired;

  bool get retryableByDefault =>
      this == rateLimit || this == upstream || this == cancelled;
}

class CatalogError {
  const CatalogError({
    required this.code,
    this.message = '',
    this.retryable,
  });

  final CatalogErrorCode code;
  final String message;
  final bool? retryable;

  bool get isRetryable => retryable ?? code.retryableByDefault;

  factory CatalogError.fromJson(Map<String, dynamic> j) {
    final code = CatalogErrorCode.tryParse(j['code']?.toString()) ??
        CatalogErrorCode.upstream;
    return CatalogError(
      code: code,
      message: (j['message'] ?? '').toString(),
      retryable: j['retryable'] is bool
          ? j['retryable'] as bool
          : (j['retriable'] is bool ? j['retriable'] as bool : null),
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code.wire,
        'message': message,
        if (retryable != null) 'retryable': retryable,
      };
}

class CatalogCacheHints {
  const CatalogCacheHints({
    this.etag,
    this.maxAge,
    this.swr,
  });

  final String? etag;
  final Duration? maxAge;
  final Duration? swr;

  static const empty = CatalogCacheHints();

  bool get isEmpty => etag == null && maxAge == null && swr == null;

  factory CatalogCacheHints.fromJson(Map<String, dynamic>? j) {
    if (j == null) return empty;
    Duration? secs(String a, String b) {
      final v = j[a] ?? j[b];
      if (v is num) {
        final n = v.toInt();
        return n > 0 ? Duration(seconds: n) : null;
      }
      return null;
    }

    final etag = (j['etag'] ?? '').toString().trim();
    return CatalogCacheHints(
      etag: etag.isEmpty ? null : etag,
      maxAge: secs('maxAge', 'maxAgeSec'),
      swr: secs('swr', 'staleWhileRevalidateSec') ??
          secs('staleWhileRevalidate', 'swr'),
    );
  }

  Map<String, dynamic> toJson() => {
        if (etag != null) 'etag': etag,
        if (maxAge != null) 'maxAge': maxAge!.inSeconds,
        if (swr != null) 'swr': swr!.inSeconds,
      };
}

class CatalogEnvelope {
  const CatalogEnvelope({
    required this.ok,
    this.kit = hostKitVersion,
    this.protocol = hostProtocolVersion,
    this.action = '',
    this.data,
    this.error,
    this.cache = CatalogCacheHints.empty,
    this.notModified = false,
  });

  final bool ok;
  final int kit;
  final int protocol;
  final String action;
  final Map<String, dynamic>? data;
  final CatalogError? error;
  final CatalogCacheHints cache;
  final bool notModified;

  bool get isUnsupportedKit => kit > hostKitVersion;

  List<CatalogMetaItem> get items {
    final raw = data?['items'];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map) CatalogMetaItem.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  CatalogMetaItem? get meta {
    final raw = data?['meta'];
    if (raw is! Map) return null;
    return CatalogMetaItem.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Pack `stream` action rows: `{ name, url, type: direct|embed }`.
  List<CatalogStream> get streams {
    final raw = data?['streams'];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map) CatalogStream.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  factory CatalogEnvelope.failure(
    CatalogErrorCode code, {
    String message = '',
    String action = '',
  }) {
    return CatalogEnvelope(
      ok: false,
      action: action,
      error: CatalogError(code: code, message: message),
    );
  }

  factory CatalogEnvelope.fromJson(Map<String, dynamic> j) {
    final err = j['error'];
    final cacheRaw = j['cache'];
    return CatalogEnvelope(
      ok: j['ok'] == true,
      kit: (j['kit'] as num?)?.toInt() ?? hostKitVersion,
      protocol: (j['protocol'] as num?)?.toInt() ?? hostProtocolVersion,
      action: (j['action'] ?? '').toString(),
      data: j['data'] is Map
          ? Map<String, dynamic>.from(j['data'] as Map)
          : null,
      error: err is Map
          ? CatalogError.fromJson(Map<String, dynamic>.from(err))
          : null,
      cache: CatalogCacheHints.fromJson(
        cacheRaw is Map ? Map<String, dynamic>.from(cacheRaw) : null,
      ),
      notModified: j['notModified'] == true,
    );
  }
}

/// Plugin returns `[envelope]` (engine list coerce) or a bare envelope map.
CatalogEnvelope? parseEnvelope(dynamic raw) {
  if (raw is Map) {
    final m = Map<String, dynamic>.from(raw);
    if (!m.containsKey('ok')) return null;
    return CatalogEnvelope.fromJson(m);
  }
  if (raw is List && raw.isNotEmpty && raw.first is Map) {
    final m = Map<String, dynamic>.from(raw.first as Map);
    if (!m.containsKey('ok')) return null;
    return CatalogEnvelope.fromJson(m);
  }
  return null;
}

/// Host detail route declared by a hub pack on each openable meta.
///
/// Host switches only on [surface] — never on pack/scraper id keys.
class CatalogOpen {
  const CatalogOpen({
    required this.surface,
    required this.id,
    this.extras = const {},
  });

  /// Host surface: `anime` | `drama` | `tmdb` | `arabic` (feature routes).
  final String surface;
  /// Opaque id for that surface (string form of int or remote key).
  final String id;
  final Map<String, dynamic> extras;

  int? get idInt => int.tryParse(id);

  String? extraString(String key) {
    final v = extras[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  bool extraBool(String key) {
    final v = extras[key];
    if (v is bool) return v;
    if (v == null) return false;
    final s = v.toString().toLowerCase();
    return s == 'true' || s == '1';
  }

  static CatalogOpen? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final surface = (m['surface'] ?? m['route'] ?? '').toString().trim();
    final id = (m['id'] ?? '').toString().trim();
    if (surface.isEmpty || id.isEmpty) return null;
    final extras = Map<String, dynamic>.from(m)
      ..remove('surface')
      ..remove('route')
      ..remove('id');
    return CatalogOpen(surface: surface, id: id, extras: extras);
  }

  Map<String, dynamic> toJson() => {
        'surface': surface,
        'id': id,
        ...extras,
      };
}

/// Episode / playable unit on hub `details` meta (`videos[]`).
class CatalogVideo {
  const CatalogVideo({
    required this.id,
    required this.title,
    this.season,
    this.episode,
    this.thumbnail = '',
  });

  final String id;
  final String title;
  final int? season;
  final int? episode;
  final String thumbnail;

  factory CatalogVideo.fromJson(Map<String, dynamic> j) => CatalogVideo(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        season: (j['season'] as num?)?.toInt(),
        episode: (j['episode'] as num?)?.toInt(),
        thumbnail: (j['thumbnail'] ?? j['poster'] ?? '').toString(),
      );
}

/// One row from hub `stream` action.
class CatalogStream {
  const CatalogStream({
    required this.url,
    this.name = '',
    this.type = 'embed',
  });

  final String url;
  final String name;
  /// `direct` (mp4/hls) or legacy `embed` (resolved upstream in the pack/provider).
  final String type;

  bool get isDirect => type == 'direct' || type == 'hls' || type == 'mp4';

  factory CatalogStream.fromJson(Map<String, dynamic> j) => CatalogStream(
        url: (j['url'] ?? '').toString(),
        name: (j['name'] ?? j['title'] ?? '').toString(),
        type: (j['type'] ?? 'embed').toString(),
      );
}

class CatalogMetaItem {
  const CatalogMetaItem({
    required this.id,
    required this.type,
    required this.name,
    this.poster = '',
    this.background = '',
    this.description = '',
    this.rating,
    this.releaseInfo = '',
    this.genres = const [],
    this.badge,
    this.status,
    this.episodes,
    this.bannerImage = '',
    this.tmdbMediaType,
    this.ids = const {},
    this.listTarget,
    this.open,
    this.videos = const [],
  });

  final String id;
  final String type;
  final String name;
  final String poster;
  final String background;
  final String description;
  final double? rating;
  final String releaseInfo;
  final List<String> genres;
  final String? badge;
  /// Hub status wire (`RELEASING`, `NOT_YET_RELEASED`, …).
  final String? status;
  final int? episodes;
  /// Ultrawide banner — hero uses `fitWidth` when set (pre-cutover).
  final String bannerImage;
  /// Pack/kit TMDB media hint (`movie` / `tv`) from enrich.
  final String? tmdbMediaType;
  final Map<String, dynamic> ids;
  final Map<String, dynamic>? listTarget;
  /// Pack-declared host open route. Prefer over guessing from [ids] keys.
  final CatalogOpen? open;
  /// Pack-owned episode list from `details` (opaque video ids for `stream`).
  final List<CatalogVideo> videos;

  String? get idNamespace {
    final i = id.indexOf(':');
    if (i <= 0) return null;
    return id.substring(0, i);
  }

  /// Host id scheme lookup (e.g. `tmdb`). Do not use pack scraper keys here.
  int? numericId(String scheme) {
    final fromMap = ids[scheme];
    if (fromMap is num) return fromMap.toInt();
    if (fromMap != null) return int.tryParse(fromMap.toString());
    // tmdb:movie:603
    final parts = id.split(':');
    if (parts.isEmpty) return null;
    if (parts.first != scheme && !(scheme == 'tmdb' && parts.first == 'tmdb')) {
      return null;
    }
    for (var i = parts.length - 1; i >= 1; i--) {
      final n = int.tryParse(parts[i]);
      if (n != null) return n;
    }
    return null;
  }

  factory CatalogMetaItem.fromJson(Map<String, dynamic> j) {
    final genresRaw = j['genres'];
    final videosRaw = j['videos'];
    return CatalogMetaItem(
      id: (j['id'] ?? '').toString(),
      type: (j['type'] ?? 'movie').toString(),
      name: (j['name'] ?? '').toString(),
      poster: (j['poster'] ?? '').toString(),
      background: (j['background'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      rating: (j['rating'] as num?)?.toDouble(),
      releaseInfo: (j['releaseInfo'] ?? '').toString(),
      genres: genresRaw is List
          ? genresRaw.map((e) => e.toString()).toList()
          : const [],
      badge: j['badge']?.toString(),
      status: j['status']?.toString(),
      episodes: (j['episodes'] as num?)?.toInt(),
      bannerImage: (j['bannerImage'] ?? '').toString(),
      tmdbMediaType: j['tmdbMediaType']?.toString(),
      ids: j['ids'] is Map
          ? Map<String, dynamic>.from(j['ids'] as Map)
          : const {},
      listTarget: j['listTarget'] is Map
          ? Map<String, dynamic>.from(j['listTarget'] as Map)
          : null,
      open: CatalogOpen.fromJson(j['open']),
      videos: videosRaw is List
          ? [
              for (final e in videosRaw)
                if (e is Map)
                  CatalogVideo.fromJson(Map<String, dynamic>.from(e)),
            ]
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
        if (poster.isNotEmpty) 'poster': poster,
        if (background.isNotEmpty) 'background': background,
        if (description.isNotEmpty) 'description': description,
        if (rating != null) 'rating': rating,
        if (releaseInfo.isNotEmpty) 'releaseInfo': releaseInfo,
        if (genres.isNotEmpty) 'genres': genres,
        if (badge != null) 'badge': badge,
        if (status != null && status!.isNotEmpty) 'status': status,
        if (episodes != null) 'episodes': episodes,
        if (bannerImage.isNotEmpty) 'bannerImage': bannerImage,
        if (tmdbMediaType != null && tmdbMediaType!.isNotEmpty)
          'tmdbMediaType': tmdbMediaType,
        if (ids.isNotEmpty) 'ids': ids,
        if (listTarget != null) 'listTarget': listTarget,
        if (open != null) 'open': open!.toJson(),
        if (videos.isNotEmpty)
          'videos': [
            for (final v in videos)
              {
                'id': v.id,
                'title': v.title,
                if (v.season != null) 'season': v.season,
                if (v.episode != null) 'episode': v.episode,
                if (v.thumbnail.isNotEmpty) 'thumbnail': v.thumbnail,
              },
          ],
      };

  CatalogMetaItem copyWith({
    String? name,
    String? poster,
    String? description,
    List<CatalogVideo>? videos,
  }) =>
      CatalogMetaItem(
        id: id,
        type: type,
        name: name ?? this.name,
        poster: poster ?? this.poster,
        background: background,
        description: description ?? this.description,
        rating: rating,
        releaseInfo: releaseInfo,
        genres: genres,
        badge: badge,
        status: status,
        episodes: episodes,
        bannerImage: bannerImage,
        tmdbMediaType: tmdbMediaType,
        ids: ids,
        listTarget: listTarget,
        open: open,
        videos: videos ?? this.videos,
      );
}

class CatalogFilterAst {
  static Map<String, dynamic>? parse(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final op = (m['op'] ?? '').toString();
    if (op == 'and' || op == 'or') {
      final nodes = m['nodes'];
      if (nodes is! List || nodes.isEmpty) return null;
      final parsed = <Map<String, dynamic>>[];
      for (final n in nodes) {
        final p = parse(n);
        if (p != null) parsed.add(p);
      }
      if (parsed.isEmpty) return null;
      if (parsed.length == 1) return parsed.first;
      return {'op': op, 'nodes': parsed};
    }
    final field = (m['field'] ?? '').toString().trim();
    if (field.isEmpty) return null;
    if (!m.containsKey('value')) return null;
    return {
      'field': field,
      'op': op.isEmpty ? 'eq' : op,
      'value': m['value'],
    };
  }

  static Map<String, dynamic> eq(String field, Object value) => {
        'field': field,
        'op': 'eq',
        'value': value,
      };

  static Map<String, dynamic> inList(String field, List<Object> values) => {
        'field': field,
        'op': 'in',
        'value': values,
      };

  static Map<String, dynamic>? andFilters(
    Iterable<Map<String, dynamic>?> nodes,
  ) {
    final list = <Map<String, dynamic>>[
      for (final n in nodes)
        if (n != null) n,
    ];
    if (list.isEmpty) return null;
    if (list.length == 1) return list.first;
    return {'op': 'and', 'nodes': list};
  }
}

/// Host fallback when hub layout, manifest config, and rail response omit page size.
const int kCatalogRailPageSizeFallback = 20;

const _catalogRailPageSizeKeys = [
  'pageSize',
  'limit',
  'perPage',
  'page_size',
];

/// Reads pack-declared rail page size from layout widgets, page defaults,
/// manifest `config`, or rail response `data`.
int? catalogRailPageSizeFrom(Map<String, dynamic>? source) {
  if (source == null) return null;
  for (final key in _catalogRailPageSizeKeys) {
    final v = source[key];
    if (v is num && v.toInt() > 0) return v.toInt();
    final parsed = int.tryParse(v?.toString() ?? '');
    if (parsed != null && parsed > 0) return parsed;
  }
  return null;
}

bool? catalogRailHasMoreFrom(Map<String, dynamic>? source) {
  if (source == null) return null;
  final v = source['hasMore'];
  if (v is bool) return v;
  return null;
}

/// One fetched rail page — items plus optional pack paging metadata.
class CatalogRailPage<T> {
  const CatalogRailPage({
    required this.items,
    this.pageSize,
    this.hasMore,
  });

  const CatalogRailPage.empty()
      : items = const [],
        pageSize = null,
        hasMore = null;

  final List<T> items;
  final int? pageSize;
  final bool? hasMore;
}

/// Null when valid; otherwise a short reason string.
String? validateLayoutData(Map<String, dynamic>? data) {
  if (data == null) return 'missing data';
  final pages = data['pages'];
  if (pages is! Map || pages.isEmpty) return 'missing pages';
  for (final entry in pages.entries) {
    final page = entry.value;
    if (page is! Map) return 'page ${entry.key} invalid';
    final widgets = page['widgets'];
    if (widgets is! List || widgets.isEmpty) {
      return 'page ${entry.key} missing widgets';
    }
    for (final w in widgets) {
      if (w is! Map) return 'widget not an object';
      if ((w['type'] ?? '').toString().trim().isEmpty) {
        return 'widget missing type';
      }
    }
  }
  return null;
}

class CatalogNavSpec {
  const CatalogNavSpec({
    required this.tabId,
    required this.label,
    required this.order,
    this.pluginId,
    this.icon,
    this.accent,
    this.defaultEnabled = true,
  });

  final String tabId;
  final String label;
  final int order;
  final String? pluginId;
  final String? icon;
  final String? accent;
  final bool defaultEnabled;

  static CatalogNavSpec? fromPluginNav(
    Map<String, dynamic>? nav, {
    String? pluginId,
    String? fallbackLabel,
  }) {
    if (nav == null) return null;
    final iconRaw = nav['icon'];
    String? icon;
    if (iconRaw is String) {
      icon = iconRaw;
    } else if (iconRaw is Map) {
      icon = (iconRaw['asset'] ?? iconRaw['material'])?.toString();
    }
    final tabId = (nav['tabId'] ?? '').toString().trim();
    final label = (nav['label'] ?? fallbackLabel ?? '').toString().trim();
    if (tabId.isEmpty || label.isEmpty) return null;
    return CatalogNavSpec(
      tabId: tabId,
      label: label,
      order: (nav['order'] as num?)?.toInt() ?? 100,
      pluginId: pluginId,
      icon: icon,
      accent: nav['accent']?.toString(),
      defaultEnabled: nav['defaultEnabled'] != false,
    );
  }

  bool get isValid => tabId.isNotEmpty && label.isNotEmpty;
}
