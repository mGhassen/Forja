part of 'live_matches_screen.dart';

mixin _LiveMatchesData on State<LiveMatchesScreen> {
  _LiveMatchesScreenState get _s => this as _LiveMatchesScreenState;

  void _focusTopBarItem(int index) {
    if (index == _LiveMatchesScreenState._topBarServersIndex) {
      ShellTvFocusCoordinator.focusRowItem(
        _LiveMatchesScreenState._tabId,
        _LiveMatchesScreenState._topBarRowId,
        _LiveMatchesScreenState._topBarServersIndex,
      );
      return;
    }
    final node = index == _LiveMatchesScreenState._topBarViewIndex
        ? _s._viewFocusNode
        : _s._refreshFocusNode;
    if (!node.canRequestFocus) return;
    node.requestFocus();
    ShellTvFocusCoordinator.saveFocus(
      _LiveMatchesScreenState._tabId,
      ShellTvFocusMemory(zone: ShellTvZone.topBar, node: node),
    );
  }

  Future<void> _selectServer(_LiveMatchesServer server) async {
    if (server == _s._server) return;
    setState(() => _s._server = server);
    await _load();
  }

  void _openServerPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LiveMatchesServerSheet(
        current: _s._server,
        onSelected: (server) {
          Navigator.pop(context);
          unawaited(_selectServer(server));
        },
      ),
    );
  }

  Widget _serversTopBarButton() {
    return ForjaShellChip(
      label: 'Servers',
      icon: Icons.dns_rounded,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      fontSize: 11.5,
      listIndex: _LiveMatchesScreenState._topBarServersIndex,
      tvTabId: _LiveMatchesScreenState._tabId,
      tvRowId: _LiveMatchesScreenState._topBarRowId,
      onTap: _openServerPicker,
      onLeftEdge: shellTvChipLeftEdge(
        context,
        tabId: _LiveMatchesScreenState._tabId,
        rowId: _LiveMatchesScreenState._topBarRowId,
        index: _LiveMatchesScreenState._topBarServersIndex,
      ),
      onRightEdge: () => _focusTopBarItem(_LiveMatchesScreenState._topBarRefreshIndex),
      onDownEdge: _topBarDownEdge,
    );
  }

  void _topBarDownEdge() {
    if (_s._hasSportChips) {
      final chip = ShellTvFocusCoordinator.rowHandle(_LiveMatchesScreenState._tabId, _LiveMatchesScreenState._chipRowId);
      if (chip != null && chip.itemCount > 0) {
        final idx = chip.lastFocusedIndex.clamp(0, chip.itemCount - 1);
        ShellTvFocusCoordinator.focusRowItem(_LiveMatchesScreenState._tabId, _LiveMatchesScreenState._chipRowId, idx);
        return;
      }
    }
    _restoreLiveMatchesTvFocus();
  }

  VoidCallback? _gridUpEdge(BuildContext context, int index, int crossCount) {
    if (!_s._tvFocus(context) || index ~/ crossCount != 0) return null;
    return () => _focusTopBarItem(_LiveMatchesScreenState._topBarServersIndex);
  }

  bool _focusGridItem(int index) {
    final handle = ShellTvFocusCoordinator.rowHandle(_LiveMatchesScreenState._tabId, _LiveMatchesScreenState._gridRowId);
    if (handle == null || handle.itemCount <= 0) return false;
    final idx = index.clamp(0, handle.itemCount - 1);
    return ShellTvFocusCoordinator.focusRowItem(_LiveMatchesScreenState._tabId, _LiveMatchesScreenState._gridRowId, idx);
  }

  bool _restoreLiveMatchesTvFocus() {
    bool tryFocus() {
      final handle = ShellTvFocusCoordinator.rowHandle(_LiveMatchesScreenState._tabId, _LiveMatchesScreenState._gridRowId);
      if (handle == null || handle.itemCount <= 0) return false;
      final idx = handle.lastFocusedIndex.clamp(0, handle.itemCount - 1);
      return _focusGridItem(idx);
    }

    if (tryFocus()) return true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ShellTvFocus.currentNavTabId != _LiveMatchesScreenState._tabId) return;
      tryFocus();
    });
    return false;
  }

  void _registerGridRow(int itemCount) {
    shellTvRegisterRow(
      tabId: _LiveMatchesScreenState._tabId,
      rowId: _LiveMatchesScreenState._gridRowId,
      sortOrder: _s._gridSortOrder,
      itemCount: itemCount,
      onFocusUp: () => _focusTopBarItem(_LiveMatchesScreenState._topBarServersIndex),
    );
  }

  Future<void> _load() async {
    setState(() {
      _s._loading = true;
      _s._error = null;
      _s._sportFilter = 'all';
      // Fresh data rebuilds the time canvas — land on now again, not the
      // previous pixel offset (which maps to a wrong clock after reload).
      _s._timelineAutoScrolled = false;
    });
    // Drop the stale offset immediately so a remount can't flash Dec/epoch junk.
    if (_s._timelineScrollController.hasClients) {
      _s._timelineScrollController.jumpTo(0);
    }
    if (_s._server == _LiveMatchesServer.all) {
      await _loadAll();
      return;
    }
    if (_s._server == _LiveMatchesServer.ppv) {
      await _loadDamiTv();
      return;
    }
    if (_s._server == _LiveMatchesServer.streamed) {
      await _loadStreamed();
      return;
    }
    if (_s._server == _LiveMatchesServer.cdnLive) {
      await _loadCdn();
      return;
    }
  }

  /// Sport chip / tab change rebuilds the time canvas — re-land on now.
  void _setSportFilter(String id) {
    setState(() {
      _s._sportFilter = id;
      _s._timelineAutoScrolled = false;
    });
  }

  void _applySportTabs(List<_Sport> cats) {
    final oldCtrl = _s._tabController;
    setState(() {
      _s._tabController = null;
      _s._sports = cats;
      _s._loading = false;
    });
    oldCtrl?.dispose();
    if (!mounted) return;
    final newCtrl = TabController(length: cats.length + 1, vsync: _s);
    newCtrl.addListener(() {
      if (!newCtrl.indexIsChanging) {
        final idx = newCtrl.index;
        _setSportFilter(idx == 0 ? 'all' : cats[idx - 1].id);
      }
    });
    setState(() => _s._tabController = newCtrl);
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        _fetchDamiTvStreams().catchError((_) => <_DamiTvStream>[]),
        _fetchStreamedMatches().catchError((_) => <_StreamedMatch>[]),
        _fetchCdnChannels().catchError((_) => <_CdnChannel>[]),
        _fetchCdnSports().catchError((_) => <_CdnSportEvent>[]),
      ]);
      final ppvStreams = results[0] as List<_DamiTvStream>;
      final streamedMatches = results[1] as List<_StreamedMatch>;
      final cdnChannels = results[2] as List<_CdnChannel>;
      final cdnSports = results[3] as List<_CdnSportEvent>;

      final seenCats = <String>{};
      final cats = <_Sport>[];
      void addCat(String raw) {
        final id = _normalizeSportId(raw);
        if (id.isEmpty || !seenCats.add(id)) return;
        cats.add(_Sport(id: id, name: _sportDisplayName(raw, id)));
      }

      for (final s in ppvStreams) {
        addCat(s.categoryName);
      }
      for (final m in streamedMatches) {
        addCat(m.category);
      }
      for (final e in cdnSports) {
        // Unified chips are sport-level; CDN tournaments stay for CDN-only mode.
        if (e.sport.isNotEmpty) addCat(e.sport);
      }
      cats.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _s._damiTvStreams = ppvStreams;
        _s._streamedMatches = streamedMatches;
        _s._cdnChannels = cdnChannels;
        _s._cdnSports = cdnSports;
      });
      _applySportTabs(cats);
    } catch (e) {
      if (mounted) {
        setState(() {
          _s._loading = false;
          _s._error = e.toString();
        });
      }
    }
  }

  Future<void> _loadDamiTv() async {
    try {
      final streams = await _fetchDamiTvStreams();
      final seenCats = <String>{};
      final cats = <_Sport>[];
      for (final s in streams) {
        if (s.categoryName.isNotEmpty && seenCats.add(s.categoryName)) {
          cats.add(_Sport(id: s.categoryName, name: s.categoryName));
        }
      }
      if (mounted) {
        final oldCtrl = _s._tabController;
        setState(() {
          _s._tabController = null;
          _s._damiTvStreams = streams;
          _s._sports = cats;
          _s._loading = false;
        });
        oldCtrl?.dispose();
        final newCtrl = TabController(length: cats.length + 1, vsync: _s);
        newCtrl.addListener(() {
          if (!newCtrl.indexIsChanging) {
            final idx = newCtrl.index;
            _setSportFilter(idx == 0 ? 'all' : cats[idx - 1].id);
          }
        });
        if (mounted) setState(() => _s._tabController = newCtrl);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _s._loading = false;
          _s._error = e.toString();
        });
      }
    }
  }

  Future<void> _loadStreamed() async {
    try {
      final results = await Future.wait([
        _fetchStreamedSports(),
        _fetchStreamedMatches(),
      ]);
      final sports = results[0] as List<_Sport>;
      final matches = results[1] as List<_StreamedMatch>;

      final catsInMatches = matches.map((m) => m.category).toSet();
      var cats = sports.where((s) => catsInMatches.contains(s.id)).toList();
      if (cats.isEmpty) {
        final seen = <String>{};
        cats = [];
        for (final m in matches) {
          if (m.category.isNotEmpty && seen.add(m.category)) {
            cats.add(_Sport(id: m.category, name: m.categoryLabel));
          }
        }
      }

      if (mounted) {
        final oldCtrl = _s._tabController;
        setState(() {
          _s._tabController = null;
          _s._streamedMatches = matches;
          _s._sports = cats;
          _s._loading = false;
        });
        oldCtrl?.dispose();
        final newCtrl = TabController(length: cats.length + 1, vsync: _s);
        newCtrl.addListener(() {
          if (!newCtrl.indexIsChanging) {
            final idx = newCtrl.index;
            _setSportFilter(idx == 0 ? 'all' : cats[idx - 1].id);
          }
        });
        if (mounted) setState(() => _s._tabController = newCtrl);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _s._loading = false;
          _s._error = e.toString();
        });
      }
    }
  }

  Future<void> _loadCdn() async {
    try {
      final results = await Future.wait([
        _fetchCdnChannels(),
        _fetchCdnSports(),
      ]);
      final channels = results[0] as List<_CdnChannel>;
      final sports = results[1] as List<_CdnSportEvent>;

      // Build categories from sports
      final seenCats = <String>{};
      final cats = <_Sport>[];
      for (final s in sports) {
        if (s.tournament.isNotEmpty && seenCats.add(s.tournament)) {
          cats.add(_Sport(id: s.tournament, name: s.tournament));
        }
      }

      if (mounted) {
        final oldCtrl = _s._tabController;
        setState(() {
          _s._tabController = null;
          _s._cdnChannels = channels;
          _s._cdnSports = sports;
          _s._sports = cats;
          _s._loading = false;
        });
        oldCtrl?.dispose();
        final newCtrl = TabController(length: cats.length + 1, vsync: _s);
        newCtrl.addListener(() {
          if (!newCtrl.indexIsChanging) {
            final idx = newCtrl.index;
            _setSportFilter(idx == 0 ? 'all' : cats[idx - 1].id);
          }
        });
        if (mounted) setState(() => _s._tabController = newCtrl);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _s._loading = false;
          _s._error = e.toString();
        });
      }
    }
  }

  /// True when the 24/7 chip is selected (normalized id).
  bool get _showing247 => _normalizeSportId(_s._sportFilter) == '24-7';

  /// Hide 24/7 streams from All / other sports; show them only on the 24/7 chip.
  bool _includeSportCategory(String raw) {
    if (_is247Sport(raw)) return _showing247;
    return _sportIdsMatch(raw, _s._sportFilter);
  }

  List<_DamiTvStream> get _filteredDamiTv => _sortDamiTvLiveFirst(
    _s._damiTvStreams
        .where((s) => _includeSportCategory(s.categoryName))
        .toList(),
  );

  List<_StreamedMatch> get _filteredStreamed => _sortStreamedLiveFirst(
    _s._streamedMatches
        .where((m) => _includeSportCategory(m.category))
        .toList(),
  );

  List<_CdnSportEvent> get _filteredCdnSports => _sortCdnSportsLiveFirst(
    _s._cdnSports.where((s) {
      // All-servers uses sport buckets; CDN-only still filters by tournament.
      if (_s._server == _LiveMatchesServer.all) {
        return _includeSportCategory(s.sport);
      }
      if (_s._sportFilter == 'all') {
        // CDN-only: tournaments are not the 24/7 sport chip — keep all.
        return true;
      }
      return s.tournament == _s._sportFilter;
    }).toList(),
  );
}
