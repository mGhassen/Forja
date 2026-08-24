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
        container.invalidate(animeCatalogFuturesProvider);
        container.invalidate(animeMoodCatalogProvider(_s._selectedMood));
        _s._appliedCatalog = null;
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

      // Green Forja Play when Auto is on — same as details, not AnimePlayerScreen.
      if (await hubEngineAutoPlayEnabled()) {
        if (!mounted) return;
        final isMovie = (anime.format ?? '').toUpperCase() == 'MOVIE';
        final malId = await _s._service.resolveMalId(animeId);
        if (!mounted) return;
        await runHubEngineAutoPlay(
          context: context,
          movie: Movie(
            id: -anime.id,
            title: anime.displayTitle,
            posterPath: anime.coverUrl,
            backdropPath: anime.heroBackdrop,
            voteAverage: (anime.averageScore ?? 0) / 10.0,
            releaseDate: anime.seasonYear?.toString() ?? '',
            overview: anime.cleanDescription,
            genres: anime.genres,
            runtime: anime.duration ?? 0,
            mediaType: 'anime',
            numberOfEpisodes: anime.episodes ?? 0,
          ),
          engineCategory: 'anime',
          season: isMovie ? null : 1,
          episode: isMovie ? null : epNum,
          anilistId: animeId,
          malId: malId,
          startPosition: startPosition,
          loadingSubtitle: 'EP $epNum',
          hubEpisodes: isMovie
              ? null
              : [
                  for (final e in episodes)
                    PlayerHubEpisode(
                      number: e.number,
                      title: e.title,
                      notShippedYet: !e.aired,
                    ),
                ],
        );
        if (mounted) await _refreshHistory();
        return;
      }

      await openAnimePlayer(
        context,
        anime: anime,
        episodeNumber: epNum,
        category: cat,
        allEpisodes: episodes,
        startPosition: startPosition,
        freshResolve: true,
      );
      if (mounted) await _refreshHistory();
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
