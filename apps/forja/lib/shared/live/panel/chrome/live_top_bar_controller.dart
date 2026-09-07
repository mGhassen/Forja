part of '../live_sports_streams_page.dart';

mixin _LiveMatchesData
    on ConsumerState<LiveSportsStreamsPage>, ShellTabRefresh<LiveSportsStreamsPage> {
  _LiveSportsStreamsPageState get _s => this as _LiveSportsStreamsPageState;

  bool get _tvFocusEnabled =>
      ShellScope.inputPolicyOf(context).useFocusableMoodChips;

  void _scheduleRestoreLiveMatchesTvFocus() {
    if (!_tvFocusEnabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ShellTvFocus.currentNavTabId != _LiveSportsStreamsPageState._tabId) {
        return;
      }
      _restoreLiveMatchesTvFocus();
    });
  }

  Future<void> _syncMyIptvFromActivePortal(
    IptvController ctrl, {
    required bool reload,
  }) async {
    final p = ctrl.activePortal;
    if (p == null) return;
    try {
      await ctrl.preparePortalPanel();
    } catch (e) {
      final alreadyWarned = _s._lastSyncedIptvPortalKey == p.key;
      _s._lastSyncedIptvPortalKey = p.key;
      if (!alreadyWarned && mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('IPTV portal sync failed: $e')),
        );
      }
      return;
    }
    _s._lastSyncedIptvPortalKey = p.key;
    if (!mounted) return;
    if (reload) {
      await _load();
    }
  }

  bool get _applyTimeWindowFilter => _s._showCatalogTopBar;

  bool _restoreLiveMatchesTvFocus() {
    // Browse grid/top-bar focus deleted — kit browse owns TV land.
    return false;
  }

  void _releaseLiveMatchesItemFocusIfHeld() {
    // No-op: browse item / top-bar focus nodes removed.
  }

  void _scheduleRestoreRefreshFocus({bool clearWhenSettled = false}) {
    // No-op: refresh top-bar control deleted.
  }

  Future<void> _load() async {
    if (!mounted || !shellTabVisible) return;
    final iptvConfig = await LiveMatchesIptvSportsConfig.load();
    final mergeChanged =
        _s._mergeMatchingEvents != iptvConfig.mergeMatchingEvents;
    if (_s._iptvSportsEnabled != iptvConfig.enabled || mergeChanged) {
      setState(() {
        _s._iptvSportsEnabled = iptvConfig.enabled;
        _s._mergeMatchingEvents = iptvConfig.mergeMatchingEvents;
        if (mergeChanged) {
          (this as _LiveMatchesForjaLive)._invalidateLiveMatchesGridCache();
        }
      });
    }
    final lazyCatalog =
        (this as _LiveMatchesForjaLive)._usesForjaLiveLazyCatalog;
    _s._loadGen++;
    (this as _LiveMatchesForjaLive)._resetForjaLiveCatalogState(
      clearMatches: !lazyCatalog,
    );
    setState(() {
      (this as _LiveMatchesForjaLive)._invalidateLiveMatchesGridCache();
      _s._loading = !lazyCatalog;
      if (lazyCatalog) _s._forjaLiveCatalogHydrating = true;
      _s._error = null;
      _s._sportFilter = 'all';
      if (!lazyCatalog) {
        _s._iframeCatalogStreams = [];
        _s._streamedMatches = [];
        _s._espnGames = [];
        _s._sports = [];
      } else {
        final oldCtrl = _s._tabController;
        _s._tabController = null;
        _s._sports = [];
        (this as _LiveMatchesForjaLive)._deferTabControllerDispose(oldCtrl);
      }
    });
    ref.invalidate(liveMatchesPrimaryLoadProvider);
    if ((this as _LiveMatchesForjaLive)._usesForjaLiveLazyCatalog) {
      (this as _LiveMatchesForjaLive)._kickForjaLiveLazyCatalog(replace: true);
    }
  }

  void _applyPrimaryLoad(_LiveMatchesPrimaryLoad load) {
    final lazyCatalog =
        (this as _LiveMatchesForjaLive)._usesForjaLiveLazyCatalog;
    final forjaKeep = _s._streamedMatches.where((m) => m.isForjaLive).toList();
    final damiKeep =
        lazyCatalog ? _s._iframeCatalogStreams : const <_IframeCatalogStream>[];
    final oldCtrl = _s._tabController;
    setState(() {
      (this as _LiveMatchesForjaLive)._invalidateLiveMatchesGridCache();
      _s._tabController = null;
      _s._iframeCatalogStreams = lazyCatalog ? damiKeep : const [];
      _s._streamedMatches = forjaKeep;
      _s._espnGames = load.espnGames;
      _s._sports = load.sports;
      _s._loading = false;
      _s._error = null;
      _s._sportFilter = 'all';
    });
    (this as _LiveMatchesForjaLive)._deferTabControllerDispose(oldCtrl);
    if (!mounted) return;
    if ((this as _LiveMatchesForjaLive)._usesForjaLiveLazyCatalog &&
        (_s._streamedMatches.any((m) => m.isForjaLive) ||
            _s._iframeCatalogStreams.isNotEmpty)) {
      (this as _LiveMatchesForjaLive)._rebuildSportTabsFromCurrentMatches();
    } else {
      final cats = load.sports;
      if (cats.length > 1) {
        final newCtrl = TabController(length: cats.length + 1, vsync: _s);
        newCtrl.addListener(() {
          if (!newCtrl.indexIsChanging) {
            final idx = newCtrl.index;
            _setSportFilter(idx == 0 ? 'all' : cats[idx - 1].id);
          }
        });
        setState(() => _s._tabController = newCtrl);
      } else {
        setState(() => _s._tabController = null);
      }
    }
    markShellTabFresh();
    _scheduleRestoreLiveMatchesTvFocus();
    if ((this as _LiveMatchesForjaLive)._usesForjaLiveLazyCatalog) {
      unawaited((this as _LiveMatchesForjaLive)._applyScheduleEnrichMerge());
    }
  }

  void _setSportFilter(String id) {
    setState(() {
      (this as _LiveMatchesForjaLive)._invalidateLiveMatchesGridCache();
      _s._sportFilter = id;
    });
  }

  List<_IframeCatalogStream> get _filteredIframeCatalog {
    var list = _s._iframeCatalogStreams
        .where(
          (s) => _includeInSportFilter(
            category: s.categoryName,
            isAlwaysOn: s.isAlwaysOn,
            sportFilter: _s._sportFilter,
          ),
        )
        .toList();
    if (_applyTimeWindowFilter) {
      list = list
          .where(
            (s) => _iframeCatalogInScheduleFilter(
              s,
              status: _s._scheduleStatus,
              horizon: _s._scheduleHorizon,
            ),
          )
          .toList();
    }
    return _sortIframeCatalogLiveFirst(_mergeIframeCatalogRows(list));
  }

  List<_StreamedMatch> _streamedMatchesSportAndTimeFiltered() {
    var list = _s._streamedMatches
        .where(
          (m) => _includeInSportFilter(
            category: m.category,
            isAlwaysOn: m.isAlwaysOn,
            sportFilter: _s._sportFilter,
          ),
        )
        .toList();
    if (_applyTimeWindowFilter) {
      list = list
          .where(
            (m) => _streamedMatchInScheduleFilter(
              m,
              status: _s._scheduleStatus,
              horizon: _scheduleHorizonForCatalogMatch(
                m,
                horizon: _s._scheduleHorizon,
                catalogFilter: _s._forjaLivePluginFilter,
              ),
            ),
          )
          .toList();
    }
    return list;
  }

  List<_StreamedMatch> get _filteredStreamed => _mergeStreamedCatalogRows(
        _sortStreamedLiveFirst(_streamedMatchesSportAndTimeFiltered()),
        mergeMatching: _s._mergeMatchingEvents,
      );
}
