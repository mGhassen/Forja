part of 'anime_screen.dart';

mixin _AnimeScreenFeed on State<AnimeScreen> {
  _AnimeScreenState get _s => this as _AnimeScreenState;

  void _onHistoryChanged() => _refreshHistory();

  /// Reload only the Continue Watching list — cheap, no API hits other
  /// than SharedPreferences. Called on init, catalog refresh, app resume,
  /// on history mutation, and after returning from player/details.
  Future<void> _refreshHistory() async {
    try {
      final list = await _s._service.getWatchHistory();
      if (!mounted) return;
      setState(() {
        _s._continueWatching = list.take(10).toList();
        _s._historyResolved = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _s._historyResolved = true);
    }
  }

  void _onTheme() {
    if (mounted) setState(() {});
  }

  Future<List<AnimeCard>> _safeSection(
    Future<List<AnimeCard>> future,
    String name,
  ) async {
    try {
      return await future;
    } catch (e) {
      debugPrint('[AnimeScreen] $name load failed: $e');
      return const [];
    }
  }

  /// Spotlight / Top 10 / Trending share one AniList TRENDING_DESC page.
  List<AnimeCard> _spotlightFromTrending(List<AnimeCard> trending) {
    final filtered = trending.where((a) {
      final s = (a.status ?? '').toUpperCase();
      return s.isEmpty || s == 'RELEASING' || s == 'FINISHED';
    }).take(10).toList();
    if (filtered.isNotEmpty) return filtered;
    return trending.take(10).toList();
  }

  /// Hero paints AniList art immediately; TMDB backdrops swap in later.
  Future<void> _enrichSpotlightTmdb(
    int gen,
    Future<List<AnimeCard>> spotlightFuture,
  ) async {
    try {
      final list = await spotlightFuture;
      if (!mounted || gen != _s._loadGen || list.isEmpty) return;
      final head = list.take(5).toList();
      final enrichedHead = await _s._service.attachTmdbBackdrops(head);
      if (!mounted || gen != _s._loadGen) return;
      final byId = {for (final c in enrichedHead) c.id: c};
      final merged = [
        for (final c in list) byId[c.id] ?? c,
      ];
      setState(() => _s._spotlightFuture = Future.value(merged));
    } catch (e) {
      debugPrint('[AnimeScreen] spotlight TMDB enrich failed: $e');
    }
  }

  Future<void> _load() async {
    final gen = ++_s._loadGen;
    unawaited(_refreshHistory());

    // One TRENDING_DESC query → spotlight / top10 / trending (was 3).
    final trendingBase =
        _safeSection(_s._service.getTrending(perPage: 20), 'trending');
    final spotlightFuture =
        trendingBase.then(_spotlightFromTrending);
    final top10Future = trendingBase.then((list) => list.take(10).toList());
    final trendingFuture = trendingBase;

    final topAiringFuture = _safeSection(_s._service.getTopAiring(), 'top airing');
    final mostPopularFuture =
        _safeSection(_s._service.getMostPopular(), 'most popular');
    final mostFavoriteFuture =
        _safeSection(_s._service.getMostFavorite(), 'most favorite');
    final topRatedFuture = _safeSection(_s._service.getTopRated(), 'top rated');
    final latestCompletedFuture =
        _safeSection(_s._service.getLatestCompleted(), 'latest completed');
    final recentEpisodesFuture =
        _safeSection(_s._service.getRecentEpisodes(), 'recent episodes');
    final moodFuture = _loadMood(_s._selectedMood);

    setState(() {
      _s._error = null;
      _s._catalogResolved = false;
      _s._spotlightFuture = spotlightFuture;
      _s._trendingFuture = trendingFuture;
      _s._topAiringFuture = topAiringFuture;
      _s._mostPopularFuture = mostPopularFuture;
      _s._mostFavoriteFuture = mostFavoriteFuture;
      _s._topRatedFuture = topRatedFuture;
      _s._latestCompletedFuture = latestCompletedFuture;
      _s._top10Future = top10Future;
      _s._recentEpisodesFuture = recentEpisodesFuture;
      _s._moodFuture = moodFuture;
    });

    unawaited(_enrichSpotlightTmdb(gen, spotlightFuture));

    final results = await Future.wait([
      spotlightFuture,
      trendingFuture,
      topAiringFuture,
      mostPopularFuture,
      mostFavoriteFuture,
      topRatedFuture,
      latestCompletedFuture,
      top10Future,
      recentEpisodesFuture,
    ]);
    if (!mounted || gen != _s._loadGen) return;

    final hasCatalog = results
        .cast<List<AnimeCard>>()
        .any((section) => section.isNotEmpty);

    setState(() {
      _s._catalogResolved = true;
      _s._error =
          hasCatalog ? null : 'Failed to load anime — check your connection';
    });
    if (hasCatalog) (this as ShellTabRefresh<AnimeScreen>).markShellTabFresh();
  }

  Future<List<AnimeCard>> _loadMood(String id) async {
    try {
      final mood = _AnimeScreenState._moods.firstWhere((m) => m.id == id, orElse: () => _AnimeScreenState._moods[0]);
      return await _s._service.browse(
        genre: mood.genre,
        sort: 'TRENDING_DESC',
        perPage: 20,
      );
    } catch (e) {
      debugPrint('[AnimeScreen] mood load failed: $e');
      return const [];
    }
  }

  void _selectMood(String id) {
    if (id == _s._selectedMood) return;
    setState(() {
      _s._selectedMood = id;
      _s._moodFuture = _loadMood(id);
    });
  }

  void _openDetails(AnimeCard a) {
    openAnimeDetails(context, a).then((_) {
      _refreshHistory();
      unawaited((this as ShellTabRefresh<AnimeScreen>).refreshIfStale(force: _s._error != null));
    });
  }

  void _openSearch() {
    pushShellRoute(
      context,
      AppRouter.slideShellRoute(
        (_) => const AnimeSearchScreen(),
        settings: const RouteSettings(name: 'anime_search'),
      ),
    );
  }

  Future<void> _resumeWatch(Map<String, dynamic> entry) async {
    final animeId = entry['animeId'] as int?;
    if (animeId == null || _s._resumingAnimeId != null) return;

    setState(() => _s._resumingAnimeId = animeId);
    try {
      final epNum = (entry['episodeNumber'] as num?)?.toInt() ?? 1;
      final cat = (entry['category'] as String?) ?? 'sub';
      final posMs = (entry['positionMs'] as num?)?.toInt() ?? 0;
      final durMs = (entry['durationMs'] as num?)?.toInt() ?? 0;
      Duration? startPosition;
      // Same as movies: ≥90% finished → restart at 0 (not near-credits).
      if (posMs > 5000 && isInProgressResume(posMs, durMs)) {
        final clamped = (durMs > 0 && posMs > durMs - 30000)
            ? (durMs - 30000)
            : posMs;
        startPosition =
            Duration(milliseconds: (clamped - 3000).clamp(0, 1 << 31));
      }

      // Same launch contract as details → Resume (fresh title + episode list).
      final anime = await _s._service.getDetails(animeId);
      if (!mounted) return;
      final episodes = await _s._service.getEpisodes(anime);
      if (!mounted) return;

      openAnimePlayer(
        context,
        anime: anime,
        episodeNumber: epNum,
        category: cat,
        allEpisodes: episodes,
        startPosition: startPosition,
        freshResolve: true,
      ).then((_) => _refreshHistory());
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('Resume failed: $e');
    } finally {
      if (mounted) setState(() => _s._resumingAnimeId = null);
    }
  }

  Future<void> _removeFromHistory(Map<String, dynamic> entry) async {
    final animeId = entry['animeId'] as int?;
    if (animeId == null) return;
    await _s._service.removeFromHistory(animeId);
    if (!mounted) return;
    setState(() {
      _s._continueWatching.removeWhere((e) => e['animeId'] == animeId);
    });
  }
}
