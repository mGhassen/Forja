import 'package:flutter/foundation.dart';
import 'package:forja/shared/widgets/media_details/torrent_release_metadata.dart';

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
    this.prelude = '',
    this.protocol,
    this.kit,
    this.capabilities = const [],
    this.nav,
    this.enrich,
    this.ctxConfigMap = const {},
    this.defaultCapabilities = const {},
    this.liveLegacyIds,
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

  /// Optional shared JS fetched relative to the manifest and prepended at load.
  /// Declared by the pack (`prelude`) — host does not hardcode pack paths.
  final String prelude;

  /// Catalog hub protocol version the plugin speaks ([hostProtocolVersion]).
  final int? protocol;

  /// Catalog hub `ctx` kit version the plugin needs ([hostKitVersion]).
  final int? kit;

  /// Declared hub features (`nav`, `search`, `host_search`, `structured_search`, `details`, `filters`, `auth`, …).
  final List<String> capabilities;

  /// Nav contribution — parsed by `CatalogNavSpec.fromPluginNav`.
  final Map<String, dynamic>? nav;

  /// Optional companion catalog plugin id for post-rail / post-details enrich.
  /// Source plugins stay data-only; host pipes `items` / `meta` through this.
  final String? enrich;

  /// Maps `open.extract.ctx` keys → plugin `config` keys at extract time.
  /// Declared in pack manifest — host does not branch on plugin id.
  final Map<String, String> ctxConfigMap;

  /// First-run Settings defaults for `live_sport` capability toggles (`catalog`, `resolve`).
  final Map<String, bool> defaultCapabilities;

  /// Retired twin-pack ids for one-time capability-pref migration (`catalog-*`, `live-*`).
  final LiveSportLegacyIds? liveLegacyIds;

  bool get isHttp => kind == 'http';
  bool get isHost => kind == 'host';
  bool get isHop => kind == 'hop';
  bool get isTorrent => kind == 'torrent';

  /// Catalog hub plugin — serves shell tabs through the catalog protocol.
  bool get isHubCatalog => kind == 'catalog';

  /// Pack install must cache JS for this plugin.
  bool get needsScript => isHttp || isHop || isHubCatalog || isTorrent;

  bool hasCapability(String name) {
    final want = name.trim().toLowerCase();
    if (want.isEmpty) return false;
    return capabilities.any((c) => c.toLowerCase() == want);
  }

  /// Unified live sport plugins (`types: live_sport`, not hub `kind: catalog`).
  bool get isLiveSportPlugin =>
      types.contains('live_sport') && !isHubCatalog;

  /// Legacy schedule plugins (`types: catalog`, not hub `kind: catalog`).
  bool get isLiveCatalog => types.contains('catalog') && !isHubCatalog;
  bool get isLivePlugin => types.contains('plugins');
  bool get isLiveSport => types.contains('live_sport');
  /// Resolve-only entries in `plugins/live/manifest.json` (`types: live`).
  bool get isLiveResolve => types.contains('live');

  bool get supportsLiveCatalog =>
      isLiveSportPlugin ? hasCapability('catalog') : isLiveCatalog;

  /// IPTV broadcast channel hints on catalog rows (`broadcast` capability).
  bool get supportsLiveBroadcast =>
      (isLiveSportPlugin || isLiveCatalog) && hasCapability('broadcast');

  bool get supportsLiveResolve =>
      isLiveSportPlugin
          ? hasCapability('resolve')
          : isLiveResolve || isLivePlugin || isLiveSport;

  /// Any Forja Sports / Live Matches plugin (catalog orchestrator, resolve, sport feeds).
  bool get isLive =>
      isLiveSportPlugin ||
      isLiveCatalog ||
      isLiveResolve ||
      isLivePlugin ||
      isLiveSport;

  /// Sources chips: HTTP VOD only — hops and hub catalogs are never chips.
  bool get isExtractable => isHttp && !isHubCatalog;

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
    final config = engineConfigMap(j['config']);
    final preludeRaw = (j['prelude'] as String?)?.trim() ?? '';
    final preludeFromConfig = config['prelude']?.toString().trim() ?? '';
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
      config: config,
      prelude: preludeRaw.isNotEmpty ? preludeRaw : preludeFromConfig,
      protocol: _asPluginInt(j['protocol']),
      kit: _asPluginInt(j['kit']),
      capabilities: _stringList(j['capabilities']),
      nav: j['nav'] is Map ? Map<String, dynamic>.from(j['nav'] as Map) : null,
      enrich: (j['enrich'] as String?)?.trim().isNotEmpty == true
          ? (j['enrich'] as String).trim()
          : null,
      ctxConfigMap: _ctxConfigMap(j['ctxConfigMap']),
      defaultCapabilities: _defaultCapabilitiesMap(j['defaultCapabilities']),
      liveLegacyIds: LiveSportLegacyIds.fromJson(j['legacyIds']),
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
    if (prelude.isNotEmpty) 'prelude': prelude,
    if (protocol != null) 'protocol': protocol,
    if (kit != null) 'kit': kit,
    if (capabilities.isNotEmpty) 'capabilities': capabilities,
    if (nav != null) 'nav': nav,
    if (enrich != null && enrich!.isNotEmpty) 'enrich': enrich,
    if (ctxConfigMap.isNotEmpty) 'ctxConfigMap': ctxConfigMap,
    if (defaultCapabilities.isNotEmpty) 'defaultCapabilities': defaultCapabilities,
    if (liveLegacyIds != null && !liveLegacyIds!.isEmpty)
      'legacyIds': liveLegacyIds!.toJson(),
  };

  EnginePlugin copyWith({bool? enabled, String? prelude}) => EnginePlugin(
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
    prelude: prelude ?? this.prelude,
    protocol: protocol,
    kit: kit,
    capabilities: capabilities,
    nav: nav,
    enrich: enrich,
    ctxConfigMap: ctxConfigMap,
    defaultCapabilities: defaultCapabilities,
    liveLegacyIds: liveLegacyIds,
  );
}

