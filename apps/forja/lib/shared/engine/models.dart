import 'ids.dart';

class EnginePlugin {
  EnginePlugin({
    required this.id,
    required this.name,
    required this.entry,
    this.description,
    this.types = const ['movie', 'tv'],
    this.ids = const [],
    this.kind = 'http',
    this.hostId,
    this.hosts = const [],
    this.enabled = true,
    this.config = const {},
  });

  final String id;
  final String name;
  final String entry;
  final String? description;
  final List<String> types;

  /// Catalog keys this plugin reads from `extract(ctx)`:
  /// `title`, `tmdb`, `imdb`, `mal`, `anilist`.
  final List<String> ids;
  final String kind;

  /// When [kind] is `host`, which built-in provider to resolve (`vidsrc`, …).
  final String? hostId;

  /// Hostnames this plugin handles. Used by `kind: hop` (`ctx.hop(url)`).
  final List<String> hosts;
  final bool enabled;
  final Map<String, dynamic> config;

  bool get isHttp => kind == 'http';
  bool get isHost => kind == 'host';
  bool get isHop => kind == 'hop';

  /// Live Matches engine.json `types` (RFC-065).
  bool get isLiveCatalog => types.contains('catalog');
  bool get isLiveProvider => types.contains('providers');
  bool get isLiveSport => types.contains('live_sport');

  /// Any Forja Sports / Live Matches plugin (catalog orchestrator, resolve, sport feeds).
  bool get isLive =>
      isLiveCatalog || isLiveProvider || isLiveSport || types.contains('live');

  /// Sources chips: HTTP catalog plugins only. Hops are internal; host sniff
  /// stays on green Play (`ctx.host` fallback), not as Forja chips.
  bool get isExtractable => isHttp;

  /// Movie/TV Sources → Forja — not Live Matches plugins.
  bool get isVodCatalog => isExtractable && !isLive;

  List<String> get hopHosts {
    final out = <String>[...hosts];
    final cfg = config['hosts'];
    if (cfg is List) {
      for (final e in cfg) {
        final s = e.toString().trim();
        if (s.isNotEmpty) out.add(s);
      }
    }
    return out;
  }

  String get hostProviderId {
    final h = hostId?.trim();
    if (h != null && h.isNotEmpty) return h;
    return id;
  }

  factory EnginePlugin.fromJson(Map<String, dynamic> j) {
    final id = (j['id'] ?? '').toString().trim();
    if (id.isEmpty) {
      throw const FormatException('engine plugin missing id');
    }
    return EnginePlugin(
      id: id,
      name: (j['name'] as String?)?.trim().isNotEmpty == true
          ? (j['name'] as String).trim()
          : id,
      entry:
          (j['entry'] as String?)?.trim() ??
          (j['filename'] as String?)?.trim() ??
          '',
      description: (j['description'] as String?)?.trim(),
      types:
          ((j['types'] as List?) ??
                  (j['supportedTypes'] as List?) ??
                  const ['movie', 'tv'])
              .map((e) => e.toString())
              .toList(),
      ids: _stringList(j['ids']),
      kind: (j['kind'] as String?)?.trim().isNotEmpty == true
          ? (j['kind'] as String).trim()
          : 'http',
      hostId: (j['hostId'] as String?)?.trim(),
      hosts: _stringList(j['hosts']),
      enabled: (j['enabled'] as bool?) ?? true,
      config: engineConfigMap(j['config']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'entry': entry,
    if (description != null) 'description': description,
    'types': types,
    if (ids.isNotEmpty) 'ids': ids,
    'kind': kind,
    if (hostId != null) 'hostId': hostId,
    if (hosts.isNotEmpty) 'hosts': hosts,
    'enabled': enabled,
    if (config.isNotEmpty) 'config': config,
  };

  EnginePlugin copyWith({bool? enabled}) => EnginePlugin(
    id: id,
    name: name,
    entry: entry,
    description: description,
    types: types,
    ids: ids,
    kind: kind,
    hostId: hostId,
    hosts: hosts,
    enabled: enabled ?? this.enabled,
    config: config,
  );
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e.toString().trim().isNotEmpty) e.toString().trim(),
  ];
}

/// First hop plugin whose [EnginePlugin.hopHosts] suffix-matches [url].
String? hopPluginIdForUrl(String url, Iterable<EnginePlugin> plugins) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  if (host.isEmpty) return null;
  for (final p in plugins) {
    if (!p.isHop) continue;
    for (final h in p.hopHosts) {
      final n = h.toLowerCase().trim();
      if (n.isEmpty) continue;
      if (host == n || host.endsWith('.$n')) return p.id;
    }
  }
  return null;
}

