import 'models.dart';

/// Plugin `types` + structural buckets — all labels from manifest tokens, not
/// hardcoded pack names.
abstract final class EngineCategories {
  /// TMDB-shaped defaults for Home / feature details (not hub pack types).
  static const movie = 'movie';
  static const tv = 'tv';

  /// Live Matches plugin types (`engine.json`).
  static const liveCatalog = 'catalog';
  static const livePlugin = 'plugins';
  static const liveSport = 'live_sport';

  /// Shell hub plugins (`kind: catalog`) — Settings → Forja **Hubs** tab.
  static const hubCatalog = 'hubs';

  static const _structuralGroupKeys = {
    'movie_tv',
    movie,
    tv,
    livePlugin,
    liveCatalog,
    hubCatalog,
    'other',
  };

  static String typeLabel(String id) {
    switch (id) {
      case 'movie_tv':
        return 'Movie & TV';
      case movie:
        return 'Movie';
      case tv:
        return 'TV';
      case livePlugin:
        return 'Live';
      case liveCatalog:
        return 'Catalog';
      case hubCatalog:
        return 'Hubs';
      case 'other':
        return 'Other';
      default:
        return id
            .split('_')
            .where((w) => w.isNotEmpty)
            .map(
              (w) => w.length == 1
                  ? w.toUpperCase()
                  : '${w[0].toUpperCase()}${w.substring(1)}',
            )
            .join(' ');
    }
  }

  /// Unique VOD filter chips from installed extractable plugins' `types`.
  static List<String> filterTypesFromPlugins(Iterable<EnginePlugin> plugins) {
    final out = <String>{movie, tv};
    for (final p in plugins) {
      if (!p.isExtractable) continue;
      for (final raw in p.types) {
        final t = raw.toLowerCase().trim();
        if (t.isEmpty) continue;
        if (t == 'series') {
          out.add(tv);
        } else if (!_liveTypeTokens.contains(t)) {
          out.add(t);
        }
      }
    }
    final list = out.toList()..sort(_typeSortCompare);
    return list;
  }

  static const _liveTypeTokens = {
    liveCatalog,
    livePlugin,
    liveSport,
    'live',
  };

  static int _typeSortCompare(String a, String b) {
    const head = [movie, tv];
    final ai = head.indexOf(a);
    final bi = head.indexOf(b);
    if (ai >= 0 || bi >= 0) {
      if (ai < 0) return 1;
      if (bi < 0) return -1;
      return ai.compareTo(bi);
    }
    return a.compareTo(b);
  }

  /// Filter chip types: installed plugin types + [include] + [extra].
  static List<String> filterTypeOptions({
    required Iterable<EnginePlugin> plugins,
    Set<String> include = const {},
    List<String> extra = const [],
  }) {
    final out = filterTypesFromPlugins(plugins).toSet()
      ..addAll(include)
      ..addAll(extra);
    final list = out.toList()..sort(_typeSortCompare);
    return list;
  }

  /// Settings / pack grouping key (dual movie+tv → one bucket).
  static String groupKey(EnginePlugin plugin) {
    if (plugin.isHubCatalog) return hubCatalog;
    if (plugin.isLiveCatalog) return liveCatalog;
    if (plugin.isLivePlugin || plugin.isLiveSport || plugin.isLive) {
      return livePlugin;
    }
    final types = plugin.types.map((t) => t.toLowerCase()).toSet();
    if (types.contains(movie) && types.contains(tv)) return 'movie_tv';
    if (types.contains(tv) || types.contains('series')) return tv;
    if (types.contains(movie)) return movie;
    final vod = types.where((t) => t.isNotEmpty && t != 'series').toList()
      ..sort();
    if (vod.length == 1) return vod.first;
    if (vod.isNotEmpty) return vod.first;
    return 'other';
  }

  static String groupLabel(String key) => typeLabel(key);