/// Retired `catalog-*` / `live-*` plugin ids for unified `live_sport` migration.
class LiveSportLegacyIds {
  const LiveSportLegacyIds({this.catalog, this.resolve});

  final String? catalog;
  final String? resolve;

  bool get isEmpty =>
      (catalog == null || catalog!.isEmpty) &&
      (resolve == null || resolve!.isEmpty);

  static LiveSportLegacyIds? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final catalog = (raw['catalog'] as String?)?.trim();
    final resolve = (raw['resolve'] as String?)?.trim();
    final out = LiveSportLegacyIds(
      catalog: catalog?.isNotEmpty == true ? catalog : null,
      resolve: resolve?.isNotEmpty == true ? resolve : null,
    );
    return out.isEmpty ? null : out;
  }

  Map<String, String> toJson() => {
    'catalog': ?catalog,
    'resolve': ?resolve,
  };
}

Map<String, bool> _defaultCapabilitiesMap(dynamic raw) {
  if (raw is! Map) return const {};
  final out = <String, bool>{};
  raw.forEach((k, v) {
    final key = k.toString().trim().toLowerCase();
    if (key.isEmpty || v is! bool) return;
    out[key] = v;
  });
  return out;
}

Map<String, String> _ctxConfigMap(dynamic raw) {
  if (raw is! Map) return const {};
  final out = <String, String>{};
  raw.forEach((k, v) {
    final dest = k.toString().trim();
    final src = v?.toString().trim() ?? '';
    if (dest.isNotEmpty && src.isNotEmpty) out[dest] = src;
  });
  return out;
}