class EnginePack {
  EnginePack({
    required this.sourceUrl,
    required this.name,
    required this.version,
    required this.plugins,
    this.bundled = false,
  });

  final String sourceUrl;
  final String name;
  final String version;
  final List<EnginePlugin> plugins;
  final bool bundled;

  factory EnginePack.fromJson(
    Map<String, dynamic> j, {
    required String sourceUrl,
    bool bundled = false,
  }) {
    final pluginsRaw = j['plugins'];
    final List<EnginePlugin> plugins;
    if (pluginsRaw is List) {
      plugins = [
        for (final raw in pluginsRaw)
          if (raw is Map) EnginePlugin.fromJson(Map<String, dynamic>.from(raw)),
      ];
    } else if ((j['id'] ?? '').toString().trim().isNotEmpty) {
      plugins = [EnginePlugin.fromJson(j)];
    } else {
      plugins = const [];
    }
    if (plugins.isEmpty) {
      throw const FormatException('engine.json has no plugins');
    }
    return EnginePack(
      sourceUrl: sourceUrl,
      name: (j['name'] as String?)?.trim().isNotEmpty == true
          ? (j['name'] as String).trim()
          : plugins.first.name,
      version: (j['version'] as String?)?.trim() ?? '0.0.0',
      plugins: plugins,
      bundled: bundled,
    );
  }

  Map<String, dynamic> toJson() => {
    'sourceUrl': sourceUrl,
    'name': name,
    'version': version,
    'bundled': bundled,
    'plugins': [for (final p in plugins) p.toJson()],
  };

  factory EnginePack.fromStored(Map<String, dynamic> j) => EnginePack(
    sourceUrl: (j['sourceUrl'] as String?) ?? '',
    name: (j['name'] as String?) ?? 'Engine',
    version: (j['version'] as String?) ?? '0.0.0',
    bundled: j['bundled'] == true,
    plugins: [
      for (final raw in (j['plugins'] as List? ?? const []))
        if (raw is Map) EnginePlugin.fromJson(Map<String, dynamic>.from(raw)),
    ],
  );

  EnginePack copyWithPlugins(List<EnginePlugin> next) => EnginePack(
    sourceUrl: sourceUrl,
    name: name,
    version: version,
    plugins: next,
    bundled: bundled,
  );
}

class EngineExtractResult {
  const EngineExtractResult({
    required this.pluginId,
    required this.pluginName,
    required this.streams,
  });

  final String pluginId;
  final String pluginName;
  final List<Map<String, dynamic>> streams;
}

Set<String> enabledEnginePluginIds(List<EnginePack> packs) => {
  for (final pack in packs)
    for (final p in pack.plugins)
      if (p.enabled && p.isHttp) p.id,
};

/// Walk order for the Forja tab: HTTP/JS plugins only (no sniff hosts).
List<String> orderedEnginePluginIds(List<EnginePack> packs) {
  final ids = <String>[];
  for (final pack in packs) {
    for (final p in pack.plugins) {
      if (p.enabled && p.isHttp) ids.add(p.id);
    }
  }
  return ids;
}

Set<String> nextEngineSelectedAfterAllTap({
  required Set<String> selectedIds,
  required Set<String> enabledIds,
}) {
  if (enabledIds.isEmpty) return {};
  final allOn = enabledIds.every(selectedIds.contains);
  return allOn ? <String>{} : Set<String>.from(enabledIds);
}

bool engineStreamBelongsToPlugin(Map<String, dynamic> stream, String pluginId) {
  final id = stream['_enginePluginId'] as String?;
  if (id == pluginId) return true;
  return stream['_addonBaseUrl']?.toString() == EngineIds.pluginChip(pluginId);
}

bool enginePluginHasStreams(
  String pluginId,
  Iterable<Map<String, dynamic>> streams,
) => streams.any((s) => engineStreamBelongsToPlugin(s, pluginId));

/// Fetched markers with no rows — used when expanding All / forcing refetch of
/// empty chips. Do **not** apply on soft session-cache hydrate (that made
/// player Sources re-extract every empty Forja plugin after details).
Set<String> engineStaleFetchedPluginIds({
  required Set<String> fetchedIds,
  required Set<String> selectedIds,
  required Iterable<Map<String, dynamic>> streams,
}) => {
  for (final id in fetchedIds)
    if (selectedIds.contains(id) && !enginePluginHasStreams(id, streams)) id,
};

