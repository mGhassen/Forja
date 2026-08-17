class EnginePlugin {
  EnginePlugin({
    required this.id,
    required this.name,
    required this.entry,
    this.description,
    this.types = const ['movie', 'tv'],
    this.kind = 'http',
    this.enabled = true,
  });

  final String id;
  final String name;
  final String entry;
  final String? description;
  final List<String> types;
  final String kind;
  final bool enabled;

  bool get isHttp => kind == 'http';

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
      entry: (j['entry'] as String?)?.trim() ??
          (j['filename'] as String?)?.trim() ??
          '',
      description: (j['description'] as String?)?.trim(),
      types: ((j['types'] as List?) ??
              (j['supportedTypes'] as List?) ??
              const ['movie', 'tv'])
          .map((e) => e.toString())
          .toList(),
      kind: (j['kind'] as String?)?.trim().isNotEmpty == true
          ? (j['kind'] as String).trim()
          : 'http',
      enabled: (j['enabled'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'entry': entry,
        if (description != null) 'description': description,
        'types': types,
        'kind': kind,
        'enabled': enabled,
      };

  EnginePlugin copyWith({bool? enabled}) => EnginePlugin(
        id: id,
        name: name,
        entry: entry,
        description: description,
        types: types,
        kind: kind,
        enabled: enabled ?? this.enabled,
      );
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
          if (raw is Map)
            EnginePlugin.fromJson(Map<String, dynamic>.from(raw)),
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
            if (raw is Map)
              EnginePlugin.fromJson(Map<String, dynamic>.from(raw)),
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

Set<String> nextEngineSelectedAfterAllTap({
  required Set<String> selectedIds,
  required Set<String> enabledIds,
}) {
  if (enabledIds.isEmpty) return {};
  final allOn = enabledIds.every(selectedIds.contains);
  return allOn ? <String>{} : Set<String>.from(enabledIds);
}

Set<String> filterEngineSelectedPluginIds({
  required Iterable<String> savedIds,
  required Set<String> enabledIds,
}) =>
    {
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
