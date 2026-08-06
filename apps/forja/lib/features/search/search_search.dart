part of 'search_screen.dart';

mixin _SearchSearch on ConsumerState<SearchScreen> {
  SearchScreenState get _s => this as SearchScreenState;

  List<Map<String, dynamic>> get _addonProviders {
    return ref.watch(searchAddonProvidersProvider).valueOrNull ?? const [];
  }

  List<String> get _trendingHelperTitles {
    return ref.watch(searchTrendingTitlesProvider).valueOrNull ?? const [];
  }

  bool get _trendingHelpersLoading {
    final async = ref.watch(searchTrendingTitlesProvider);
    return async.isLoading && !async.hasValue;
  }

  /// Left column: recent + recommendations (empty) or recent + result titles (query).
  List<_SearchHelperEntry> get _helperEntries {
    final recent = _s._recentQueries;
    final recentLower = {for (final q in recent) q.toLowerCase()};

    if (_s._query.trim().isNotEmpty) {
      final results = _s._flatResults();
      return [
        for (final q in recent) _SearchHelperEntry(q, isRecent: true),
        for (var i = 0; i < results.length; i++)
          if (!recentLower.contains(results[i].title.toLowerCase()))
            _SearchHelperEntry(
              results[i].title,
              isRecent: false,
              resultIndex: i,
            ),
      ];
    }

    final recs = SearchRecentQueries.pickRecommendations(
      _trendingHelperTitles,
      exclude: recent,
    );
    return [
      for (final q in recent) _SearchHelperEntry(q, isRecent: true),
      for (final t in recs) _SearchHelperEntry(t, isRecent: false),
    ];
  }

  Future<void> _recordRecentQuery(String query) async {
    final next = await SearchRecentQueries.record(
      SearchRecentQueries.scopeSearch,
      query,
    );
    if (!mounted) return;
    setState(() => _s._recentQueries = next);
  }

  List<_SearchSection> _mapSearchSections(List<SearchResultSection> sections) {
    return sections
        .map(
          (s) => _SearchSection(
            key: s.key,
            title: s.title,
            icon: s.icon,
            isTmdb: s.isTmdb,
            results: List<dynamic>.from(s.results),
          ),
        )
        .toList();
  }

  /// Apply provider value into local fields without [setState].
  /// Safe to call from [build] (Riverpod watch path).
  void _applySearchAsync(AsyncValue<List<SearchResultSection>> async) {
    async.when(
      loading: () {
        _s._isSearching = true;
      },
      error: (_, _) {
        _s._isSearching = false;
      },
      data: (sections) {
        _s._sections = _mapSearchSections(sections);
        _s._isSearching = false;
      },
    );
  }

  /// Debounced query change → immediate fetch (TV submit / external).
  void _runSearchNow(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _s._activeSearchQuery = trimmed;
      _s._sections = [];
      _s._isSearching = true;
      _s._gridFocusedIndex = null;
    });
    _recordRecentQuery(trimmed);
    (_s._container ?? ProviderScope.containerOf(context, listen: false))
        .invalidate(searchResultsProvider(trimmed));
  }

  void _applyHelperQuery(String title) {
    _s._pendingGridFocusIndex = 0;
    _s._controller.text = title;
    _onSearchChanged(title);
  }

  void _onExternalSearch() async {
    final data = ShellBus.stremioSearchNotifier.value;
    if (data == null || (data['query'] ?? '').isEmpty) return;
    final query = data['query']!;
    await ref.read(searchAddonProvidersProvider.future);
    if (mounted) {
      _s._controller.text = query;
      _onSearchChanged(query);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _s._query = query;
      _s._gridFocusedIndex = null;
    });
    ShellBus.notifyShellChromeChanged();
    _s._debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _s._sections.clear();
        _s._isSearching = false;
        _s._activeSearchQuery = '';
        _s._helperFocusedIndex = null;
        _s._gridFocusedIndex = null;
        _s._pendingGridFocusIndex = null;
      });
      if (_s._tvFocus(context) && _s._focusNode.hasFocus) {
        _s._focusSearchFieldBrowse();
      }
      return;
    }
    _s._debounce = Timer(const Duration(milliseconds: 500), () {
      final trimmed = query.trim();
      if (trimmed.isEmpty) return;
      setState(() {
        _s._activeSearchQuery = trimmed;
        _s._sections = [];
        _s._isSearching = true;
        _s._gridFocusedIndex = null;
      });
      _recordRecentQuery(trimmed);
      (_s._container ?? ProviderScope.containerOf(context, listen: false))
          .invalidate(searchResultsProvider(trimmed));
    });
  }

  /// Watch [searchResultsProvider] in build — never [setState] here.
  void _watchSearchResultsProvider() {
    final query = _s._activeSearchQuery.trim();
    if (query.isEmpty) return;

    final async = ref.watch(searchResultsProvider(query));
    final wasSearching = _s._isSearching;
    _applySearchAsync(async);

    // Focus after results land (post-frame — must not run mid-build).
    if (async.hasValue &&
        wasSearching &&
        _s._pendingGridFocusIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _s._scheduleFocusOnResultCardIfPending();
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation helpers (unchanged from original)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _openDetails(Movie movie) async {
    if (!mounted) return;
    await AppRouter.openMovie(context, movie: movie);
  }

  Future<void> _openStremioItem(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    final type = item['type']?.toString() ?? 'movie';
    final name = item['name']?.toString() ?? 'Unknown';
    final poster = item['poster']?.toString() ?? '';
    final isCustomId = !id.startsWith('tt');
    final isCollection = id.startsWith('ctmdb.') || type == 'collections';

    if (!isCustomId && !isCollection) {
      try {
        final movie = await _s._api.findByImdbId(
          id,
          mediaType: type == 'series' ? 'tv' : 'movie',
        );
        if (movie != null && mounted) {
          await AppRouter.openDetails(context, movie: movie, stremioItem: item);
          return;
        }
      } catch (_) {}
    }

    if (!isCustomId && !isCollection) {
      try {
        final results = await _s._api.searchMulti(name);
        if (results.isNotEmpty && mounted) {
          final match = results.firstWhere(
            (m) => m.title.toLowerCase() == name.toLowerCase(),
            orElse: () => results.first,
          );
          await AppRouter.openDetails(context, movie: match, stremioItem: item);
          return;
        }
      } catch (_) {}
    }

    if (mounted) {
      final actualType = isCollection
          ? 'collections'
          : (type == 'series' ? 'tv' : 'movie');
      final movie = Movie(
        id: id.hashCode,
        imdbId: id.startsWith('tt') ? id : null,
        title: name,
        posterPath: poster,
        backdropPath: item['background']?.toString() ?? poster,
        voteAverage: double.tryParse(item['imdbRating']?.toString() ?? '') ?? 0,
        releaseDate: item['releaseInfo']?.toString() ?? '',
        overview: item['description']?.toString() ?? '',
        mediaType: actualType,
      );
      final updatedItem = Map<String, dynamic>.from(item);
      if (isCollection) updatedItem['type'] = 'collections';
      await AppRouter.openDetails(
        context,
        movie: movie,
        stremioItem: updatedItem,
      );
    }
  }
}