Set<String> enginePluginIdsToRefetchOnAllExpand({
  required Set<String> previousSelectedIds,
  required Set<String> nextSelectedIds,
  required Set<String> fetchedIds,
  required Iterable<Map<String, dynamic>> streams,
}) {
  final out = nextSelectedIds.difference(previousSelectedIds);
  out.addAll(
    engineStaleFetchedPluginIds(
      fetchedIds: fetchedIds,
      selectedIds: nextSelectedIds,
      streams: streams,
    ),
  );
  return out;
}

bool engineFullAllSelected({
  required Set<String> enabledIds,
  required Set<String> selectedIds,
}) => enabledIds.isNotEmpty && enabledIds.every(selectedIds.contains);

Set<String> filterEngineSelectedPluginIds({
  required Iterable<String> savedIds,
  required Set<String> enabledIds,
}) => {
  for (final id in savedIds)
    if (enabledIds.contains(id)) id,
};

String? nextEnginePluginId({
  required List<String> orderedIds,
  required Set<String> selectedIds,
  required Set<String> fetchedIds,
}) {
  for (final id in orderedIds) {
    if (selectedIds.contains(id) && !fetchedIds.contains(id)) return id;
  }
  return null;
}

const kEngineSourcesBatchDesktop = 10;
const kEngineSourcesBatchTv = 5;

int engineSourcesBatchLimit({required bool tv}) =>
    tv ? kEngineSourcesBatchTv : kEngineSourcesBatchDesktop;

List<String> nextEnginePluginBatch({
  required Iterable<String> orderedIds,
  required Set<String> selectedIds,
  required Set<String> fetchedIds,
  required int limit,
}) {
  final out = <String>[];
  for (final id in orderedIds) {
    if (out.length >= limit) break;
    if (selectedIds.contains(id) && !fetchedIds.contains(id)) out.add(id);
  }
  return out;
}

Map<String, dynamic> engineConfigMap(dynamic raw) {
  if (raw is! Map) return const {};
  return Map<String, dynamic>.from(raw);
}

/// Overlay wins. Nested maps merge; lists and scalars replace.
Map<String, dynamic> mergeEngineConfig(
  Map<String, dynamic> base,
  Map<String, dynamic> overlay,
) {
  if (overlay.isEmpty) return Map<String, dynamic>.from(base);
  if (base.isEmpty) return Map<String, dynamic>.from(overlay);
  final out = Map<String, dynamic>.from(base);
  overlay.forEach((key, value) {
    final existing = out[key];
    if (value is Map && existing is Map) {
      out[key] = mergeEngineConfig(
        Map<String, dynamic>.from(existing),
        Map<String, dynamic>.from(value),
      );
    } else {
      out[key] = value;
    }
  });
  return out;
}

/// Asian Drama Sources already knows KissKh drama/episode ids. Inject them
/// into kisskh plugin config so extract skips title search (Search has no
/// `tmdbID`, so TMDB match always misses).
Map<String, dynamic> engineConfigWithKissKhIds(
  Map<String, dynamic> config, {
  required String pluginId,
  int? kisskhId,
  int? kisskhEpisodeId,
}) {
  if (pluginId != 'kisskh') return config;
  final drama = kisskhId ?? 0;
  final ep = kisskhEpisodeId ?? 0;
  if (drama <= 0 && ep <= 0) return config;
  final out = Map<String, dynamic>.from(config);
  if (ep > 0) out['episodeId'] = ep;
  if (drama > 0) out['dramaId'] = drama;
  return out;
}

/// Card title matching Nuvio plugin rows: `Show S1E1 - (2026)`.
String engineMediaDisplayTitle({
  String? title,
  String? year,
  String? type,
  int? season,
  int? episode,
}) {
  final t = (title ?? '').trim();
  if (t.isEmpty) return '';
  final buf = StringBuffer(t);
  final isTv = type == 'tv' || type == 'series';
  if (isTv && season != null && episode != null && season > 0 && episode > 0) {
    buf.write(' S${season}E$episode');
  }
  final y = (year ?? '').trim();
  final y4 = y.length >= 4 ? y.substring(0, 4) : y;
  if (RegExp(r'^\d{4}$').hasMatch(y4)) {
    buf.write(' - ($y4)');
  }
  return buf.toString();
}

String? normalizeEngineQuality(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return null;
  final lower = s.toLowerCase();
  if (lower == 'auto' ||
      lower == 'adaptive' ||
      lower == 'unknown' ||
      lower == 'english' ||
      lower == 'hindi' ||
      lower == 'german') {
    return null;
  }
  const aliases = <String, String>{
    '4k': '4K',
    '2160p': '4K',
    '2160': '4K',
    'uhd': '4K',
    '1440p': '1440p',
    '1440': '1440p',
    '1080p': '1080p',
    '1080': '1080p',
    'fhd': '1080p',
    '720p': '720p',
    '720': '720p',
    '480p': '480p',
    '480': '480p',
    '360p': '360p',
    '360': '360p',
  };
  final aliased = aliases[lower];
  if (aliased != null) return aliased;
  return engineQualityFromText(s);
}

