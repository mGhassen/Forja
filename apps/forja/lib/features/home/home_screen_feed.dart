part of 'home_screen.dart';

mixin _HomeScreenFeed on ConsumerState<HomeScreen>, ShellTabRefresh<HomeScreen> {
  _HomeScreenState get _s => this as _HomeScreenState;

  Future<List<Movie>> _fetchCategoryRow(
    ({String id, String label, List<int> movieGenres, List<int> tvGenres})
        category,
  ) {
    final providerId = _s._watchProviderId;
    final globalGenres = _s._genreIds;
    final movieGenres = globalGenres.movie ?? category.movieGenres;
    final tvGenres = globalGenres.tv ?? category.tvGenres;
    return _fetchMediaFiltered(
      movieFetch: () => _s._api.discoverMovies(
        genres: movieGenres,
        watchProviderId: providerId,
      ),
      tvFetch: () => _s._api.discoverTvShows(
        genres: tvGenres,
        watchProviderId: providerId,
      ),
    );
  }

  void _resetRandomCategoryRows() {
    final selectedGenreId = ShellBus.homeSelectedGenreId.value;
    final List<
        ({
          String id,
          String label,
          List<int> movieGenres,
          List<int> tvGenres,
        })> picked;
    if (selectedGenreId != null) {
      picked = homeGenreCategories
          .where((category) => category.id == selectedGenreId)
          .toList();
    } else {
      final pool = List.of(homeGenreCategories)..shuffle(math.Random());
      picked = pool.take(3).toList();
    }
    _s._randomCategoryRows = [
      for (final category in picked)
        (
          id: category.id,
          label: category.label,
          future: _fetchCategoryRow(category),
        ),
    ];
  }

  List<Movie> _enforceMediaFilter(List<Movie> items) {
    final filter = _s._mediaFilter;
    if (filter == ShellHomeCategory.films) {
      return items.where((movie) => movie.mediaType != 'tv').toList();
    }
    if (filter == ShellHomeCategory.tvShows) {
      return items.where((movie) => movie.mediaType == 'tv').toList();
    }
    return items;
  }

  Future<List<Movie>> _fetchMediaFiltered({
    required Future<List<Movie>> Function() movieFetch,
    required Future<List<Movie>> Function() tvFetch,
    List<Movie>? movieCache,
    void Function(List<Movie> movies)? onLoaded,
  }) {
    final filter = _s._mediaFilter;
    if (filter == ShellHomeCategory.films) {
      if (movieCache != null) {
        final movies = _enforceMediaFilter(movieCache);
        onLoaded?.call(movies);
        return Future.value(movies);
      }
      return movieFetch()
          .then((movies) {
            final filtered = _enforceMediaFilter(movies);
            onLoaded?.call(filtered);
            return filtered;
          })
          .catchError((_) => <Movie>[]);
    }
    if (filter == ShellHomeCategory.tvShows) {
      return tvFetch()
          .then((movies) {
            final filtered = _enforceMediaFilter(movies);
            onLoaded?.call(filtered);
            return filtered;
          })
          .catchError((_) => <Movie>[]);
    }
    return _fetchMixed(
      movieFetch,
      tvFetch,
      movieCache: movieCache,
      onLoaded: onLoaded,
    );
  }

  List<Movie> _interleaveMedia(List<Movie> movies, List<Movie> tv) {
    final out = <Movie>[];
    final seen = <String>{};
    void add(Movie m) {
      final key = '${m.mediaType}:${m.id}';
      if (seen.add(key)) out.add(m);
    }
    final maxLen = math.max(movies.length, tv.length);
    for (var i = 0; i < maxLen; i++) {
      if (i < movies.length) add(movies[i]);
      if (i < tv.length) add(tv[i]);
    }
    return out;
  }

  Future<List<Movie>> _fetchMixed(
    Future<List<Movie>> Function() movieFetch,
    Future<List<Movie>> Function() tvFetch, {
    List<Movie>? movieCache,
    void Function(List<Movie> movies)? onLoaded,
  }) {
    Future<List<Movie>> safeTv() =>
        tvFetch().catchError((_) => <Movie>[]);

    if (movieCache != null) {
      return safeTv().then((tv) {
        final merged = _interleaveMedia(movieCache, tv);
        onLoaded?.call(merged);
        return merged;
      });
    }
    final safeMovie = movieFetch().catchError((_) => <Movie>[]);
    return Future.wait([safeMovie, safeTv()]).then((results) {
      final merged = _interleaveMedia(results[0], results[1]);
      onLoaded?.call(merged);
      return merged;
    });
  }

  void _resetHomeCategoryFeeds() {
    _s._homeFeedEpoch++;
    _s._moodFuture = _loadMoodMovies(_s._selectedMood);
    _resetRandomCategoryRows();
  }

  Future<void> _reloadHomeFeed() async {
    if (!mounted) return;
    refreshHomeFeed(ref);
    ref.invalidate(homeTraktRecommendationsProvider);
    ref.invalidate(homeTraktUpcomingShowsProvider);
    ref.invalidate(homeTraktUpcomingMoviesProvider);
    setState(() => _resetHomeCategoryFeeds());
    // Re-roll "Because you watched" on every Home refresh.
    _pickBecauseSeed(WatchHistoryService().current);
  }

  void _onWatchProviderChanged() {
    if (!mounted || !shellTabVisible) return;
    setState(() => _resetHomeCategoryFeeds());
  }

  void _onHomeCategoryChanged() {
    if (!mounted || !shellTabVisible) return;
    setState(() => _resetHomeCategoryFeeds());
  }

  void _onHomeGenreChanged() {
    if (!mounted || !shellTabVisible) return;
    setState(() => _resetHomeCategoryFeeds());
  }

  /// Stop Home-scoped network work while another shell tab is selected.
  /// Keep-alive leaves [mounted] true — generation bumps abort in-flight loops.
  void _pauseHomeBackgroundWork() {
    _s._homeBgWorkGen++;
    _s._historySeedSub?.cancel();
    _s._historySeedSub = null;
    if (_s._splashDismissedListener != null) {
      ShellBus.splashDismissed.removeListener(_s._splashDismissedListener!);
      _s._splashDismissedListener = null;
    }
  }

  void _resumeHomeBackgroundWorkIfNeeded() {
    if (!mounted || !shellTabVisible) return;
    // Post-splash personalization never started (left before splash / delay).
    if (!_s._postSplashWorkStarted) {
      _schedulePostSplashWork();
      return;
    }
    // Because-you-watched still empty after a mid-fetch hide.
    if (_s._becauseSeed == null || _s._becauseFuture == null) {
      _initBecauseYouWatched();
    }
  }

  void _schedulePostSplashWork() {
    void run() {
      if (!mounted || !shellTabVisible) return;
      _s._postSplashWorkStarted = true;
      // Account-level sync — OK to continue if user leaves Home mid-flight.
      TraktService().fullSync();
      SimklService().fullSync();
      _loadTraktRecommendations();
      _loadTraktCalendar();
      _loadTraktCalendarMovies();
      _initBecauseYouWatched();
    }

    void schedule() {
      final gen = _s._homeBgWorkGen;
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (!mounted || !shellTabVisible || gen != _s._homeBgWorkGen) return;
        run();
      });
    }

    if (ShellBus.splashDismissed.value) {
      schedule();
      return;
    }

    _s._splashDismissedListener = () {
      if (!ShellBus.splashDismissed.value) return;
      ShellBus.splashDismissed.removeListener(_s._splashDismissedListener!);
      _s._splashDismissedListener = null;
      if (!mounted || !shellTabVisible) return;
      schedule();
    };
    ShellBus.splashDismissed.addListener(_s._splashDismissedListener!);
  }

  void _initBecauseYouWatched() {
    if (!mounted || !shellTabVisible) return;
    final svc = WatchHistoryService();
    if (!_pickBecauseSeed(svc.current)) {
      _s._historySeedSub?.cancel();
      _s._historySeedSub = svc.historyStream.listen((items) {
        if (!mounted || !shellTabVisible) return;
        if (_pickBecauseSeed(items)) {
          _s._historySeedSub?.cancel();
          _s._historySeedSub = null;
        }
      });
    }
  }

  /// Returns in-progress continue-watching items (2–90%), one per tmdbId.
  List<Map<String, dynamic>> _inProgressPool(List<Map<String, dynamic>> history) {
    return inProgressPoolByShow(history);
  }

  String _seedMediaType(Map<String, dynamic> seed) {
    final mediaType = (seed['mediaType'] as String?) ??
        (seed['season'] != null ? 'tv' : 'movie');
    return mediaType == 'tv' || mediaType == 'series' ? 'tv' : 'movie';
  }

  Map<String, dynamic>? _pickOppositeSeed(
    List<Map<String, dynamic>> pool,
    Map<String, dynamic> primary,
  ) {
    final wantOpposite = _seedMediaType(primary) == 'tv' ? 'movie' : 'tv';
    final candidates =
        pool.where((s) => _seedMediaType(s) == wantOpposite).toList();
    if (candidates.isEmpty) return null;
    return candidates[math.Random().nextInt(candidates.length)];
  }

  /// Returns true if a seed was successfully picked. Filters to in-progress
  /// items (between 2% and 90% watched) and picks one at random.
  /// When the pool has more than one title, avoids repeating the current seed.
  bool _pickBecauseSeed(List<Map<String, dynamic>> history) {
    if (!mounted || !shellTabVisible || history.isEmpty) return false;
    final pool = _inProgressPool(history);
    if (pool.isEmpty) return false;

    var candidates = pool;
    final currentKey = _becauseSeedKey(_s._becauseSeed);
    if (currentKey != null && pool.length > 1) {
      final others = pool
          .where((s) => _becauseSeedKey(s) != currentKey)
          .toList();
      if (others.isNotEmpty) candidates = others;
    }

    final seed = candidates[math.Random().nextInt(candidates.length)];
    final secondary = _pickOppositeSeed(pool, seed);
    final workGen = _s._homeBgWorkGen;
    setState(() {
      _s._becauseSeed = seed;
      _s._becausePoolSize = pool.length;
      _s._becauseFuture = _loadBecauseRecsMixed(seed, secondary, workGen);
    });
    return true;
  }

  Object? _becauseSeedKey(Map<String, dynamic>? seed) {
    if (seed == null) return null;
    return seed['uniqueId'] ?? seed['tmdbId'];
  }

  Future<List<Movie>> _loadBecauseRecsMixed(
    Map<String, dynamic> primary,
    Map<String, dynamic>? secondary,
    int workGen,
  ) async {
    if (secondary == null) return _loadBecauseRecs(primary, workGen);
    final results = await Future.wait([
      _loadBecauseRecs(primary, workGen),
      _loadBecauseRecs(secondary, workGen),
    ]);
    if (!mounted || workGen != _s._homeBgWorkGen) return const [];
    return _interleaveMedia(results[0], results[1]);
  }

  Future<List<Movie>> _loadBecauseRecs(
    Map<String, dynamic> seed,
    int workGen,
  ) async {
    final title = (seed['title'] as String?)?.trim();
    if (title == null || title.isEmpty) {
      debugPrint('[BecauseYouWatched] no title in seed');
      return const [];
    }
    final mediaType = (seed['mediaType'] as String?) ??
        (seed['season'] != null ? 'tv' : 'movie');
    final isTv = mediaType == 'tv' || mediaType == 'series';
    final wantType = isTv ? 'tv' : 'movie';
    debugPrint('[BecauseYouWatched] seed="$title" isTv=$isTv');

    try {
      // 1) Autocomplete on bestsimilar; pick the closest hit (forgiving).
      final hits = await BestSimilarScraper.autocomplete(title);
      if (!mounted || workGen != _s._homeBgWorkGen) return const [];
      debugPrint('[BecauseYouWatched] autocomplete hits=${hits.length}');
      if (hits.isEmpty) return const [];

      final lowerTitle = title.toLowerCase();
      BSAutocompleteHit? hit;
      // Prefer same-type exact title match.
      for (final h in hits) {
        if (h.isTv == isTv && h.title.toLowerCase() == lowerTitle) {
          hit = h; break;
        }
      }
      // Then any exact title match.
      hit ??= hits.firstWhere(
        (h) => h.title.toLowerCase() == lowerTitle,
        orElse: () => hits.first,
      );
      debugPrint('[BecauseYouWatched] picked hit id=${hit.id} title="${hit.title}"');

      // 2) Detail page → similar items.
      final details =
          await BestSimilarScraper.fetchDetails(id: hit.id, slug: hit.slug);
      if (!mounted || workGen != _s._homeBgWorkGen) return const [];
      if (details == null || details.similar.isEmpty) {
        debugPrint('[BecauseYouWatched] no similar items returned');
        return const [];
      }
      debugPrint('[BecauseYouWatched] bestsimilar similar=${details.similar.length}');

      // 3) Resolve each BS item to a TMDB Movie (parallel) - relaxed threshold
      //    so we don't drop everything when the year is unknown.
      final lookups = details.similar.map((it) async {
        if (workGen != _s._homeBgWorkGen) return null;
        try {
          final hits = await _s._api.searchMulti(it.title);
          if (workGen != _s._homeBgWorkGen) return null;
          if (hits.isEmpty) return null;
          Movie? best;
          var bestScore = -1;
          for (final h in hits) {
            var s = 0;
            final ht = h.title.toLowerCase();
            final it2 = it.title.toLowerCase();
            if (ht == it2) {
              s += 5;
            } else if (ht.startsWith(it2) || it2.startsWith(ht)) {
              s += 2;
            }
            if (h.mediaType == wantType) s += 3;
            if (it.year != null && h.releaseDate.length >= 4) {
              final hy = int.tryParse(h.releaseDate.substring(0, 4));
              if (hy == it.year) {
                s += 4;
              } else if (hy != null && (hy - it.year!).abs() <= 1) {
                s += 1;
              }
            }
            if (h.posterPath.isNotEmpty) s += 1;
            if (s > bestScore) {
              bestScore = s;
              best = h;
            }
          }
          if (best == null || bestScore < 2) return null;
          if (best.posterPath.isEmpty) return null;
          return MapEntry(it.similarityPercent ?? -1, best);
        } catch (_) {
          return null;
        }
      });
      final resolved = await Future.wait(lookups);
      if (!mounted || workGen != _s._homeBgWorkGen) return const [];

      // 4) Sort by bestsimilar similarity % (desc), drop dupes & nulls.
      //    Items without a percentage fall to the bottom.
      final ranked = resolved.whereType<MapEntry<int, Movie>>().toList()
        ..sort((a, b) => b.key.compareTo(a.key));
      final out = <Movie>[];
      final seen = <String>{};
      for (final e in ranked) {
        final key = '${e.value.mediaType}:${e.value.id}';
        if (!seen.add(key)) continue;
        out.add(e.value);
      }
      debugPrint('[BecauseYouWatched] tmdb-resolved=${out.length} (sorted by %)');
      return out;
    } catch (e) {
      debugPrint('[BecauseYouWatched] failed: $e');
      return const [];
    }
  }

  void _shuffleBecauseSeed() {
    _pickBecauseSeed(WatchHistoryService().current);
  }

  Future<void> _loadTraktRecommendations() async {
    final workGen = _s._homeBgWorkGen;
    try {
      if (!await TraktService().isLoggedIn()) return;
      if (!mounted || !shellTabVisible || workGen != _s._homeBgWorkGen) return;
      if (mounted) setState(() => _s._traktRecsLoading = true);
      final movies = await ref.read(homeTraktRecommendationsProvider.future);
      if (mounted && workGen == _s._homeBgWorkGen && movies.isNotEmpty) {
        setState(() => _s._traktRecommendations = movies);
      }
    } catch (_) {} finally {
      if (mounted && workGen == _s._homeBgWorkGen) {
        setState(() => _s._traktRecsLoading = false);
      }
    }
  }

  Future<void> _loadTraktCalendar() async {
    final workGen = _s._homeBgWorkGen;
    try {
      if (!await TraktService().isLoggedIn()) return;
      if (!mounted || !shellTabVisible || workGen != _s._homeBgWorkGen) return;
      if (mounted) setState(() => _s._traktShowsLoading = true);
      final movies = await ref.read(homeTraktUpcomingShowsProvider.future);
      if (mounted && workGen == _s._homeBgWorkGen && movies.isNotEmpty) {
        setState(() => _s._traktUpcomingShows = movies);
      }
    } catch (_) {} finally {
      if (mounted && workGen == _s._homeBgWorkGen) {
        setState(() => _s._traktShowsLoading = false);
      }
    }
  }

  Future<void> _loadTraktCalendarMovies() async {
    final workGen = _s._homeBgWorkGen;
    try {
      if (!await TraktService().isLoggedIn()) return;
      if (!mounted || !shellTabVisible || workGen != _s._homeBgWorkGen) return;
      if (mounted) setState(() => _s._traktMoviesLoading = true);
      final movies = await ref.read(homeTraktUpcomingMoviesProvider.future);
      if (mounted && workGen == _s._homeBgWorkGen && movies.isNotEmpty) {
        setState(() => _s._traktUpcomingMovies = movies);
      }
    } catch (_) {} finally {
      if (mounted && workGen == _s._homeBgWorkGen) {
        setState(() => _s._traktMoviesLoading = false);
      }
    }
  }


  Future<List<Movie>> _loadMoodMovies(String moodId) async {
    final mood = _HomeScreenState._moods.firstWhere((m) => m.id == moodId, orElse: () => _HomeScreenState._moods.first);
    final providerId = _s._watchProviderId;
    return _fetchMediaFiltered(
      movieFetch: () => _s._api.discoverMovies(
        genres: mood.movieGenres,
        minRating: 6.0,
        watchProviderId: providerId,
      ),
      tvFetch: () => _s._api.discoverTvShows(
        genres: mood.tvGenres,
        minRating: 6.0,
        watchProviderId: providerId,
      ),
    ).catchError((_) => <Movie>[]);
  }

  void _selectMood(String moodId) {
    if (moodId == _s._selectedMood) return;
    setState(() {
      _s._selectedMood = moodId;
      _s._moodFuture = _loadMoodMovies(moodId);
    });
  }


  @override
  void dispose() {
    if (_s._splashDismissedListener != null) {
      ShellBus.splashDismissed.removeListener(_s._splashDismissedListener!);
    }
    _s._homeScrollController.removeListener(_s._syncHomeScrollOffset);
    _s._homeScrollController.dispose();
    ShellBus.homeScrollOffset.value = 0;
    _s._historySeedSub?.cancel();
    super.dispose();
  }


  Future<void> _openDetails(Movie movie) async {
    if (!mounted) return;
    await AppRouter.openMovie(context, movie: movie);
  }

  Future<void> _watchNow(Movie movie) async {
    if (!mounted) return;
    await AppRouter.openMovie(context, movie: movie, autoPlay: true);
  }
}
