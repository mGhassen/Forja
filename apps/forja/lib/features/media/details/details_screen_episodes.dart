part of 'details_screen.dart';

mixin _DetailsScreenEpisodes on ConsumerState<DetailsScreen> {
  _DetailsScreenState get _s => this as _DetailsScreenState;

  Future<void> _loadEpisodeProgressForSeason(int season) async {
    List episodes = [];
    if (_s._seasonData != null) {
      if (_s._seasonData!['episodes'] != null) {
        episodes = _s._seasonData!['episodes'] as List;
      } else if (_s._seasonData!['episodesBySeason'] != null) {
        final bySeason = _s._seasonData!['episodesBySeason'] as Map;
        episodes = bySeason[season] as List? ?? [];
      }
    }
    final map = <String, Map<String, dynamic>>{};
    for (final ep in episodes) {
      final n = (ep['episode_number'] ?? ep['episode']) as int;
      final p = await WatchHistoryService().getProgress(
        _s._movie.id,
        season: season,
        episode: n,
      );
      if (p != null) map['S${season}_E$n'] = p;
    }
    if (mounted) setState(() => _s._episodeProgress = map);
  }
  void _refreshSourcesForEpisode() {
    if (!_s._isCurrentSourceAllowed()) {
      _s._syncSelectedSourceToPlaySources();
    }
    // Drop in-memory rows for the previous episode; session TTL cache is
    // keyed by S/E so the new episode hydrates or fetches independently.
    _s._invalidatePanelSourceCache();
    _s._ensurePanelSourceLoaded();
  }
  void _highlightEpisode(int episode) {
    if (_s._selectedEpisode == episode) return;
    setState(() {
      _s._selectedEpisode = episode;
      _s._syncSelectedSourceToPlaySources();
    });
    if (_s._sourcesPanelOpen) {
      _refreshSourcesForEpisode();
    } else {
      _s._invalidatePanelSourceCache();
    }
  }
  Future<void> _onEpisodeSelected(int episode) async {
    _highlightEpisode(episode);
    await _s._checkHistory();
  }

  Future<void> _onEpisodePlay(int episode) async {
    if (_s._selectedEpisode != episode) {
      _highlightEpisode(episode);
    }
    await _s._checkHistory();
    if (!mounted) return;

    final progress = _s._lastProgress;
    if (progress != null && hasSavedEpisodePlayback(progress)) {
      if (await _s._tryDirectEpisodeResumeFromHistory(progress)) return;
    }

    if (_s._playSourceEngine && _s._playSourceEngineAutoStart) {
      unawaited(_s._startEngineAutoPlayback());
      return;
    }

    if (_s._hasPanelPlaySources) {
      _s._openSourcesPanel();
    }
  }
  void _onSeasonSelected(int season) {
    if (widget.stremioItem != null &&
        _s._seasonData != null &&
        _s._seasonData!['episodesBySeason'] != null) {
      setState(() {
        _s._selectedSeason = season;
        _s._selectedEpisode = 1;
      });
      _s._fetchStremioStreamsForCustomId(widget.stremioItem!);
      _s._checkHistory();
      _loadEpisodeProgressForSeason(season);
      return;
    }
    _fetchSeason(season);
  }
  Widget _buildTvPicker({
    required int tvRowOrderBase,
    VoidCallback? tvFocusUp,
  }) {
    int seasonCount = _s._movie.numberOfSeasons;
    if (_s._seasonData != null && _s._seasonData!['seasons'] != null) {
      seasonCount = (_s._seasonData!['seasons'] as List).length;
    }
    Map<int, List<Map<String, dynamic>>>? customEpisodes;
    if (_s._seasonData != null && _s._seasonData!['episodesBySeason'] != null) {
      customEpisodes = Map<int, List<Map<String, dynamic>>>.from(
        (_s._seasonData!['episodesBySeason'] as Map).map(
          (k, v) =>
              MapEntry(k as int, List<Map<String, dynamic>>.from(v as List)),
        ),
      );
    }
    return TvSeasonEpisodePicker(
      tmdbId: _s._movie.id,
      seasonCount: seasonCount,
      selectedSeason: _s._selectedSeason,
      selectedEpisode: _s._selectedEpisode,
      isLoadingSeason: _s._isLoadingSeason,
      seasonData: _s._seasonData,
      watchedEpisodes: _s._watchedEpisodes,
      fallbackPosterPath: _s._movie.posterPath.isNotEmpty
          ? _s._movie.posterPath
          : _s._movie.backdropPath,
      seasonPosters: _s._seasonPosters,
      episodeProgress: _s._episodeProgress,
      customEpisodesBySeason: customEpisodes,
      onSeasonSelected: _onSeasonSelected,
      onEpisodeSelected: _onEpisodeSelected,
      onEpisodePlay: _onEpisodePlay,
      onEpisodeFocused: _highlightEpisode,
      onToggleWatched: _toggleEpisodeWatched,
      onSeasonToggleWatched: _toggleSeasonWatched,
      tvTabId: MediaDetailsTv.tabId,
      tvSeasonRowId: 'seasons',
      tvEpisodeRowId: 'episodes',
      tvRowOrderBase: tvRowOrderBase,
      tvFocusUp: tvFocusUp,
    );
  }

  Future<void> _loadWatchedEpisodes() async {
    final set = await _s._episodeWatchedService.getWatchedSet(_s._movie.id);
    if (mounted) setState(() => _s._watchedEpisodes = set);
    if (mounted) await _reconcileListStatusFromWatched();
  }

  Future<void> _reconcileListStatusFromWatched() async {
    if (_s._movie.mediaType != 'tv') return;
    final total = _s._movie.numberOfEpisodes;
    if (total <= 0 || _s._watchedEpisodes.isEmpty) return;
    ProviderContainer? container;
    try {
      container = ProviderScope.containerOf(_s.context, listen: false);
    } catch (_) {}
    await ListFollowFromWatched.reconcileTmdb(
      movie: _s._movie,
      watchedCount: _s._watchedEpisodes.length,
      totalEpisodes: total,
      container: container,
    );
  }

  Future<void> _toggleEpisodeWatched(int season, int episode) async {
    await _s._episodeWatchedService.toggle(_s._movie.id, season, episode);
    await _loadWatchedEpisodes();
  }

  Future<void> _toggleSeasonWatched(int season, List<int> episodes) async {
    var epNums = episodes;
    if (epNums.isEmpty) {
      epNums = await _episodeNumbersForSeason(season);
    }
    if (epNums.isEmpty) return;

    await _s._episodeWatchedService.toggleSeason(
      _s._movie.id,
      season,
      epNums,
    );
    if (!mounted) return;
    await _loadWatchedEpisodes();
  }

  Future<List<int>> _episodeNumbersForSeason(int season) async {
    List episodes = [];
    if (_s._seasonData != null &&
        (_s._seasonData!['season_number'] as int? ?? _s._selectedSeason) ==
            season &&
        _s._seasonData!['episodes'] != null) {
      episodes = _s._seasonData!['episodes'] as List;
    } else {
      try {
        final data =
            await _s._api.getTvSeasonDetails(_s._movie.id, season);
        episodes = data['episodes'] as List? ?? [];
      } catch (_) {
        return [];
      }
    }
    return [
      for (final raw in episodes)
        if (raw is Map &&
            !episodeAirDateInfo(Map<String, dynamic>.from(raw))
                .notShippedYet)
          (raw['episode_number'] ?? raw['episode']) as int,
    ];
  }
  Future<void> _fetchSeason(int seasonNumber) async {
    setState(() => _s._isLoadingSeason = true);
    try {
      final data = await _s._api.getTvSeasonDetails(_s._movie.id, seasonNumber);
      if (mounted) {
        final poster = data['poster_path'] as String?;
        // Preserve episode when refetching the already-selected season
        // (history resolve sets S/E before this fetch; do not wipe to E1).
        final previousSeason = _s._selectedSeason;
        final previousEpisode = _s._selectedEpisode;
        setState(() {
          _s._seasonData = data;
          _s._isLoadingSeason = false;
          _s._selectedSeason = seasonNumber;
          if (poster != null && poster.isNotEmpty) {
            _s._seasonPosters[seasonNumber] = poster;
          }
          if (widget.initialEpisode != null &&
              seasonNumber == widget.initialSeason) {
            _s._selectedEpisode = widget.initialEpisode!;
          } else if (seasonNumber == previousSeason && previousEpisode > 0) {
            _s._selectedEpisode = previousEpisode;
          } else {
            _s._selectedEpisode = 1;
          }
        });
        await _loadEpisodeProgressForSeason(seasonNumber);
        _s._checkHistory();
        if (_s._sourcesPanelOpen) {
          _refreshSourcesForEpisode();
        } else {
          _s._invalidatePanelSourceCache();
        }
        _loadWatchedEpisodes();
      }
    } catch (e) {
      if (mounted) setState(() => _s._isLoadingSeason = false);
    }
  }
}
