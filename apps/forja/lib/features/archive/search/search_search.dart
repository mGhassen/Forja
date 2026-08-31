part of 'search_screen.dart';

mixin _SearchSearch on ConsumerState<SearchScreen> {
  SearchScreenState get _s => this as SearchScreenState;

  List<String> get _trendingHelperTitles {
    final key = _s._activeSearchQuery.trim().isNotEmpty
        ? _s._activeSearchQuery.trim()
        : '';
    return ref.watch(searchHelperTitlesProvider(key)).valueOrNull ?? const [];
  }

  bool get _trendingHelpersLoading {
    final key = _s._activeSearchQuery.trim().isNotEmpty
        ? _s._activeSearchQuery.trim()
        : '';
    final async = ref.watch(searchHelperTitlesProvider(key));
    return async.isLoading && !async.hasValue;
  }

  /// Left column: recent + recommendations — never mirrors result cards.
  List<_SearchHelperEntry> get _helperEntries {
    final recent = _s._recentQueries;
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

  Future<void> _removeRecentQuery(String query, {required int index}) async {
    final next = await SearchRecentQueries.remove(
      SearchRecentQueries.scopeSearch,
      query,
    );
    if (!mounted) return;
    setState(() {
      _s._recentQueries = next;
      _s._helperFocusedIndex = null;
    });
    final count = _s._helperItemCount();
    if (count == 0) {
      _s._focusSearchFieldBrowse();
      return;
    }
    final focusIndex = index.clamp(0, count - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _s._focusHelperAtIndex(focusIndex);
    });
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
  void _applySearchState(SearchResultsState search) {
    _s._sections = _mapSearchSections(search.sections);
    _s._isSearching = search.isSearching;
  }

  /// Debounced query change → immediate fetch (TV submit / external).
  void _runSearchNow(String query) {
    _s._query = query;
    final effective = _effectiveSearchQuery(query);
    if (effective.trim().isEmpty) return;
    _commitSearch(effective, recordRecent: query.trim().isNotEmpty);
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


  String _effectiveSearchQuery([String? typed]) {
    return composeSearchQuery(typed ?? _s._query, _s._filters);
  }

  void _commitSearch(String effective, {required bool recordRecent}) {
    final trimmed = effective.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _s._sections.clear();
        _s._isSearching = false;
        _s._activeSearchQuery = '';
        _s._helperFocusedIndex = null;
        _s._gridFocusedIndex = null;
        _s._pendingGridFocusIndex = null;
      });
      return;
    }
    setState(() {
      _s._activeSearchQuery = trimmed;
      _s._sections = [];
      _s._isSearching = true;
      _s._gridFocusedIndex = null;
    });
    if (recordRecent) {
      final typed = _s._query.trim();
      if (typed.isNotEmpty) _recordRecentQuery(typed);
    }
    (_s._container ?? ProviderScope.containerOf(context, listen: false))
        .invalidate(searchResultsProvider(trimmed));
  }

  void _onFiltersChanged(SearchFilters next) {
    // Draft only — search runs on Submit in the filter lens.
    setState(() => _s._filters = next);
    ShellBus.notifyShellChromeChanged();
  }

  void _submitFilters() {
    _s._debounce?.cancel();
    final effective = _effectiveSearchQuery();
    _commitSearch(effective, recordRecent: false);
    if (_s._filtersOpen) {
      setState(() => _s._filtersOpen = false);
    }
  }

  void _toggleFiltersOpen() {
    setState(() => _s._filtersOpen = !_s._filtersOpen);
  }

  void _onSearchChanged(String query) {
    setState(() {
      _s._query = query;
      _s._gridFocusedIndex = null;
    });
    ShellBus.notifyShellChromeChanged();
    _s._debounce?.cancel();
    final effective = _effectiveSearchQuery(query);
    if (effective.trim().isEmpty) {
      _commitSearch('', recordRecent: false);
      if (_s._leanbackTextInput(context) && _s._focusNode.hasFocus) {
        _s._focusSearchFieldBrowse();
      }
      return;
    }
    _s._debounce = Timer(const Duration(milliseconds: 500), () {
      // TV: only persist on OK/submit — debounce would save every IME partial.
      final record = !_s._leanbackTextInput(context) || !_s._searchFieldEditing;
      _commitSearch(_effectiveSearchQuery(query), recordRecent: record);
    });
  }

  /// Watch [searchResultsProvider] in build — never [setState] here.
  void _watchSearchResultsProvider() {
    final query = _s._activeSearchQuery.trim();
    if (query.isEmpty) return;

    final search = ref.watch(searchResultsProvider(query));
    final wasSearching = _s._isSearching;
    _applySearchState(search);

    // Focus after results land (post-frame — must not run mid-build).
    if (search.tmdbDone &&
        search.sections.isNotEmpty &&
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
