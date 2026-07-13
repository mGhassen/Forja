part of 'search_screen.dart';

mixin _SearchSearch on State<SearchScreen> {
  SearchScreenState get _s => this as SearchScreenState;

  Future<void> _loadProviders() async {
    final catalogs = await _s._stremio.getAllCatalogs();
    final Map<String, Map<String, dynamic>> providers = {};
    for (final c in catalogs) {
      if (c['supportsSearch'] != true) continue;
      final key = c['addonBaseUrl'] as String;
      if (!providers.containsKey(key)) {
        providers[key] = {
          'id': key,
          'name': c['addonName'],
          'icon': c['addonIcon'],
          'baseUrl': key,
          'catalogs': <Map<String, dynamic>>[],
        };
      }
      (providers[key]!['catalogs'] as List).add(c);
    }
    if (mounted) {
      setState(() => _s._addonProviders = providers.values.toList());
    }
  }

  Future<void> _loadTrendingHelpers() async {
    try {
      final movies = await _s._api.getTrending();
      final shows = await _s._api.getTrendingTv();
      final titles = <String>[];
      for (final item in [...movies, ...shows]) {
        if (item.title.isEmpty || titles.contains(item.title)) continue;
        titles.add(item.title);
        if (titles.length >= 12) break;
      }
      if (mounted) {
        setState(() => _s._trendingHelperTitles = titles);
        shellTvRegisterRow(
          tabId: 'search',
          rowId: 'helpers',
          sortOrder: 0,
          itemCount: titles.length,
          orientation: ShellTvRowOrientation.vertical,
        );
        if (_s._query.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_s._tvFocus(context) &&
                ShellTvFocus.currentNavTabId == 'search' &&
                !_s._focusNode.hasFocus) {
              _s._focusSearchFieldBrowse();
            }
          });
        }
      }
    } catch (_) {}
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
    if (_s._addonProviders.isEmpty) await _loadProviders();
    if (mounted) {
      _s._controller.text = query;
      _onSearchChanged(query);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _s._query = query;
      _s._gridFocusedIndex = 0;
    });
    ShellBus.notifyShellChromeChanged();
    _s._debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _s._sections.clear();
        _s._isSearching = false;
        _s._helperFocusedIndex = null;
        _s._gridFocusedIndex = 0;
        _s._pendingGridFocusIndex = null;
      });
      if (_s._tvFocus(context) && _s._focusNode.hasFocus) {
        _s._focusSearchFieldBrowse();
      }
      return;
    }
    _s._debounce = Timer(const Duration(milliseconds: 500), () {
      _performUnifiedSearch(query);
    });
  }

  /// Fire all search APIs in parallel; results stream in as they arrive.
  Future<void> _performUnifiedSearch(String query) async {
    if (query.trim().isEmpty) return;

    final gen = ++_s._searchGeneration;
    setState(() {
      _s._sections.clear();
      _s._isSearching = true;
      _s._gridFocusedIndex = 0;
    });

    int pendingCount = 1 + _s._addonProviders.length; // TMDB + each addon

    void decPending() {
      pendingCount--;
      if (pendingCount <= 0 && gen == _s._searchGeneration && mounted) {
        setState(() => _s._isSearching = false);
      }
    }

    // ── TMDB ──
    _searchTmdb(query, gen).then((_) => decPending());

    // ── Stremio Addons ──
    for (final provider in _s._addonProviders) {
      _searchAddon(query, provider, gen).then((_) => decPending());
    }
  }

  Future<void> _searchTmdb(String query, int gen) async {
    try {
      final results = await _s._api.searchMulti(query);
      if (gen != _s._searchGeneration || !mounted) return;

      final movies = results.where((m) => m.mediaType == 'movie').toList();
      final shows = results.where((m) => m.mediaType == 'tv').toList();

      setState(() {
        if (movies.isNotEmpty) {
          _s._sections.insert(
            0,
            _SearchSection(
              key: 'tmdb_movies',
              title: 'TMDB Movies',
              isTmdb: true,
              results: movies,
            ),
          );
        }
        if (shows.isNotEmpty) {
          // Insert after tmdb_movies if it exists, else at 0
          final idx = _s._sections.indexWhere((s) => s.key == 'tmdb_movies');
          _s._sections.insert(
            idx >= 0 ? idx + 1 : 0,
            _SearchSection(
              key: 'tmdb_shows',
              title: 'TMDB Shows',
              isTmdb: true,
              results: shows,
            ),
          );
        }
      });
      _s._scheduleFocusOnResultCardIfPending();
    } catch (e) {
      debugPrint('TMDB search error: $e');
    }
  }

  Future<void> _searchAddon(
    String query,
    Map<String, dynamic> provider,
    int gen,
  ) async {
    final providerBaseUrl = provider['baseUrl'] as String;
    final providerName = provider['name'] as String;
    final providerIcon = provider['icon']?.toString() ?? '';
    final catalogs = provider['catalogs'] as List<Map<String, dynamic>>;

    // Group results by type (movie / series)
    final Map<String, List<Map<String, dynamic>>> byType = {};

    await Future.wait(
      catalogs.map((cat) async {
        try {
          final results = await _s._stremio.getCatalog(
            baseUrl: cat['addonBaseUrl'],
            type: cat['catalogType'],
            id: cat['catalogId'],
            search: query,
          );
          for (final r in results) {
            r['_addonBaseUrl'] = providerBaseUrl;
            r['_addonName'] = providerName;
          }
          final type = cat['catalogType']?.toString() ?? 'other';
          byType.putIfAbsent(type, () => []);
          byType[type]!.addAll(results);
        } catch (_) {}
      }),
    );

    if (gen != _s._searchGeneration || !mounted) return;

    setState(() {
      for (final entry in byType.entries) {
        // Deduplicate within this type
        final seen = <String>{};
        final deduped = entry.value.where((r) {
          final id = r['id']?.toString() ?? '';
          if (id.isEmpty || seen.contains(id)) return false;
          seen.add(id);
          return true;
        }).toList();

        if (deduped.isEmpty) continue;

        final typeLabel = entry.key == 'series'
            ? 'Shows'
            : (entry.key == 'movie' ? 'Movies' : entry.key);
        _s._sections.add(
          _SearchSection(
            key: '${providerBaseUrl}_${entry.key}',
            title: '$providerName $typeLabel',
            icon: providerIcon,
            results: deduped,
          ),
        );
      }
    });
    _s._scheduleFocusOnResultCardIfPending();
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
