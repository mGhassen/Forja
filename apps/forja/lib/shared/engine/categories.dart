import 'models.dart';

/// Forja plugin categories from `engine.json` `types`.
///
/// Soft visibility only — selected off-category plugins still extract.
abstract final class EngineCategories {
  static const movie = 'movie';
  static const tv = 'tv';
  static const anime = 'anime';
  static const drama = 'drama';

  /// Live Matches plugin types (`engine.json`).
  static const liveCatalog = 'catalog';
  static const livePlugin = 'plugins';
  static const liveSport = 'live_sport';

  static const all = [movie, tv, anime, drama];

  static String label(String id) => switch (id) {
    movie => 'Movie',
    tv => 'TV',
    anime => 'Anime',
    drama => 'Drama',
    _ => id,
  };

  /// Settings / pack grouping key (dual movie+tv → one bucket).
  static String groupKey(EnginePlugin plugin) {
    final types = plugin.types.map((t) => t.toLowerCase()).toSet();
    if (types.contains(anime)) return anime;
    if (types.contains(drama)) return drama;
    if (types.contains(movie) && types.contains(tv)) return 'movie_tv';
    if (types.contains(tv) || types.contains('series')) return tv;
    if (types.contains(movie)) return movie;
    return 'other';
  }

  static String groupLabel(String key) => switch (key) {
    'movie_tv' => 'Movie & TV',
    movie => 'Movie',
    tv => 'TV',
    anime => 'Anime',
    drama => 'Drama',
    _ => 'Other',
  };

  static const groupOrder = ['movie_tv', movie, tv, anime, drama, 'other'];

  /// Live Matches source plugins (resolve + schedule) — one Settings bucket.
  /// Catalog plugins are listed separately under Settings → Catalog.
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

  /// Default visible categories for the current details media type.
  static Set<String> defaultsForMediaType(String? mediaType) =>
      {panelCategoryFor(mediaType: mediaType)};

  /// Panel bucket for soft-hide + selection prefs: movie | tv | anime | drama.
  ///
  /// Hubs pass [panelCategory] explicitly — TMDB `movie`/`tv` alone is not enough
  /// (anime/drama catalog Sources still use a TMDB Movie).
  static String panelCategoryFor({
    String? mediaType,
    String? panelCategory,
    bool hasAnimeIds = false,
  }) {
    final explicit = panelCategory?.toLowerCase().trim();
    if (explicit != null && explicit.isNotEmpty) {
      if (explicit == 'series') return tv;
      if (explicit == 'asian' || explicit == 'asian_drama') return drama;
      if (all.contains(explicit)) return explicit;
    }
    final t = (mediaType ?? '').toLowerCase().trim();
    if (t == anime || hasAnimeIds) return anime;
    if (t == drama || t == 'asian' || t == 'asian_drama') return drama;
    if (t == 'tv' || t == 'series' || t == 'show') return tv;
    return movie;
  }

  static Set<String> defaultsForPanelCategory(String category) =>
      {panelCategoryFor(panelCategory: category)};

  /// Infer anime/drama panel bucket from the playing `engine:` plugin.
  ///
  /// Dual movie/TV plugins that also list `drama` (Videasy, VidLink, …) must
  /// fall through so TMDB movie/TV Sources keep the full chip row.
  static String? panelCategoryFromPlayingPlugin(EnginePlugin plugin) {
    final types = plugin.types.map((t) => t.toLowerCase()).toSet();
    final hasMovieTv =
        types.contains(movie) ||
        types.contains(tv) ||
        types.contains('series');
    if (types.contains(anime) && !hasMovieTv) return anime;
    if (types.contains(drama) && !hasMovieTv) return drama;
    return null;
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

  /// Chips to show: matching category, or already selected (so they stay usable).
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
    required String? mediaType,
  }) {
    final defaults = defaultsForPanelCategory(
      panelCategoryFor(mediaType: mediaType, panelCategory: mediaType),
    );
    return visibleCategories.difference(defaults).length +
        defaults.difference(visibleCategories).length;
  }

  /// Enabled HTTP plugin ids whose `types` intersect [categories].
  static Set<String> matchingPluginIds({
    required List<EnginePack> packs,
    required Set<String> categories,
  }) => {
    for (final pack in packs)
      for (final p in pack.plugins)
        if (p.enabled &&
            p.isHttp &&
            pluginMatchesCategories(p, categories))
          p.id,
  };

  /// Legacy prefs / Select All that picked every enabled plugin → narrow to [scope].
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
