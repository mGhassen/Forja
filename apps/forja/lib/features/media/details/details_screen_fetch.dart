part of 'details_screen.dart';

mixin _DetailsScreenFetch on State<DetailsScreen> {
  _DetailsScreenState get _s => this as _DetailsScreenState;

  Future<void> _resolveInitialSeasonEpisode() async {
    if (widget.initialSeason != null) return;
    final history = await WatchHistoryService().getHistory();
    final entry = latestInProgressForShow(_s._movie.id, history);
    if (entry == null || !mounted) return;
    final season = entry['season'] as int?;
    final episode = entry['episode'] as int?;
    setState(() {
      if (season != null && season > 0) _s._selectedSeason = season;
      if (episode != null && episode > 0) _s._selectedEpisode = episode;
    });
  }
  String _pickDirector(List<Map<String, String>> crew) {
    for (final c in crew) {
      final job = (c['job'] ?? '').toLowerCase();
      if (job.contains('director')) return c['name'] ?? '';
    }
    for (final c in crew) {
      final job = (c['job'] ?? '').toLowerCase();
      if (job.contains('creator')) return c['name'] ?? '';
    }
    return '';
  }
  Future<void> _fetchDetails() async {
    final stremioItem = widget.stremioItem;
    _s._playSourceTorrent = await _s._settings.isPlaySourceTorrentEnabled();
    _s._playSourceStremio = await _s._settings.isPlaySourceStremioEnabled();
    _s._playSourceWebstreaming = await _s._settings.isPlaySourceWebstreamingEnabled();
    _s._syncPanelKindFilterToPlaySources();
    if (!mounted) return;

    final bool isCustomId =
        stremioItem != null &&
        !(stremioItem['id']?.toString().startsWith('tt') ?? true);

    try {
      final streamAddons = await _s._stremio.getAddonsForResource('stream');

      // If this is a custom-ID Stremio item, skip TMDB fetch — we already
      // have all the info we need from the search result.
      if (isCustomId) {
        debugPrint('[DetailsScreen] Custom ID detected: ${stremioItem['id']}');
        debugPrint(
          '[DetailsScreen] stremioItem keys: ${stremioItem.keys.toList()}',
        );
        debugPrint(
          '[DetailsScreen] _addonBaseUrl: ${stremioItem['_addonBaseUrl']}',
        );
        debugPrint('[DetailsScreen] _addonName: ${stremioItem['_addonName']}');
        debugPrint('[DetailsScreen] type: ${stremioItem['type']}');

        // Update movie mediaType if it's a collection
        if (stremioItem['type'] == 'collections') {
          _s._movie = Movie(
            id: _s._movie.id,
            imdbId: _s._movie.imdbId,
            title: _s._movie.title,
            posterPath: _s._movie.posterPath,
            backdropPath: _s._movie.backdropPath,
            voteAverage: _s._movie.voteAverage,
            releaseDate: _s._movie.releaseDate,
            overview: _s._movie.overview,
            mediaType: 'collections',
            genres: _s._movie.genres,
            runtime: _s._movie.runtime,
            numberOfSeasons: _s._movie.numberOfSeasons,
            logoPath: _s._movie.logoPath,
            screenshots: _s._movie.screenshots,
          );
        }

        if (mounted) {
          setState(() {
            _s._streamAddons = streamAddons;
            _s._isLoading = false;
            // Auto-select the addon that owns this item
            final addonBaseUrl = stremioItem['_addonBaseUrl']?.toString() ?? '';
            if (addonBaseUrl.isNotEmpty) {
              _s._selectedSourceId = addonBaseUrl;
            } else if (streamAddons.isNotEmpty) {
              _s._selectedSourceId = streamAddons.first['baseUrl'];
            }
          });
          _s._fetchStremioStreamsForCustomId(stremioItem);
        }
        return;
      }

      final RichMediaDetails rich;
      if (_s._movie.mediaType == 'tv') {
        rich = await _s._api.getRichTvDetails(widget.movie.id);
        if (widget.initialSeason == null) {
          await _resolveInitialSeasonEpisode();
        }
        if (mounted) {
          setState(() => _s._seasonPosters.addAll(rich.extras.seasonPosters));
        }
        await _s._fetchSeason(_s._selectedSeason);
      } else {
        rich = await _s._api.getRichMovieDetails(widget.movie.id);
      }
      final similar = rich.movie.mediaType == 'tv'
          ? await _s._api.getTvRecommendations(rich.movie.id)
          : await _s._api.getMovieRecommendations(rich.movie.id);
      if (mounted) {
        setState(() {
          _s._movie = rich.movie;
          _s._trailerKey = rich.extras.trailerYoutubeKey;
          _s._originalLanguage = rich.extras.originalLanguage;
          _s._tagline = rich.extras.tagline;
          _s._certification = rich.extras.certification;
          _s._status = rich.extras.status;
          _s._lastAirDate = rich.extras.lastAirDate;
          _s._networks = rich.extras.networks;
          _s._creators = rich.extras.creators;
          _s._directorName = _pickDirector(rich.extras.crew);
          _s._budget = rich.extras.budget;
          _s._revenue = rich.extras.revenue;
          _s._spokenLanguages = rich.extras.spokenLanguages;
          _s._productionCompanies = rich.extras.productionCompanies;
          _s._originCountries = rich.extras.originCountries;
          _s._watchProviders = rich.watchProviders;
          _s._castMembers = rich.extras.cast;
          _s._trailers = rich.extras.trailers;
          _s._streamAddons = streamAddons;
          _s._similarMovies = similar;
          _s._isLoading = false;
          if (!_s._playbackProfile.builtinTorrentSearch &&
              streamAddons.isNotEmpty) {
            _s._selectedSourceId =
                streamAddons.first['baseUrl'] as String;
          }
          _s._syncSelectedSourceToPlaySources();
        });
        await _s._hydrateWebstreamingFromCache();
        _s._maybeAutoPlay();
        // Torrent search + Stremio streams load only when Sources opens
        // ([_openSourcesPanel] → [_ensurePanelSourceLoaded]). Nuvio addon
        // listing is cheap and needed for the Nuvio chip.
        if (_s._playSourceTorrent) {
          _s._checkAndFetchNuvio();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _s._isLoading = false);
    }
  }

  /// Probes Nuvio addons (built-in + user installs) for the Sources panel.
  /// Does NOT kick off scraping — that happens when the user picks a scraper.


  Future<void> _fetchExternalRatings() async {
    try {
      if (!await MdblistService().isConfigured()) return;
      Map<String, dynamic>? ratings;
      if (_s._movie.imdbId != null && _s._movie.imdbId!.isNotEmpty) {
        ratings = await MdblistService().getRatingsByImdb(_s._movie.imdbId!);
      } else {
        ratings = await MdblistService().getRatingsByTmdb(
          _s._movie.id,
          _s._movie.mediaType == 'tv' ? 'show' : 'movie',
        );
      }
      if (mounted && ratings != null) setState(() => _s._mdblistRatings = ratings);
    } catch (_) {}
  }

  Future<void> _openRecommendation(Map<String, dynamic> rec) async {
    final id = rec['id']?.toString() ?? '';
    final type = rec['type']?.toString() ?? 'movie';

    // Try TMDB lookup first for IMDB IDs
    if (id.startsWith('tt')) {
      try {
        final movie = await _s._api.findByImdbId(
          id,
          mediaType: type == 'series' ? 'tv' : 'movie',
        );
        if (movie != null && mounted) {
          await AppRouter.openDetails(context, movie: movie);
          return;
        }
      } catch (_) {}
    }

    // Fallback: search TMDB by name
    final name = rec['name']?.toString() ?? '';
    if (name.isNotEmpty) {
      try {
        final results = await _s._api.searchMulti(name);
        if (results.isNotEmpty && mounted) {
          final match = results.firstWhere(
            (m) => m.title.toLowerCase() == name.toLowerCase(),
            orElse: () => results.first,
          );
          await AppRouter.openDetails(context, movie: match);
          return;
        }
      } catch (_) {}
    }

    // Last fallback: minimal Movie
    if (mounted) {
      await AppRouter.openDetails(
        context,
        movie: Movie(
          id: id.hashCode,
          imdbId: id.startsWith('tt') ? id : null,
          title: name.isNotEmpty ? name : id,
          posterPath: '',
          backdropPath: '',
          voteAverage: 0,
          releaseDate: '',
          overview: '',
          mediaType: type == 'series' ? 'tv' : 'movie',
        ),
      );
    }
  }


  void _autoSearch() {
    _s._checkHistory();
    final year = _s._movie.releaseDate.take(4);
    if (_s._movie.mediaType == 'tv') {
      final s = _s._selectedSeason.toString().padLeft(2, '0');
      final e = _s._selectedEpisode.toString().padLeft(2, '0');
      _s._searchTvTorrents('${_s._movie.title} S$s', '${_s._movie.title} S${s}E$e');
    } else {
      _s._searchTorrents('${_s._movie.title} $year');
    }
  }
}
