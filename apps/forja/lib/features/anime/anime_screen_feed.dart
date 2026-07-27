part of 'anime_screen.dart';

mixin _AnimeScreenFeed on ConsumerState<AnimeScreen>, ShellTabRefresh<AnimeScreen> {
  _AnimeScreenState get _s => this as _AnimeScreenState;

  void _onHistoryChanged() => _refreshHistory();

  /// Reload only the Continue Watching list - cheap, no API hits other
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
      if (!mounted || !shellTabVisible || gen != _s._loadGen || list.isEmpty) {
        return;
      }
      final head = list.take(5).toList();
      final enrichedHead = await _s._service.attachTmdbBackdrops(head);
      if (!mounted || !shellTabVisible || gen != _s._loadGen) return;
      final byId = {for (final c in enrichedHead) c.id: c};
      final merged = [
        for (final c in list) byId[c.id] ?? c,
      ];
      setState(() {
        _s._spotlightFuture = Future.value(merged);
      });
    } catch (e) {
      debugPrint('[AnimeScreen] spotlight TMDB enrich failed: $e');
    }
  }

  Future<void> _load() async {
    if (!mounted || !shellTabVisible) return;
    final container = _s._container;
    // Visibility keep-alive can leave State.mounted true while the element is
    // deactivated — never fall back to ProviderScope.containerOf here.
    if (container == null) return;
    final gen = ++_s._loadGen;
    unawaited(_refreshHistory());
    final done = Completer<void>();
    // Shell show/refresh runs in a post-frame callback; the keep-alive element
    // may still be inactive in that window. Defer so setState is safe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (!mounted || !shellTabVisible || gen != _s._loadGen) return;
        setState(() {
          _s._error = null;
          _s._catalogResolved = false;
        });
        container.invalidate(animeCatalogProvider);
        container.invalidate(animeMoodCatalogProvider(_s._selectedMood));
      } finally {
        if (!done.isCompleted) done.complete();
      }
    });
    return done.future;
  }

  void _selectMood(String id) {
    if (id == _s._selectedMood) return;
    setState(() => _s._selectedMood = id);
    final container = _s._container;
    if (container == null) return;
    container.invalidate(animeMoodCatalogProvider(id));
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
