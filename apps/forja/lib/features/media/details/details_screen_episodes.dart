part of 'details_screen.dart';

mixin _DetailsScreenEpisodes on State<DetailsScreen> {
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
    setState(() => _s._selectedEpisode = episode);
    if (_s._sourcesPanelOpen) {
      _refreshSourcesForEpisode();
    } else {
      _s._invalidatePanelSourceCache();
    }
  }
  void _openTorrentPanelForEpisode({bool preselectHistory = false}) {
    setState(() {
      _s._sourcesPanelOpen = true;
      _s._episodePlayPending = false;
      if (preselectHistory) {
        _s._applyPanelFilterForSavedMethod('torrent');
      }
      if (_s._panelShowTorrent) _s._selectedSourceId = 'forja';
    });
    _refreshSourcesForEpisode();
  }

  Future<void> _onEpisodeSelected(int episode) async {
    setState(() {
      _s._selectedEpisode = episode;
      _s._webstreamingStreams = [];
      _s._webstreamingActiveProviderId = null;
      _s._syncSelectedSourceToPlaySources();
    });
    await _s._checkHistory();
    if (!mounted) return;

    final progress = _s._lastProgress;
    final savedPlayback = hasSavedEpisodePlayback(progress);
    final stale = savedPlayback && isStaleResume(progress);
    final savedMethod = progress?['method'] as String?;

    if (stale) {
      if (savedMethod == 'torrent' && _s._hasPanelPlaySources) {
        setState(() {
          _s._sourcesPanelOpen = true;
          _s._episodePlayPending = false;
          _s._applyPanelFilterForSavedMethod(savedMethod);
        });
        _refreshSourcesForEpisode();
      }
      return;
    }

    if (savedPlayback && progress != null) {
      if (savedMethod == 'torrent' &&
          _s._playSourceTorrent &&
          _s._hasPanelPlaySources) {
        _openTorrentPanelForEpisode(preselectHistory: true);
        return;
      }

      if (_s._isDirectStreamingSavedMethod(savedMethod)) {
        await _s._hydrateWebstreamingFromCache();
        if (!mounted) return;
        await _s._tryDirectEpisodeResumeFromHistory(progress);
        return;
      }
    }

    // Never played — webstreaming auto-play only; never auto-launch torrent.
    if (_s._playSourceWebstreaming) {
      unawaited(_s._startWebstreamingOnlyPlayback());
      return;
    }

    if (_s._hasPanelPlaySources) {
      _openTorrentPanelForEpisode();
    }
  }
  void _onSeasonSelected(int season) {
    if (widget.stremioItem != null &&
        _s._seasonData != null &&
        _s._seasonData!['episodesBySeason'] != null) {
      setState(() {
        _s._selectedSeason = season;
        _s._selectedEpisode = 1;
        _s._webstreamingStreams = [];
        _s._webstreamingActiveProviderId = null;
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
      onEpisodeFocused: _highlightEpisode,
      onToggleWatched: _toggleEpisodeWatched,
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
  }

  Future<void> _toggleEpisodeWatched(int season, int episode) async {
    await _s._episodeWatchedService.toggle(_s._movie.id, season, episode);
    await _loadWatchedEpisodes();
  }
  Future<void> _fetchSeason(int seasonNumber) async {
    setState(() => _s._isLoadingSeason = true);
    try {
      final data = await _s._api.getTvSeasonDetails(_s._movie.id, seasonNumber);
      if (mounted) {
        final poster = data['poster_path'] as String?;
        setState(() {
          _s._seasonData = data;
          _s._isLoadingSeason = false;
          _s._selectedSeason = seasonNumber;
          _s._webstreamingStreams = [];
          _s._webstreamingActiveProviderId = null;
          if (poster != null && poster.isNotEmpty) {
            _s._seasonPosters[seasonNumber] = poster;
          }
          // Only reset to episode 1 if no initial episode was provided,
          // or if we're navigating to a different season after init.
          if (widget.initialEpisode != null &&
              seasonNumber == widget.initialSeason) {
            _s._selectedEpisode = widget.initialEpisode!;
          } else {
            _s._selectedEpisode = 1;
          }
        });
        await _s._hydrateWebstreamingFromCache();
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
