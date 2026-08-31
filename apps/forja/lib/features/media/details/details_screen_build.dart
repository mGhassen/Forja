part of 'details_screen.dart';

mixin _DetailsScreenBuild on ConsumerState<DetailsScreen> {
  _DetailsScreenState get _s => this as _DetailsScreenState;

  Widget _buildDetailsHero({
    required double heroHeight,
    bool showEpisodeRail = false,
    bool showSeasonRail = false,
    Widget? pageBottomChild,
  }) {
    return MediaDetailsHero(
      movie: _s._movie,
      backdropPathOverride: _selectedSeasonBackdropPath(),
      trailerYoutubeKey: _s._trailerKey,
      trailerLanguageCode: _s._originalLanguage,
      progress: _s._lastProgress,
      height: heroHeight,
      pageBottomChild: pageBottomChild,
      showSeasonRail: showSeasonRail,
      tagline: _s._tagline,
      certification: _s._certification,
      status: _s._status,
      imdbRating: _heroImdbRating,
      directorName: _s._directorName,
      budget: _s._budget,
      revenue: _s._revenue,
      languageCode: _s._originalLanguage,
      spokenLanguages: _s._spokenLanguages,
      productionCompanies: _s._productionCompanies,
      originCountries: _s._originCountries,
      lastAirDate: _s._lastAirDate,
      networks: _s._networks,
      creators: _s._creators,
      watchProviders: _s._watchProviders,
      seriesProgress: _seriesProgressWidget(),
      actionRow: _s._isCollection ? null : _buildHeroActionRow(),
    );
  }

  Widget? _seriesProgressWidget() {
    if (_s._movie.mediaType != 'tv') return null;
    final total = _s._movie.numberOfEpisodes;
    final watched = _s._watchedEpisodes.length;
    if (total <= 0 || watched <= 0) return null;
    return WatchSeriesProgress(watched: watched, total: total);
  }

  double? get _heroImdbRating {
    final r = _s._mdblistRatings;
    if (r == null) return null;
    final scores =
        r['scores'] as List<dynamic>? ?? r['ratings'] as List<dynamic>? ?? [];
    for (final s in scores) {
      final source = (s['source'] ?? '').toString().toLowerCase();
      if (source != 'imdb') continue;
      final value = s['value'] ?? s['score'];
      if (value is num && value > 0) return value.toDouble();
    }
    return null;
  }

  /// Season poster for TV hero backdrop; null keeps the show-level backdrop.
  String? _selectedSeasonBackdropPath() {
    if (_s._movie.mediaType != 'tv' || _s._isCollection) return null;

    final cached = _s._seasonPosters[_s._selectedSeason];
    if (cached != null && cached.isNotEmpty) return cached;

    final seasonData = _s._seasonData;
    if (seasonData != null &&
        (seasonData['season_number'] as int? ?? -1) == _s._selectedSeason) {
      final poster = seasonData['poster_path'] as String?;
      if (poster != null && poster.isNotEmpty) return poster;
    }

    return null;
  }

  Widget _buildHeroActionRow() {
    final progress = _s._lastProgress;
    final pos = watchHistoryInt(progress?['position']);
    final dur = watchHistoryInt(progress?['duration']);
    final hasResume =
        progress != null && WatchProgressBar.isResumable(pos, dur);
    final hasClearableProgress = progress != null && pos > 0;
    final showPlay = _s._hasPanelPlaySources;
    final policy = ShellScope.inputPolicyOf(context);
    if (policy.heroPlayAutoFocus &&
        !_s._detailsHeroInitialFocusDone &&
        !_s._isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _s._detailsHeroInitialFocusDone) return;
        if (_s._detailsHeroPlayFocus.canRequestFocus) {
          _s._detailsHeroPlayFocus.requestFocus();
          _s._detailsHeroInitialFocusDone = true;
        }
      });
    }
    return MediaDetailsTorrentActionRow(
      movie: _s._movie,
      hasResume: hasResume,
      showPlay: showPlay,
      showPlayStreaming: _s._showGreenPlay,
      isStreamingExtracting: _s._isEngineAutoExtracting,
      onOpenSources: _s._openSourcesPanel,
      onClearProgress: hasClearableProgress ? _clearProgress : null,
      onPlayStreaming: _s._onPlayStreamingPressed,
      onOverflowAction: _handleHeroOverflowAction,
      trailers: _s._trailers,
      trailerLanguageCode: _s._originalLanguage,
      userTraktRating: _s._trackerState.userTraktRating,
      userSimklRating: _s._trackerState.userSimklRating,
      isInTraktCollection: _s._trackerState.isInTraktCollection,
      playFocusNode: policy.heroPlayAutoFocus ? _s._detailsHeroPlayFocus : null,
      tvTabId: policy.useFocusableMoodChips ? MediaDetailsTv.tabId : null,
      tvFocusUp: policy.useFocusableMoodChips ? _focusDetailsBack : null,
    );
  }

  void _focusDetailsBack() {
    if (!_s._detailsBackFocus.canRequestFocus) {
      maybePopShellOverlay();
      return;
    }
    _s._detailsBackFocus.requestFocus();
  }

  Future<void> _clearProgress() async {
    final progress = _s._lastProgress;
    if (progress == null) return;
    final uniqueId = progress['uniqueId'] as String?;
    if (uniqueId == null || uniqueId.isEmpty) return;
    await WatchHistoryService().removeItem(uniqueId);
    syncProgressClearedToTrackers(
      tmdbId: _s._movie.id,
      imdbId: _s._movie.imdbId,
      mediaType: _s._movie.mediaType,
      season: progress['season'] as int?,
      episode: progress['episode'] as int?,
    );

    if (!mounted) return;
    setState(() {
      _s._lastProgress = null;
      if (_s._movie.mediaType == 'tv') {
        final season = progress['season'] as int? ?? _s._selectedSeason;
        final episode = progress['episode'] as int? ?? _s._selectedEpisode;
        _s._episodeProgress.remove('S${season}_E$episode');
      }
    });
  }

  Future<void> _handleHeroOverflowAction(String value) async {
    await _s._trackerHandlersOrCreate.handleOverflow(value);
  }

  void _scrollDetailsHeroIntoView() {
    if (!_s._detailsScrollController.hasClients) return;
    _s._detailsScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _revealedDetailsHeroPlayFocus() {
    void focusPlay() {
      if (!mounted) return;
      if (_s._detailsHeroPlayFocus.canRequestFocus) {
        _s._detailsHeroPlayFocus.requestFocus();
      }
    }

    _scrollDetailsHeroIntoView();
    if (!_s._detailsScrollController.hasClients) {
      focusPlay();
      return;
    }
    _s._detailsScrollController
        .animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(focusPlay);
  }

  int _detailsPickerRowCount() {
    var seasonCount = _s._movie.numberOfSeasons;
    if (_s._seasonData != null && _s._seasonData!['seasons'] != null) {
      seasonCount = (_s._seasonData!['seasons'] as List).length;
    }
    if (seasonCount <= 0) return 0;
    return seasonCount > 1 ? 2 : 1;
  }

  @override
  Widget build(BuildContext context) {
    // Own play/resolve bag — hero Direct/Play + Sources panel rebuild from this.
    ref.watch(detailsPlaySessionProvider(_s._metaKey));
    ref.watch(detailsResolveStatusProvider(_s._metaKey));
    final metaAsync = _s._isCustomStremioItem
        ? null
        : ref.watch(detailsMetaProvider(_s._metaKey));
    final isLoading = _s._isLoading || (metaAsync?.isLoading ?? false);

    if (isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
            MediaDetailsBackButton(focusNode: _s._detailsBackFocus),
          ],
        ),
      );
    }

    final tv = SourcesPanelTv.isTv(context);
    final scaffold = Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          ExcludeFocus(
            excluding: tv && _s._sourcesPanelOpen,
            child: _buildScrollLayout(),
          ),
          if (!_s._isCollection && _s._hasPanelPlaySources)
            TorrentSourcesPanel(
              isOpen: _s._sourcesPanelOpen,
              onClose: () => _s._closeSourcesPanel(restoreTvPlayFocus: true),
              child: ExcludeFocus(
                excluding: tv && !_s._sourcesPanelOpen,
                child: _s._sourcesPanelOpen
                    ? SourcesPanelTv.wrapBody(
                        context: context,
                        onClose: () =>
                            _s._closeSourcesPanel(restoreTvPlayFocus: true),
                        child: _buildSourcesPanelContent(),
                      )
                    : _buildSourcesPanelContent(),
              ),
            ),
          ExcludeFocus(
            excluding: tv && _s._sourcesPanelOpen,
            child: MediaDetailsBackButton(focusNode: _s._detailsBackFocus),
          ),
        ],
      ),
    );

    if (!_s._playbackLaunchInFlight) return scaffold;

    return AbsorbPointer(
      absorbing: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          scaffold,
          const ModalBarrier(dismissible: false, color: Color(0x89000000)),
          const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SCROLL LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildScrollLayout() {
    final showEpisodeRail = _s._movie.mediaType == 'tv' && !_s._isCollection;
    final showSeasonRail = showEpisodeRail && _detailsPickerRowCount() > 1;
    final heroHeight = DetailsTokens.heroHeight(
      context,
      showEpisodeRail: showEpisodeRail,
      showSeasonRail: showSeasonRail,
    );
    final showTvPicker = showEpisodeRail;
    final showCast = _s._castMembers.isNotEmpty;
    final showTrailers = _s._trailers.isNotEmpty;
    final heroFocusUp = _revealedDetailsHeroPlayFocus;
    final showCollection = _s._isCollection && _s._collectionItems.isNotEmpty;
    final firstRowIsCollection = showCollection;
    final firstRowIsCast = !showCollection && showCast;
    final firstRowIsTrailers = !showCollection && !showCast && showTrailers;
    final firstRowIsRecs = !showCollection && !showCast && !showTrailers;

    var rowOrder = 0;
    if (showTvPicker) {
      rowOrder += _detailsPickerRowCount();
    }
    final collectionOrder = showCollection ? rowOrder++ : null;
    final castOrder = showCast ? rowOrder++ : null;
    final trailersOrder = showTrailers ? rowOrder++ : null;
    final recsOrder = rowOrder;

    final sections = <Widget>[
      if (showCollection)
        MediaDetailsBody.padContent(
          context,
          DetailsCollectionSection(
            items: _s._collectionItems,
            tvRowOrder: collectionOrder!,
            tvFocusUp: firstRowIsCollection ? heroFocusUp : null,
            onOpenItem: _s._openCollectionItem,
          ),
        ),
      if (showCast)
        MediaDetailsCastSection(
          cast: _s._castMembers,
          title: 'Main Characters',
          tvTabId: MediaDetailsTv.tabId,
          tvRowId: 'cast',
          tvRowOrder: castOrder!,
          tvFocusUp: firstRowIsCast ? heroFocusUp : null,
        ),
      if (showTrailers)
        MediaDetailsTrailersSection(
          trailers: _s._trailers,
          movie: _s._movie,
          languageCode: _s._originalLanguage,
          tvTabId: MediaDetailsTv.tabId,
          tvRowId: 'trailers',
          tvRowOrder: trailersOrder!,
          tvFocusUp: firstRowIsTrailers ? heroFocusUp : null,
        ),
      MediaDetailsRecommendationsSection(
        movies: _s._similarMovies,
        onMovieTap: (movie) => AppRouter.openMovie(context, movie: movie),
        tvTabId: MediaDetailsTv.tabId,
        tvRowOrder: recsOrder,
        tvFocusUp: firstRowIsRecs ? heroFocusUp : null,
      ),
    ];

    return MediaDetailsScrollPage(
      scrollController: _s._detailsScrollController,
      tvHeroPlayFocus: _s._detailsHeroPlayFocus,
      tvBackFocus: _s._detailsBackFocus,
      bodyOverlap: showEpisodeRail ? 0 : null,
      topSpacing: showEpisodeRail
          ? DetailsTokens.bodyTopSpacingWithEpisodes
          : null,
      hero: _buildDetailsHero(
        heroHeight: heroHeight,
        showEpisodeRail: showEpisodeRail,
        showSeasonRail: showSeasonRail,
        pageBottomChild: showTvPicker
            ? MediaDetailsBody.padContent(
                context,
                _s._buildTvPicker(tvRowOrderBase: 0, tvFocusUp: heroFocusUp),
              )
            : null,
      ),
      backgroundColor: AppTheme.bgDark,
      sections: sections,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SOURCES SLIDING PANEL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSourcesPanelContent() {
    final showTorrents = _s._panelKindFilter == 'torrents';
    final showSort = showTorrents;
    final showAudio = showTorrents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TorrentSourcesPanelChrome(
          kindFilter: _s._panelKindFilter,
          showTorrents: _s._panelShowTorrent,
          showStremio: _s._panelShowStremio,
          showNuvio: _s._panelShowNuvio,
          showEngine: _s._panelShowEngine,
          onKindChanged: _s._onPanelKindFilterChanged,
          resultCount: _s._panelVisibleCount,
          isFetching:
              (_s._panelKindFilter == 'torrents' && _s._isSearching) ||
              (_s._panelKindFilter == 'stremio' && _s._isStremioFetching) ||
              (_s._panelKindFilter == 'nuvio' && _s._isNuvioFetching) ||
              (_s._panelKindFilter == EngineIds.kind &&
                  (_s._isEngineFetching ||
                      (_s._enginePacksLoading &&
                          _s._engineSelectedPluginIds.isNotEmpty))),
          onCancelFetch: _s._cancelActiveSourceFetch,
          providerOptions: _s._providerOptions(),
          selectedSourceId: _s._selectedSourceId,
          nuvioSelectedScraperIds: _s._nuvioSelectedScraperIds,
          engineSelectedPluginIds: _s._engineSelectedPluginIds,
          nuvioAllMode: _s._nuvioAllMode,
          engineAllMode: _s._engineAllMode,
          nuvioViewFilterScraperIds: _s._nuvioViewFilterScraperIds,
          engineViewFilterPluginIds: _s._engineViewFilterPluginIds,
          torrentViewFilterProviderIds: _s._torrentViewFilterProviderIds,
          loadingChipIds: _s._loadingChipIds(),
          onProviderTap: _s._onSourceChipTap,
          onProviderCancel: _s._onSourceChipCancel,
          onProviderReload: _s._onSourceChipReload,
          searchQuery: _s._sourceSearchQuery,
          onSearchChanged: (q) {
            setState(() => _s._sourceSearchQuery = q);
            if (_s._sourcesListScrollController.hasClients) {
              _s._sourcesListScrollController.jumpTo(0);
            }
          },
          availableQualities: _s._panelAvailableQualities,
          availableLanguages: _s._panelAvailableLanguages,
          availableTech: _s._panelAvailableTech,
          availableSizeRanges: _s._panelAvailableSizeRanges,
          activeQualityFilters: _s._activeQualityFilters,
          activeLanguageFilters: _s._activeLanguageFilters,
          activeTechFilters: _s._activeTechFilters,
          activeSizeFilters: _s._activeSizeFilters,
          onQualityFiltersChanged: (v) =>
              setState(() => _s._activeQualityFilters = v),
          onLanguageFiltersChanged: (v) =>
              setState(() => _s._activeLanguageFilters = v),
          onTechFiltersChanged: (v) =>
              setState(() => _s._activeTechFilters = v),
          onSizeFiltersChanged: (v) =>
              setState(() => _s._activeSizeFilters = v),
          showEngineCategories: _s._panelKindFilter == EngineIds.kind,
          engineVisibleCategories: _s._effectiveEngineCategories,
          engineCategoryOptions: EngineCategories.filterTypesFromPlugins([
            for (final pack in _s._enginePacks) ...pack.plugins,
          ]),
          engineCategoryMediaType: _s._enginePanelCategory,
          onEngineCategoriesChanged: (v) =>
              setState(() => _s._engineVisibleCategories = v),
          showAudioFilters: showAudio,
          activeAudioFilters: _s._activeAudioFilters,
          onAudioFiltersChanged: (v) =>
              setState(() => _s._activeAudioFilters = v),
          sortPreference: showSort ? _s._sortPreference : null,
          onSortChanged: showSort
              ? (val) {
                  setState(() => _s._sortPreference = val);
                  _s._settings.setSortPreference(val);
                  _s._sortResults();
                }
              : null,
          showCacheLine: showTorrents && _s._playbackProfile.localTorrentEngine,
          cacheRefreshToken: Object.hash(
            _s._sourcesPanelOpen,
            _s._allTorrentResults.length,
            _s._isSearching,
          ),
          onReloadKind: _s._reloadPanelKind,
          sourcesPanelOpen: _s._sourcesPanelOpen,
          onFocusList: () => SourcesPanelTv.focusListItem(),
        ),
        Expanded(child: _s._buildStreamList(inPanel: true)),
        SourcesPanelMetaFooter(
          episodeLabel: _s._movie.mediaType == 'tv'
              ? 'S${_s._selectedSeason.toString().padLeft(2, '0')}E${_s._selectedEpisode.toString().padLeft(2, '0')}'
              : null,
          resultCount: _s._panelVisibleCount,
        ),
      ],
    );
  }
}