String? engineQualityFromText(String raw) {
  final n = raw.toUpperCase();
  if (n.contains('2160') || n.contains('4K') || n.contains('UHD')) return '4K';
  if (n.contains('1080')) return '1080p';
  if (n.contains('1440')) return '1440p';
  if (n.contains('720')) return '720p';
  if (n.contains('480')) return '480p';
  if (n.contains('360')) return '360p';
  return null;
}

String? engineLanguageLabel(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return null;
  switch (s.toLowerCase()) {
    case 'de':
    case 'ger':
    case 'german':
      return 'German';
    case 'en':
    case 'eng':
    case 'english':
      return 'English';
    case 'hi':
    case 'hin':
    case 'hindi':
      return 'Hindi';
    default:
      return s;
  }
}

String engineServerLabel({
  required String pluginName,
  String? name,
  String? title,
}) {
  final n = (name ?? '').trim();
  final t = (title ?? '').trim();
  final candidate = n.isNotEmpty && n != t ? n : (n.isNotEmpty ? n : t);
  if (candidate.isEmpty) return pluginName;
  final cut = candidate.split(RegExp(r'\s*[·•|]\s*')).first.trim();
  if (cut.isEmpty || cut == candidate && candidate.length > 48) {
    return pluginName;
  }
  return cut;
}

Map<String, String> engineHeadersFrom(dynamic raw) {
  final headers = <String, String>{};
  if (raw is! Map) return headers;
  raw.forEach((k, v) {
    if (v == null) return;
    final ks = k.toString().trim();
    final vs = v.toString().trim();
    if (ks.isNotEmpty && vs.isNotEmpty) headers[ks] = vs;
  });
  return headers;
}

/// Maps a plugin/host row onto the Stremio-shaped map Sources tiles parse.
Map<String, dynamic>? mapEngineStream({
  required Map<String, dynamic> raw,
  required EnginePlugin plugin,
  String? mediaTitle,
  String? year,
  String? type,
  int? season,
  int? episode,
  bool requiresProxy = false,
}) {
  final url = (raw['url'] ?? '').toString().trim();
  if (url.isEmpty) return null;
  final headers = engineHeadersFrom(raw['headers']);
  final rawQuality = (raw['quality'] ?? '').toString();
  final quality =
      normalizeEngineQuality(rawQuality) ??
      engineQualityFromText('${raw['title'] ?? ''} ${raw['name'] ?? ''}');
  final language =
      engineLanguageLabel((raw['language'] ?? '').toString()) ??
      engineLanguageLabel(rawQuality);
  final audio = () {
    final a = (raw['audio'] ?? '').toString().trim();
    return a.isEmpty ? null : a;
  }();
  final size = () {
    final s = (raw['size'] ?? '').toString().trim();
    return s.isEmpty || s.toLowerCase() == 'unknown' ? null : s;
  }();
  final displayTitle = engineMediaDisplayTitle(
    title: mediaTitle,
    year: year,
    type: type,
    season: season,
    episode: episode,
  );
  final server = engineServerLabel(
    pluginName: plugin.name,
    name: (raw['name'] ?? '').toString(),
    title: (raw['title'] ?? '').toString(),
  );
  final addonName = server == plugin.name
      ? plugin.name
      : '${plugin.name} · $server';
  final desc = [
    if (quality != null) quality,
    if (audio != null) audio,
    if (language != null) language,
  ].join(' ');
  final cardTitle = displayTitle.isNotEmpty
      ? displayTitle
      : (raw['title'] ?? raw['name'] ?? plugin.name).toString();
  return {
    'url': url,
    'title': cardTitle,
    'name': addonName,
    if (desc.isNotEmpty) 'description': desc,
    if (quality != null) 'quality': quality,
    if (language != null) 'language': language,
    if (size != null) 'size': size,
    if (headers.isNotEmpty) 'headers': headers,
    if (headers.isNotEmpty)
      'behaviorHints': {
        'notWebReady': true,
        'proxyHeaders': {'request': headers},
      },
    if (requiresProxy ||
        raw['requiresProxy'] == true ||
        raw['requires_proxy'] == true)
      'requires_proxy': true,
    if (raw['subtitles'] is List && (raw['subtitles'] as List).isNotEmpty)
      'subtitles': raw['subtitles'],
    '_addonBaseUrl': 'engine:${plugin.id}',
    '_addonName': addonName,
    '_enginePluginId': plugin.id,
  };
}