  /// Structural order first, then manifest VOD types present in [plugins].
  static List<String> groupOrderFor(Iterable<EnginePlugin> plugins) {
    final keys = plugins.map(groupKey).toSet();
    const structural = [
      'movie_tv',
      movie,
      tv,
      livePlugin,
      liveCatalog,
      hubCatalog,
    ];
    final out = [for (final k in structural) if (keys.contains(k)) k];
    final dynamicKeys = keys
        .where((k) => !_structuralGroupKeys.contains(k))
        .toList()
      ..sort();
    out.addAll(dynamicKeys);
    if (keys.contains('other')) out.add('other');
    return out;
  }

  static String liveSourceGroupKey(EnginePlugin plugin) {
    if (plugin.isLiveCatalog) return liveCatalog;
    return livePlugin;
  }

  static String liveSourceGroupLabel(String key) => switch (key) {
    livePlugin => 'Plugins',
    liveCatalog => 'Catalog',
    _ => 'Other',
  };

  static const liveSourceGroupOrder = [livePlugin];

  static Set<String> defaultsForMediaType(String? mediaType) =>
      {panelCategoryFor(mediaType: mediaType)};

  /// Panel bucket — explicit [panelCategory] from pack extract wins; else TMDB
  /// movie/tv only (host does not map hub media types).
  static String panelCategoryFor({
    String? mediaType,
    String? panelCategory,
  }) {
    final explicit = panelCategory?.toLowerCase().trim();
    if (explicit != null && explicit.isNotEmpty) {
      if (explicit == 'series') return tv;
      return explicit;
    }
    final t = (mediaType ?? '').toLowerCase().trim();
    if (t == 'tv' || t == 'series' || t == 'show') return tv;
    return movie;
  }

  static Set<String> defaultsForPanelCategory(String category) =>
      {panelCategoryFor(panelCategory: category)};

  /// Single-type VOD plugins → that type. Dual movie/TV (+ drama, …) → null.
  static String? panelCategoryFromPlayingPlugin(EnginePlugin plugin) {
    final types = plugin.types
        .map((t) => t.toLowerCase().trim())
        .where((t) => t.isNotEmpty)
        .toSet();
    final hasMovieTv =
        types.contains(movie) ||
        types.contains(tv) ||
        types.contains('series');
    if (hasMovieTv) return null;
    if (types.length == 1) return types.first;
    final sorted = types.toList()..sort();
    return sorted.isEmpty ? null : sorted.first;
  }

  static bool pluginMatchesCategories(
    EnginePlugin plugin,
    Set<String> categories,
  ) {
    if (categories.isEmpty) return true;
    for (final raw in plugin.types) {
      final t = raw.toLowerCase();
      if (categories.contains(t)) return true;
      if (t == 'series' && categories.contains(tv)) return true;
    }
    return false;
  }

  static bool pluginChipVisible({
    required EnginePlugin plugin,
    required Set<String> visibleCategories,
    required Set<String> selectedPluginIds,
  }) {
    if (!plugin.enabled || !plugin.isExtractable) return false;
    if (selectedPluginIds.contains(plugin.id)) return true;
    return pluginMatchesCategories(plugin, visibleCategories);
  }

  static int extraCategoryFilterCount({
    required Set<String> visibleCategories,
    String? mediaType,
  }) {
    final defaults = defaultsForPanelCategory(
      panelCategoryFor(mediaType: mediaType, panelCategory: mediaType),
    );
    return visibleCategories.difference(defaults).length +
        defaults.difference(visibleCategories).length;
  }

  static Set<String> matchingPluginIds({
    required List<EnginePack> packs,
    required Set<String> categories,
  }) => {
    for (final pack in packs)
      if (pack.enabled)
        for (final p in pack.plugins)
          if (p.enabled &&
              p.isHttp &&
              pluginMatchesCategories(p, categories))
            p.id,
  };

  static Set<String> scopeSelectionIfFullAll({
    required Set<String> selected,
    required Set<String> enabledIds,
    required Set<String> scope,
  }) {
    if (enabledIds.isEmpty) return {};
    final fullAll =
        selected.length == enabledIds.length &&
        enabledIds.every(selected.contains);
    if (!fullAll) return selected;
    return {for (final id in scope) if (enabledIds.contains(id)) id};
  }
}