int? _asPluginInt(dynamic raw) {
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString().trim() ?? '');
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
    required this.packId,
    required this.name,
    required this.version,
    required this.plugins,
    this.prelude = '',
    this.bundle = const [],
    this.enabled = true,
  });

  final String sourceUrl;

  /// Stable pack identity from manifest `id` (not the install URL).
  final String packId;
  final String name;
  final String version;
  final List<EnginePlugin> plugins;

  /// Shared JS prelude for every plugin in this pack (manifest root `prelude`).
  final String prelude;

  /// Pack-relative script paths to download on install (`bundle` in manifest).
  /// Empty → host derives paths from plugin `entry` / `prelude` fields.
  final List<String> bundle;

  /// Pack master switch — independent of per-plugin [EnginePlugin.enabled].
  final bool enabled;

  /// Plugin contributes only when the pack and the plugin are both on.
  bool isPluginActive(EnginePlugin p) => enabled && p.enabled;

  factory EnginePack.fromJson(
    Map<String, dynamic> j, {
    required String sourceUrl,
  }) {
    final packPrelude = (j['prelude'] as String?)?.trim() ?? '';
    final pluginsRaw = j['plugins'];
    final List<EnginePlugin> plugins;
    if (pluginsRaw is List) {
      plugins = [
        for (final raw in pluginsRaw)
          if (raw is Map)
            _pluginFromManifestEntry(
              Map<String, dynamic>.from(raw),
              packPrelude: packPrelude,
            ),
      ];
    } else if ((j['id'] ?? '').toString().trim().isNotEmpty &&
        j['plugins'] == null) {
      // Single-plugin root manifest (legacy shape).
      plugins = [
        _pluginFromManifestEntry(j, packPrelude: packPrelude),
      ];
    } else {
      plugins = const [];
    }
    if (plugins.isEmpty) {
      throw const FormatException('manifest has no plugins');
    }
    final packIdRaw = (j['id'] as String?)?.trim() ?? '';
    final name = (j['name'] as String?)?.trim().isNotEmpty == true
        ? (j['name'] as String).trim()
        : plugins.first.name;
    return EnginePack(
      sourceUrl: sourceUrl,
      packId: packIdRaw.isNotEmpty
          ? packIdRaw
          : EnginePack.packIdFromSourceUrl(sourceUrl),
      name: name,
      version: (j['version'] as String?)?.trim() ?? '0.0.0',
      plugins: plugins,
      prelude: packPrelude,
      bundle: _bundlePathsFromJson(j['bundle']),
      enabled: (j['enabled'] as bool?) ?? true,
    );
  }

  /// Manifest `bundle`: list of pack-relative file paths. Legacy string ignored.
  static List<String> _bundlePathsFromJson(dynamic raw) {
    if (raw is! List) return const [];
    final out = <String>[];
    final seen = <String>{};
    for (final e in raw) {
      if (e is! String) continue;
      final path = e.trim().replaceAll('\\', '/');
      if (path.isEmpty || !seen.add(path)) continue;
      out.add(path);
    }
    return out;
  }

  static EnginePlugin _pluginFromManifestEntry(
    Map<String, dynamic> j, {
    required String packPrelude,
  }) {
    final plugin = EnginePlugin.fromJson(j);
    if (plugin.prelude.isNotEmpty || packPrelude.isEmpty) return plugin;
    return plugin.copyWith(prelude: packPrelude);
  }

  /// Derive a stable packId when the manifest omits `id`.
  static String packIdFromSourceUrl(String sourceUrl) =>
      'pack-${urlHash(sourceUrl)}';

  /// Short stable hash of a source URL (prefs key segment).
  static String urlHash(String sourceUrl) {
    var h = 2166136261;
    for (final c in sourceUrl.codeUnits) {
      h ^= c;
      h = (h * 16777619) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  Map<String, dynamic> toJson() => {
    'sourceUrl': sourceUrl,
    'packId': packId,
    'name': name,
    'version': version,
    if (prelude.isNotEmpty) 'prelude': prelude,
    if (bundle.isNotEmpty) 'bundle': bundle,
    'enabled': enabled,
    'plugins': [for (final p in plugins) p.toJson()],
  };

  factory EnginePack.fromStored(Map<String, dynamic> j) {
    final sourceUrl = (j['sourceUrl'] as String?) ?? '';
    final packIdRaw = (j['packId'] as String?)?.trim() ?? '';
    return EnginePack(
      sourceUrl: sourceUrl,
      packId: packIdRaw.isNotEmpty
          ? packIdRaw
          : packIdFromSourceUrl(sourceUrl),
      name: (j['name'] as String?) ?? 'Engine',
      version: (j['version'] as String?) ?? '0.0.0',
      enabled: (j['enabled'] as bool?) ?? true,
      prelude: (j['prelude'] as String?)?.trim() ?? '',
      bundle: _bundlePathsFromJson(j['bundle']),
      plugins: [
        for (final raw in (j['plugins'] as List? ?? const []))
          if (raw is Map)
            _pluginFromManifestEntry(
              Map<String, dynamic>.from(raw),
              packPrelude: (j['prelude'] as String?)?.trim() ?? '',
            ),
      ],
    );
  }

  EnginePack copyWith({
    bool? enabled,
    List<EnginePlugin>? plugins,
    List<String>? bundle,
  }) =>
      EnginePack(
        sourceUrl: sourceUrl,
        packId: packId,
        name: name,
        version: version,
        plugins: plugins ?? this.plugins,
        prelude: prelude,
        bundle: bundle ?? this.bundle,
        enabled: enabled ?? this.enabled,
      );

  EnginePack copyWithPlugins(List<EnginePlugin> next) =>
      copyWith(plugins: next);
}

/// Remote manifest is newer than the installed pack.
@immutable
class EnginePackUpdateInfo {
  const EnginePackUpdateInfo({
    required this.sourceUrl,
    required this.packName,
    required this.installedVersion,
    required this.remoteVersion,
  });

  final String sourceUrl;
  final String packName;
  final String installedVersion;
  final String remoteVersion;
}

/// Compare semver-ish `a.b.c` strings. Returns negative if [a] < [b].
int compareEngineSemver(String a, String b) {
  List<int> parts(String s) {
    final out = <int>[];
    for (final p in s.trim().split('.')) {
      final n = int.tryParse(p.replaceAll(RegExp(r'[^0-9].*$'), '')) ?? 0;
      out.add(n);
    }
    while (out.length < 3) {
      out.add(0);
    }
    return out.take(3).toList();
  }

  final pa = parts(a);
  final pb = parts(b);
  for (var i = 0; i < 3; i++) {
    final c = pa[i].compareTo(pb[i]);
    if (c != 0) return c;
  }
  return 0;
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
    if (pack.enabled)
      for (final p in pack.plugins)
        if (p.enabled && p.isHttp) p.id,
};

/// Walk order for the Forja tab: HTTP/JS plugins only (no sniff hosts).
List<String> orderedEnginePluginIds(List<EnginePack> packs) {
  final ids = <String>[];
  for (final pack in packs) {
    if (!pack.enabled) continue;
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

/// Tap a plugin chip when not in All mode — toggle load selection.
Set<String> nextEngineSelectedAfterPluginTap({
  required Set<String> selectedIds,
  required Set<String> enabledIds,
  required String pluginId,
}) {
  if (selectedIds.contains(pluginId)) {
    return Set<String>.from(selectedIds)..remove(pluginId);
  }
  return {...selectedIds, pluginId};
}

/// All group vs provider group — [allMode] + [viewFilterPluginIds] (empty = all).
bool engineProviderChipSelected({
  required String optionId,
  required bool allMode,
  required Set<String> selectedPluginIds,
  required Set<String> viewFilterPluginIds,
}) {
  if (optionId == EngineIds.allChip) return allMode;
  final pluginId = EngineIds.pluginIdFromChip(optionId);
  if (pluginId == null) return false;
  if (allMode) return viewFilterPluginIds.contains(pluginId);
  return selectedPluginIds.contains(pluginId);
}

Set<String> toggleSourcesPanelViewFilter(
  Set<String> current,
  String id,
) {
  if (current.contains(id)) {
    return Set<String>.from(current)..remove(id);
  }
  return {...current, id};
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
/// empty chips, and when green Play must not treat empties as terminal.
Set<String> engineStaleFetchedPluginIds({
  required Set<String> fetchedIds,
  required Set<String> selectedIds,
  required Iterable<Map<String, dynamic>> streams,
}) => {
  for (final id in fetchedIds)
    if (selectedIds.contains(id) && !enginePluginHasStreams(id, streams)) id,
};

/// Plugins to fetch when expanding All — only newly selected ids that were
/// never fetched. Already-fetched empties stay cached (kind/chip reload retries).
///
/// [streams] is unused (kept so call sites stay stable).
Set<String> enginePluginIdsToRefetchOnAllExpand({
  required Set<String> previousSelectedIds,
  required Set<String> nextSelectedIds,
  required Set<String> fetchedIds,
  required Iterable<Map<String, dynamic>> streams,
}) {
  final newlySelected = nextSelectedIds.difference(previousSelectedIds);
  return {
    for (final id in newlySelected)
      if (!fetchedIds.contains(id)) id,
  };
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

/// Missing chip selection → all enabled. Empty saved list is explicit none.
Set<String> resolveEngineSelectedPluginIds({
  required bool selectionSaved,
  required Iterable<String> savedIds,
  required Set<String> enabledIds,
  Set<String>? selectAllScopeIds,
}) {
  if (!selectionSaved) {
    final scope = selectAllScopeIds ?? enabledIds;
    return {
      for (final id in scope)
        if (enabledIds.contains(id)) id,
    };
  }
  return filterEngineSelectedPluginIds(
    savedIds: savedIds,
    enabledIds: enabledIds,
  );
}

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

/// Copies [extractCtx] into plugin [config] per manifest [EnginePlugin.ctxConfigMap].
Map<String, dynamic> injectExtractCtxIntoConfig(
  EnginePlugin plugin,
  Map<String, dynamic> extractCtx,
  Map<String, dynamic> config,
) {
  if (plugin.ctxConfigMap.isEmpty) return config;
  final out = Map<String, dynamic>.from(config);
  for (final entry in plugin.ctxConfigMap.entries) {
    final v = extractCtx[entry.value];
    if (v == null) continue;
    if (v is String && v.trim().isEmpty) continue;
    if (v is num && v <= 0) continue;
    out[entry.key] = v;
  }
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

  // Anime embeds: "Megaplay [MegaPlay] (SUB)" → MegaPlay (not the full blob).
  final bracket = RegExp(r'\[([^\]]+)\]').firstMatch(candidate);
  if (bracket != null) {
    final server = bracket.group(1)!.trim();
    if (server.isNotEmpty) {
      if (server.toLowerCase() == pluginName.toLowerCase()) {
        return pluginName;
      }
      return server;
    }
  }

  final stripped = candidate
      .replaceFirst(RegExp(r'\s*\((SUB|DUB)\)\s*$', caseSensitive: false), '')
      .trim();
  if (stripped.toLowerCase() == pluginName.toLowerCase()) {
    return pluginName;
  }

  // "VidRock Astra" → Astra (plugin name already known).
  final pluginPrefix = RegExp(
    '^${RegExp.escape(pluginName)}(?:\\s+[·•|]\\s*|\\s+)',
    caseSensitive: false,
  );
  final prefixed = pluginPrefix.firstMatch(stripped);
  if (prefixed != null) {
    final rest = stripped.substring(prefixed.end).trim();
    if (rest.isNotEmpty) {
      final server = rest.split(RegExp(r'\s*[·•]\s*')).first;
      if (_looksLikeEngineMirrorLabel(server)) return server;
      return pluginName;
    }
  }

  final cut = stripped.split(RegExp(r'\s*[·•|]\s*')).first.trim();
  if (cut.isEmpty || cut == stripped && stripped.length > 48) {
    return pluginName;
  }
  if (cut.toLowerCase() == pluginName.toLowerCase()) {
    return pluginName;
  }
  if (!_looksLikeEngineMirrorLabel(cut)) return pluginName;
  return cut;
}

/// Mirror chips are short (Yoru, Astra) — not media titles with years.
bool _looksLikeEngineMirrorLabel(String raw) {
  final t = raw.trim();
  if (t.isEmpty || t.length > 28) return false;
  if (RegExp(r'\(\d{4}\)').hasMatch(t)) return false;
  if (t.contains(' - ')) return false;
  if (RegExp(r'\bS\d+E\d+\b', caseSensitive: false).hasMatch(t)) return false;
  if (t.split(RegExp(r'\s+')).length > 2) return false;
  return true;
}

/// Hub play filter audio: `sub` | `dub`, else null.
String? normalizeEngineAudioCategory(String? raw) {
  final a = (raw ?? '').trim().toLowerCase();
  if (a == 'sub' || a == 'dub') return a;
  return null;
}

/// Stamp hub SUB/DUB into extract ctx (`ctx.category`) for providers.
void applyAudioCategoryToExtractCtx(
  Map<String, dynamic> extractCtx,
  String? audioCategory,
) {
  final cat = normalizeEngineAudioCategory(audioCategory);
  if (cat == null) return;
  extractCtx['category'] = cat;
}

/// `sub`, `dub`, or null when the row has no audio hint.
String? engineStreamAudioCategory(Map<String, dynamic> stream) {
  final lang = (stream['language'] ?? '').toString().trim().toLowerCase();
  if (lang == 'sub' || lang == 'dub') return lang;
  final blob = '${stream['name'] ?? ''} ${stream['title'] ?? ''}';
  if (RegExp(r'\(SUB\)', caseSensitive: false).hasMatch(blob)) return 'sub';
  if (RegExp(r'\(DUB\)', caseSensitive: false).hasMatch(blob)) return 'dub';
  return null;
}

bool engineStreamMatchesAudioCategory(
  Map<String, dynamic> stream,
  String category,
) {
  final want = normalizeEngineAudioCategory(category);
  if (want == null) return true;
  final have = engineStreamAudioCategory(stream);
  if (have == null) return true;
  return have == want;
}

/// Drop rows tagged for the other audio when hub SUB/DUB is set.
List<Map<String, dynamic>> filterStreamsByAudioCategory(
  List<Map<String, dynamic>> streams,
  String? audioCategory,
) {
  final want = normalizeEngineAudioCategory(audioCategory);
  if (want == null) return streams;
  return [
    for (final s in streams)
      if (engineStreamMatchesAudioCategory(s, want)) s,
  ];
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

String? engineContainerLabel({
  String? url,
  String? title,
  String? name,
}) {
  final blob = '${title ?? ''} ${name ?? ''} ${url ?? ''}'.toUpperCase();
  if (RegExp(r'(\.MKV\b|\bMKV\b)').hasMatch(blob)) return 'MKV';
  if (RegExp(r'(\.MP4\b|\bMP4\b)').hasMatch(blob)) return 'MP4';
  if (RegExp(r'(\.WEBM\b|\bWEBM\b)').hasMatch(blob)) return 'WebM';
  return null;
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
  final rawTitle = (raw['title'] ?? '').toString().trim();
  final rawName = (raw['name'] ?? '').toString().trim();
  final rawQuality = (raw['quality'] ?? '').toString();
  final quality =
      normalizeEngineQuality(rawQuality) ??
      engineQualityFromText('$rawTitle $rawName');
  final language =
      engineLanguageLabel((raw['language'] ?? '').toString()) ??
      engineLanguageLabel(rawQuality);
  final audio = () {
    final a = (raw['audio'] ?? '').toString().trim();
    return a.isEmpty ? null : a;
  }();
  final size = TorrentReleaseMetadata.resolveSizeLabel(
    sizeText: (raw['size'] ?? '').toString(),
    fallbackText: '$rawTitle $rawName',
  );
  final container = engineContainerLabel(
    url: url,
    title: rawTitle,
    name: rawName,
  );
  final displayTitle = engineMediaDisplayTitle(
    title: mediaTitle,
    year: year,
    type: type,
    season: season,
    episode: episode,
  );
  final server = engineServerLabel(
    pluginName: plugin.name,
    name: rawName,
    title: rawTitle,
  );
  final addonName = server == plugin.name
      ? plugin.name
      : '${plugin.name} · $server';
  // Keep card title clean (media SxE year). Stuff release filename / quality /
  // size / codec tokens into description so Sources badges can parse them —
  // same chip UI as Torrents, no Nuvio emoji rows.
  final descParts = <String>[
    if (rawTitle.isNotEmpty) rawTitle,
    ?quality,
    ?container,
    ?audio,
    ?language,
    ?size,
  ];
  final desc = descParts.join(' ').trim();
  final cardTitle = displayTitle.isNotEmpty
      ? displayTitle
      : (rawTitle.isNotEmpty
            ? rawTitle.split('\n').first.trim()
            : (rawName.isNotEmpty ? rawName : plugin.name));
  final needsSeekProxy =
      requiresProxy ||
      raw['requiresProxy'] == true ||
      raw['requires_proxy'] == true ||
      (Uri.tryParse(url)?.host.toLowerCase().contains('111477') ?? false);
  final typeHint = (raw['type'] ?? '').toString().trim();
  return {
    'url': url,
    'title': cardTitle,
    'name': addonName,
    if (typeHint.isNotEmpty) 'type': typeHint,
    if (desc.isNotEmpty) 'description': desc,
    'quality': ?quality,
    'language': ?language,
    'size': ?size,
    'container': ?container,
    if (headers.isNotEmpty) 'headers': headers,
    if (headers.isNotEmpty)
      'behaviorHints': {
        'notWebReady': true,
        'proxyHeaders': {'request': headers},
      },
    if (needsSeekProxy) 'requires_proxy': true,
    if (raw['subtitles'] is List && (raw['subtitles'] as List).isNotEmpty)
      'subtitles': raw['subtitles'],
    '_addonBaseUrl': 'engine:${plugin.id}',
    '_addonName': addonName,
    '_enginePluginId': plugin.id,
  };
}

/// One script/prelude fetch tick during [PluginRegistry.install].
class PluginScriptFetchProgress {
  const PluginScriptFetchProgress({
    required this.completed,
    required this.total,
    required this.label,
    required this.sourceUrl,
  });

  final int completed;
  final int total;
  final String label;
  final String sourceUrl;

  double get fraction =>
      total <= 0 ? 0 : (completed / total).clamp(0.0, 1.0);
}
