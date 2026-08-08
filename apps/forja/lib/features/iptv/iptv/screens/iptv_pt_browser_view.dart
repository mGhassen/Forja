part of 'iptv_pt_screen.dart';

class _BrowserView extends StatefulWidget {
  final IptvController ctrl;
  final bool compact;
  final bool wide;
  final bool embedded;
  const _BrowserView({
    required this.ctrl,
    required this.compact,
    required this.wide,
    this.embedded = false,
  });

  @override
  State<_BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends State<_BrowserView> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _openPortalFocus = FocusNode(debugLabel: 'iptv-open-portal');
  final FocusNode _reloadEmptyFocus = FocusNode(
    debugLabel: 'iptv-streams-reload',
  );
  final ScrollController _categoryScroll = ScrollController();
  final ScrollController _streamScroll = ScrollController();
  /// Last grid metrics for scrolling a stream tile into view before focus.
  int _streamCrossAxisCount = 1;
  double _streamTileExtent = 120;
  double _streamMainGap = 10;
  Timer? _scrollSettleTimer;
  /// TV: after settle, new tiles may decode logos. Already-shown ids stay on.
  bool _allowNewLogos = false;
  final Set<String> _revealedLogoIds = <String>{};
  static const _logoSettleDelay = Duration(milliseconds: 500);
  /// Last stream-list offset — gate new logos only when this actually moves.
  double? _lastStreamScrollOffset;
  bool _didInitialFocus = false;
  bool _didRequestReloadFocus = false;
  bool _wasLoading = false;
  bool _wasPortalPanelOpen = false;
  String _lastBrowserSearch = '';
  /// TV category rail focus — channel pane stays on the last OK/→ group until
  /// this matches [IptvController.browserSelectedCategoryId].
  String? _tvFocusedCategoryId;
  bool _tvCategoryRailFocused = false;
  /// TV floating reorder — sticky on this category until OK / Back / ← drops.
  String? _tvFloatingCategoryId;
  bool _floatingReorderKeysBound = false;
  /// Swallow OK KeyUp after hold-to-enter — must not drop the float.
  bool _swallowFloatingActivateUp = false;
  /// Category pin has focus — channel pane must not take →.
  bool _tvCategoryPinFocused = false;

  bool get _searchOpen => widget.ctrl.browserSearchOpen;
  bool get _needsPortal => widget.ctrl.activePortal == null;
  bool get _tvFloatingReorder => _tvFloatingCategoryId != null;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.ctrl.browserSearch;
    _lastBrowserSearch = widget.ctrl.browserSearch.trim();
    _wasLoading = widget.ctrl.isLoading;
    _wasPortalPanelOpen = widget.ctrl.portalPanelOpen;
    widget.ctrl.addListener(_onCtrlChanged);
    _streamScroll.addListener(_onStreamScrollForLogos);
    // Prefer this pageBack (scrolls the category rail) over the screen default.
    TvHeroActions.bind(
      'iptv',
      pageBack: _handleCatalogPageBack,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncInitialFocus();
      if (!mounted) return;
      if (iptvUseTvFocus(context)) {
        _bumpChannelLogoSettle();
      } else {
        setState(() => _allowNewLogos = true);
      }
    });
  }

  bool _handleCatalogPageBack() {
    // Pin focus / floating reorder own Back before streams → category.
    if (_CategorySidebarRowState.tryConsumeBack()) return true;
    if (_exitTvFloatingReorder()) return true;
    if (!iptvHandleCatalogPageBack(widget.ctrl)) return false;
    _scrollCategorySidebarToSelected();
    return true;
  }

  @override
  void dispose() {
    _unbindFloatingReorderKeys();
    widget.ctrl.removeListener(_onCtrlChanged);
    _streamScroll.removeListener(_onStreamScrollForLogos);
    _scrollSettleTimer?.cancel();
    _categoryScroll.dispose();
    _streamScroll.dispose();
    _searchFocus.dispose();
    _openPortalFocus.dispose();
    _reloadEmptyFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _bindFloatingReorderKeys() {
    if (_floatingReorderKeysBound) return;
    HardwareKeyboard.instance.addHandler(_onFloatingReorderKey);
    _floatingReorderKeysBound = true;
    ShellTvHoldAccel.reset();
  }

  void _unbindFloatingReorderKeys() {
    if (!_floatingReorderKeysBound) return;
    HardwareKeyboard.instance.removeHandler(_onFloatingReorderKey);
    _floatingReorderKeysBound = false;
    ShellTvHoldAccel.reset();
  }

  void _syncFloatingReorderKeys() {
    if (_tvFloatingReorder && iptvUseTvFocus(context)) {
      _bindFloatingReorderKeys();
    } else {
      _unbindFloatingReorderKeys();
    }
  }

  /// Enter / leave TV floating category reorder (parent owns ↑↓ + drop keys).
  void _setTvFloatingCategory(String? categoryId) {
    if (_tvFloatingCategoryId == categoryId) return;
    final prev = _tvFloatingCategoryId;
    // Arm swallow before setState/HW bind so the enter KeyUp cannot drop float.
    if (categoryId != null) {
      _swallowFloatingActivateUp = true;
    } else {
      _swallowFloatingActivateUp = false;
    }
    setState(() => _tvFloatingCategoryId = categoryId);
    _syncFloatingReorderKeys();
    if (categoryId != null) {
      // Stay put on enter — only scroll once dragging reaches the 2nd slot.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _tvFloatingCategoryId != categoryId) return;
        _focusFloatingCategoryRow();
      });
      return;
    }
    if (prev == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tvFloatingReorder) return;
      final cats = widget.ctrl.browserSidebarCategories;
      final idx = cats.indexWhere((c) => c.id == prev);
      if (idx >= 0) iptvFocusRowItem('browser-categories', idx);
    });
  }

  bool _exitTvFloatingReorder() {
    if (!_tvFloatingReorder) return false;
    _setTvFloatingCategory(null);
    return true;
  }

  /// Hardware keys while floating — survives focus flicker to channels / neighbors.
  bool _onFloatingReorderKey(KeyEvent event) {
    if (!_tvFloatingReorder) return false;
    if (!iptvUseTvFocus(context)) return false;

    final key = event.logicalKey;
    final up = key == LogicalKeyboardKey.arrowUp;
    final down = key == LogicalKeyboardKey.arrowDown;
    final left = key == LogicalKeyboardKey.arrowLeft;
    final right = key == LogicalKeyboardKey.arrowRight;
    final activate = shellTvIsActivateLogicalKey(key);
    if (!up && !down && !left && !right && !activate) return false;

    // Drop on a fresh OK KeyDown. Swallow KeyUp from hold-to-enter (and all
    // other activate KeyUps) — never drop on KeyUp or the enter release kills float.
    if (activate) {
      if (event is KeyUpEvent) {
        if (_swallowFloatingActivateUp) {
          _swallowFloatingActivateUp = false;
        }
        return true;
      }
      if (event is KeyDownEvent && !_swallowFloatingActivateUp) {
        _exitTvFloatingReorder();
      }
      return true;
    }
    if (left) {
      if (event is KeyDownEvent) _exitTvFloatingReorder();
      return true;
    }
    if (right) {
      // Let the focused row handle → (focus pin when available).
      return false;
    }

    // One category per KeyDown / KeyRepeat — never HoldAccel strides.
    if (event is KeyUpEvent) {
      ShellTvHoldAccel.reset();
      return true;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      ShellTvHoldAccel.reset();
      _tvMoveFloatingCategory(up ? -1 : 1);
      return true;
    }
    return true;
  }

  void _tvMoveFloatingCategory(int delta) {
    final id = _tvFloatingCategoryId;
    if (id == null || !widget.ctrl.canReorderLiveCategories) return;
    final cats = widget.ctrl.browserSidebarCategories;
    final movable = [
      for (final c in cats)
        if (!IptvLiveCatalog.isSyntheticId(c.id)) c,
    ];
    final oldIndex = movable.indexWhere((c) => c.id == id);
    if (oldIndex < 0) return;
    final newIndex = (oldIndex + delta).clamp(0, movable.length - 1);
    if (newIndex == oldIndex) return;

    // Predict post-move list index + scroll *before* notify paints — jumping
    // in a post-frame callback flashes the row at the wrong viewport slot.
    final listIdx = cats.indexWhere((c) => c.id == id);
    final predictedListIdx =
        listIdx < 0 ? -1 : (listIdx + (newIndex - oldIndex));
    final scrollTarget = predictedListIdx < 0
        ? null
        : _floatingMoveScrollTarget(
            listIndex: predictedListIdx,
            delta: delta,
          );

    unawaited(widget.ctrl.reorderLiveCategories(oldIndex, newIndex));
    if (scrollTarget != null && _categoryScroll.hasClients) {
      final max = _categoryScroll.position.maxScrollExtent;
      final target = scrollTarget.clamp(0.0, max);
      if ((_categoryScroll.offset - target).abs() > 0.5) {
        _categoryScroll.jumpTo(target);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tvFloatingCategoryId != id) return;
      // Re-assert if rebuild / ensureVisible nudged the offset.
      if (scrollTarget != null && _categoryScroll.hasClients) {
        final max = _categoryScroll.position.maxScrollExtent;
        final target = scrollTarget.clamp(0.0, max);
        if ((_categoryScroll.offset - target).abs() > 0.5) {
          _categoryScroll.jumpTo(target);
        }
      }
      _focusFloatingCategoryRow();
    });
  }

  /// Pin without scrolling the rail (item may move to top of movable list).
  void _toggleCategoryPin(String categoryId) {
    final cats = widget.ctrl.browserSidebarCategories;
    final slot = cats.indexWhere((c) => c.id == categoryId);
    final offset =
        _categoryScroll.hasClients ? _categoryScroll.offset : null;
    unawaited(widget.ctrl.toggleLiveCategoryPin(categoryId));
    void restoreScrollAndFocus() {
      if (!mounted) return;
      if (offset != null && _categoryScroll.hasClients) {
        final target = offset.clamp(
          0.0,
          _categoryScroll.position.maxScrollExtent,
        );
        if ((_categoryScroll.offset - target).abs() > 0.5) {
          _categoryScroll.jumpTo(target);
        }
      }
      // Pinned row moved to the front — keep focus on this viewport slot.
      if (slot >= 0 &&
          slot < widget.ctrl.browserSidebarCategories.length) {
        iptvFocusRowItem('browser-categories', slot);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      restoreScrollAndFocus();
      // Second frame: fight showOnScreen after sliver re-layout.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        restoreScrollAndFocus();
      });
    });
  }

  void _focusFloatingCategoryRow() {
    final id = _tvFloatingCategoryId;
    if (id == null) return;
    final idx = widget.ctrl.browserSidebarCategories
        .indexWhere((c) => c.id == id);
    if (idx < 0) return;
    iptvFocusRowItem('browser-categories', idx);
  }

  /// Scroll offset to pin [listIndex] at the edge band, or null if already in band.
  ///
  /// Dragging up — **2nd** visible row (first at list top). Dragging down —
  /// 2nd-from-bottom (last at list end). Mid-viewport moves return null.
  double? _floatingMoveScrollTarget({
    required int listIndex,
    required int delta,
  }) {
    if (!_categoryScroll.hasClients || listIndex < 0) return null;
    final rowH = _categoryRowExtent(widget.compact);
    final pos = _categoryScroll.position;
    final max = pos.maxScrollExtent;
    final viewH = pos.viewportDimension;
    final current = pos.pixels;
    final itemTop = _categoryListPadV + listIndex * rowH;

    late final double target;
    if (delta < 0) {
      target = (itemTop - rowH).clamp(0.0, max);
      if (current <= target + 0.5) return null;
    } else {
      target = (itemTop - viewH + 2 * rowH).clamp(0.0, max);
      if (current >= target - 0.5) return null;
    }
    return target;
  }

  void _onCtrlChanged() {
    if (!mounted) return;
    final loading = widget.ctrl.isLoading;
    final finishedLoad = _wasLoading && !loading;
    if (loading) {
      _didRequestReloadFocus = false;
    }
    _wasLoading = loading;
    final panelOpen = widget.ctrl.portalPanelOpen;
    final panelClosed = _wasPortalPanelOpen && !panelOpen;
    _wasPortalPanelOpen = panelOpen;
    final search = widget.ctrl.browserSearch.trim();
    final clearedSearch = _lastBrowserSearch.isNotEmpty && search.isEmpty;
    _lastBrowserSearch = search;
    if (_tvFloatingCategoryId != null &&
        !widget.ctrl.canReorderLiveCategories) {
      _setTvFloatingCategory(null);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (clearedSearch) {
        _scrollCategorySidebarToSelected();
      }
      if (panelClosed && !_needsPortal) {
        _focusCatalogGroup();
        return;
      }
      if (_needsPortal) {
        // Don't steal focus while the portals panel is open.
        if (!widget.ctrl.portalPanelOpen && !_openPortalFocus.hasFocus) {
          _focusOpenPortalButton();
        }
        return;
      }
      if (widget.ctrl.portalPanelOpen) return;
      if (loading) return;
      if (finishedLoad || !_didInitialFocus) {
        if (widget.ctrl.categories.isNotEmpty ||
            widget.ctrl.browserAllStreams.isNotEmpty) {
          _focusCatalogGroup();
        }
      }
    });
  }

  static double _categoryRowExtent(bool compact) => compact ? 42.0 : 46.0;

  /// Matches [SliverPadding] vertical on the category rail.
  static const _categoryListPadV = 10.0;

  /// Warm neighbors so D-pad ↑/↓ usually hits a mounted node (portals pattern).
  static const _categoryScrollCacheRows = 14;

  void _scrollCategorySidebarToSelected() {
    var tries = 0;
    void attempt() {
      if (!mounted) return;
      if (!_categoryScroll.hasClients) {
        if (tries++ < 4) {
          WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        }
        return;
      }
      final cats = widget.ctrl.browserSidebarCategories;
      final selected = widget.ctrl.browserSelectedCategoryId;
      if (selected == null) return;
      final idx = cats.indexWhere((c) => c.id == selected);
      if (idx < 0) return;
      final rowH = _categoryRowExtent(widget.compact);
      // Leave 3 rows above so the selection lands as the 4th visible category.
      const keepAbove = 3;
      final target = (_categoryListPadV + (idx - keepAbove) * rowH).clamp(
        0.0,
        _categoryScroll.position.maxScrollExtent,
      );
      _categoryScroll.jumpTo(target);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  void _scrollStreamsToIndex(int index) {
    if (!_streamScroll.hasClients || index < 0) return;
    final cross = _streamCrossAxisCount.clamp(1, 999);
    final row = widget.compact ? index : index ~/ cross;
    final extent = _streamTileExtent + _streamMainGap;
    final target = (row * extent).clamp(
      0.0,
      _streamScroll.position.maxScrollExtent,
    );
    if ((_streamScroll.offset - target).abs() < 0.5) return;
    _streamScroll.jumpTo(target);
  }

  /// After leaving the player: select category, scroll, focus the channel tile.
  void _restoreFocusAfterPlayback(IptvStream stream) {
    // Keep Favorites / Already watched / search hits when the channel is still
    // visible; otherwise open the channel's real group.
    final alreadyVisible =
        _filteredStreams.any((x) => x.streamId == stream.streamId);
    if (!alreadyVisible) {
      final catId = stream.categoryId;
      if (catId.isNotEmpty) {
        widget.ctrl.selectBrowserCategory(catId);
      }
    }
    final selected = widget.ctrl.browserSelectedCategoryId;
    if (iptvUseTvFocus(context) && selected != null) {
      setState(() {
        _tvFocusedCategoryId = selected;
        _tvCategoryRailFocused = false;
      });
    }
    _scrollCategorySidebarToSelected();

    if (!iptvUseTvFocus(context)) return;

    var tries = 0;
    var scrolledFor = -1;
    void attempt() {
      if (!mounted) return;
      // Overlay ExcludeFocus must lift before catalog tiles can take focus.
      if (ShellBus.shellOverlayHasPage.value ||
          ShellBus.playerSurfaceActive.value) {
        if (tries++ < 24) {
          WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        }
        return;
      }
      final list = _filteredStreams;
      final idx = list.indexWhere((x) => x.streamId == stream.streamId);
      if (idx < 0) {
        iptvFocusBrowserCategories(widget.ctrl);
        return;
      }
      // Scroll first; lazy grid builds the tile on the next frame.
      if (scrolledFor != idx) {
        _scrollStreamsToIndex(idx);
        scrolledFor = idx;
        tries++;
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        return;
      }
      if (iptvFocusBrowserStreamAt(idx)) return;
      // Node still missing — nudge scroll again and retry.
      scrolledFor = -1;
      if (tries++ < 24) {
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
      } else {
        iptvFocusBrowserCategories(widget.ctrl);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  void _syncInitialFocus() {
    if (!mounted) return;
    if (_needsPortal) {
      _focusOpenPortalButton();
    } else if (!widget.ctrl.isLoading) {
      _focusCatalogGroup();
    }
  }

  void _focusOpenPortalButton() {
    if (!_openPortalFocus.canRequestFocus) return;
    _openPortalFocus.requestFocus();
    _didInitialFocus = false;
  }

  void _focusCatalogGroup() {
    if (!iptvFocusFirstPortalGroup(widget.ctrl)) {
      if (widget.ctrl.browserSidebarCategories.isEmpty) {
        iptvFocusRowItem('browser-streams', 0);
      }
    }
    _didInitialFocus = true;
  }

  /// Commit a category for the channel pane. On TV, OK / → also moves focus
  /// into streams; ↑/↓ alone must not call this (avoids logo thrash).
  void _commitBrowserCategory(String categoryId, {required bool enterStreams}) {
    final ctrl = widget.ctrl;
    final prev = ctrl.browserSelectedCategoryId;
    // Clear before select so the rebuild does not paint old reveals.
    if (prev != categoryId) {
      iptvResetBrowserStreamsFocusMemory();
      _revealedLogoIds.clear();
      _allowNewLogos = false;
    }
    ctrl.selectBrowserCategory(categoryId);
    if (prev != categoryId) {
      _bumpChannelLogoSettle(hide: true);
    }
    if (iptvUseTvFocus(context)) {
      setState(() {
        _tvFocusedCategoryId = categoryId;
        _tvCategoryRailFocused = !enterStreams;
      });
    }
    if (!enterStreams || !iptvUseTvFocus(context)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      iptvFocusRowItem('browser-streams');
    });
  }

  void _onCategoryTvFocus(String categoryId, bool focused) {
    if (!iptvUseTvFocus(context)) return;
    // Floating reorder: ignore neighbor focus flicker from list rebuilds.
    if (_tvFloatingReorder) {
      if (focused && categoryId == _tvFloatingCategoryId) {
        _tvFocusedCategoryId = categoryId;
        _tvCategoryRailFocused = true;
      }
      return;
    }
    final selected = widget.ctrl.browserSelectedCategoryId;
    final wasPending = _tvCategoryRailFocused &&
        _tvFocusedCategoryId != null &&
        _tvFocusedCategoryId != selected;

    if (focused) {
      final nowPending = categoryId != selected;
      // Holding ↑/↓ across unopened groups: pane already shows "Press OK" —
      // skip full browser rebuild (was fighting fixed-extent scroll).
      if (wasPending && nowPending && _tvCategoryRailFocused) {
        _tvFocusedCategoryId = categoryId;
        return;
      }
      setState(() {
        _tvFocusedCategoryId = categoryId;
        _tvCategoryRailFocused = true;
      });
      return;
    }

    if (_tvFocusedCategoryId != categoryId) return;
    setState(() => _tvCategoryRailFocused = false);
  }

  /// While D-pad is on an unopened group, keep logos off the channel pane.
  bool get _tvCategoryPendingCommit {
    if (!iptvUseTvFocus(context) || !_tvCategoryRailFocused) return false;
    final focused = _tvFocusedCategoryId;
    if (focused == null) return false;
    return focused != widget.ctrl.browserSelectedCategoryId;
  }

  @override
  void didUpdateWidget(covariant _BrowserView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ctrl.browserSearchOpen && !oldWidget.ctrl.browserSearchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
    if (!widget.ctrl.browserSearchOpen && _searchCtrl.text.isNotEmpty) {
      _searchCtrl.clear();
    }
  }

  void _openSearch() {
    widget.ctrl.openBrowserSearch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    widget.ctrl.closeBrowserSearch();
    _searchCtrl.clear();
    _searchFocus.unfocus();
    if (mounted) setState(() {});
  }

  void _clearSearchQuery() {
    _searchCtrl.clear();
    widget.ctrl.setBrowserSearch('');
    if (mounted) setState(() {});
  }

  void toggleSearch() {
    if (_searchOpen) {
      _closeSearch();
    } else {
      _openSearch();
    }
  }

  void _toggleSearch() => toggleSearch();

  bool _onScrollNotification(ScrollNotification n) {
    // Mobile visibility probes only — TV logos listen via [_streamScroll].
    if (iptvUseTvFocus(context)) return false;
    if (n is ScrollStartNotification) {
      _scrollSettleTimer?.cancel();
      widget.ctrl.cancelAllLazyChecks();
    } else if (n is ScrollEndNotification) {
      _scrollSettleTimer?.cancel();
      _scrollSettleTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() {});
      });
    }
    return false;
  }

  /// TV: stop admitting *new* logos when the channel list offset moves.
  void _onStreamScrollForLogos() {
    if (!mounted || !iptvUseTvFocus(context) || !_streamScroll.hasClients) {
      return;
    }
    final offset = _streamScroll.offset;
    final prev = _lastStreamScrollOffset;
    _lastStreamScrollOffset = offset;
    if (prev == null || (offset - prev).abs() < 0.5) return;
    _bumpChannelLogoSettle(hide: true);
  }

  /// Stream ids currently on screen (plus one row of cache).
  Iterable<String> _viewportStreamIds() {
    final list = _filteredStreams;
    if (list.isEmpty || !_streamScroll.hasClients) return const Iterable.empty();
    final pos = _streamScroll.position;
    final cross = _streamCrossAxisCount.clamp(1, 999);
    final extent = _streamTileExtent + _streamMainGap;
    if (extent <= 0 || pos.viewportDimension <= 0) {
      return const Iterable.empty();
    }
    const padRows = 1;
    final firstRow =
        ((pos.pixels / extent).floor() - padRows).clamp(0, 1 << 20);
    final lastRow =
        ((pos.pixels + pos.viewportDimension) / extent).ceil() + padRows;
    final first = firstRow * cross;
    final last = (lastRow * cross).clamp(0, list.length);
    if (first >= list.length) return const Iterable.empty();
    return [for (var i = first; i < last; i++) list[i].streamId];
  }

  /// After 500ms idle, admit logos for the viewport. [hide] stops *new* logos
  /// on scroll/category swap — already-revealed tiles stay painted.
  void _bumpChannelLogoSettle({bool hide = false}) {
    if (!iptvUseTvFocus(context)) return;
    _scrollSettleTimer?.cancel();
    if (hide) {
      if (_allowNewLogos) {
        _revealedLogoIds.addAll(_viewportStreamIds());
        setState(() => _allowNewLogos = false);
      }
    } else if (_allowNewLogos) {
      return;
    }
    _scrollSettleTimer = Timer(_logoSettleDelay, () {
      if (!mounted || _allowNewLogos) return;
      setState(() {
        _allowNewLogos = true;
        _revealedLogoIds.addAll(_viewportStreamIds());
      });
    });
  }

  /// Mobile health debounce listens to stream scroll; TV uses focus settle.
  bool get _useStreamScrollListener =>
      _LiveHealthProbe.usesScrollDebounce(context);

  bool _streamShowLogo(IptvStream stream) {
    if (!iptvUseTvFocus(context)) return true;
    return _revealedLogoIds.contains(stream.streamId) || _allowNewLogos;
  }

  String get _sectionTitle {
    switch (widget.ctrl.activeSection) {
      case IptvSection.live:
        return 'Live TV';
      case IptvSection.vod:
        return 'Movies';
      case IptvSection.series:
        return 'Series';
      default:
        return 'Browse';
    }
  }

  List<IptvCategory> get _filteredCategories =>
      widget.ctrl.browserSidebarCategories;

  List<IptvStream> get _filteredStreams {
    final ctrl = widget.ctrl;
    var s = ctrl.browserAllStreams;
    final cat = ctrl.browserSelectedCategoryId;
    final q = ctrl.browserSearch.trim().toLowerCase();

    if (q.isNotEmpty) {
      // Search is global across categories AND matches by stream name OR by
      // the stream's category name. Lookup table built once per filter pass.
      final catNameById = <String, String>{
        for (final c in ctrl.categories)
          if (!IptvLiveCatalog.isSyntheticId(c.id)) c.id: c.name.toLowerCase(),
      };
      s = s.where((x) {
        if (x.name.toLowerCase().contains(q)) return true;
        final key = x.categoryId.isEmpty
            ? IptvCatalogOrphans.uncategorizedId
            : x.categoryId;
        final cn = catNameById[key];
        return cn != null && cn.contains(q);
      }).toList();
      // Optional narrow: tapping a hit-category while searching scopes results.
      if (cat == IptvLiveCatalog.favoritesId) {
        s = s.where((x) => ctrl.isLiveFavorite(x.streamId)).toList();
      } else if (cat == IptvLiveCatalog.watchedId) {
        final watched = ctrl.liveWatchedIds.toSet();
        s = s.where((x) => watched.contains(x.streamId)).toList();
      } else if (cat != null && cat.isNotEmpty) {
        s = s
            .where((x) => IptvCatalogOrphans.streamMatchesCategory(x, cat))
            .toList();
      }
    } else if (cat == IptvLiveCatalog.favoritesId) {
      s = s.where((x) => ctrl.isLiveFavorite(x.streamId)).toList();
    } else if (cat == IptvLiveCatalog.watchedId) {
      final byId = {for (final x in s) x.streamId: x};
      s = [
        for (final id in ctrl.liveWatchedIds)
          if (byId.containsKey(id)) byId[id]!,
      ];
    } else if (cat != null && cat.isNotEmpty) {
      s = s
          .where((x) => IptvCatalogOrphans.streamMatchesCategory(x, cat))
          .toList();
    }

    if (ctrl.activeSection == IptvSection.live &&
        ctrl.liveOnly &&
        ctrl.aliveStreamIds.isNotEmpty) {
      s = s.where((x) => ctrl.aliveStreamIds.contains(x.streamId)).toList();
    }
    // Watched already uses MRU order; name sort still applies via liveSorted.
    return ctrl.liveSortedStreams(s);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    if (ctrl.activePortal == null) {
      return _buildChoosePortalEmpty(context);
    }

    final body = Column(
      children: [
        if (!widget.embedded)
          _PtAppBar(
            title: _sectionTitle,
            subtitle: ctrl.activePortal?.displayLabel,
            onBack: ctrl.back,
            actions: [
              IptvIconAction(
                tooltip: _searchOpen ? 'Close search' : 'Search channels',
                onPressed: _toggleSearch,
                icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                color: _searchOpen ? IptvShellStyle.accent : null,
              ),
              if (ctrl.activeSection != null) ...[
                IptvIconAction(
                  tooltip: 'Reload ${_sectionTitle}',
                  onPressed: ctrl.isLoading
                      ? null
                      : () => ctrl.reloadSection(ctrl.activeSection!),
                  icon: Icons.refresh_rounded,
                ),
                if (ctrl.activeSection == IptvSection.live)
                  IptvIconAction(
                    tooltip: ctrl.isVerifyingAlive
                        ? 'Stop alive check'
                        : 'Re-check all streams',
                    onPressed: ctrl.isVerifyingAlive
                        ? ctrl.stopAliveCheck
                        : ctrl.recheckAlive,
                    icon: ctrl.isVerifyingAlive
                        ? Icons.stop_circle_rounded
                        : Icons.verified_outlined,
                  ),
              ],
            ],
          ),
        if (!widget.embedded)
          ClipRect(
            child: AnimatedAlign(
              alignment: Alignment.topCenter,
              heightFactor: _searchOpen ? 1 : 0,
              duration: ShellTokens.isAndroidTvDevice
                  ? Duration.zero
                  : const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              child: _buildOverlaySearchBar(),
            ),
          ),
        Expanded(
          child: switch (ctrl.catalogLoadStyle) {
            IptvCatalogLoadStyle.verbose => _IptvCatalogProgressPanel(
              step: ctrl.catalogLoadStep,
              progress: ctrl.catalogLoadProgress,
            ),
            IptvCatalogLoadStyle.none =>
              ctrl.isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: IptvShellStyle.accent,
                      ),
                    )
                  : _buildContent(),
          },
        ),
      ],
    );

    if (widget.embedded) return body;
    return SafeArea(child: body);
  }

  Widget _buildChoosePortalEmpty(BuildContext context) {
    return iptvCatalogRow(
      rowId: 'iptv-open-portal',
      sortOrder: 0,
      itemCount: 1,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.satellite_alt_rounded,
                size: 72,
                color: IptvShellStyle.accent,
              ),
              const SizedBox(height: 20),
              Text(
                'Choose a portal',
                style: IptvShellStyle.pageTitle.copyWith(fontSize: 32),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a provider to browse Live TV, Movies, and Series.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white60,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),
              IptvPrimaryButton(
                icon: Icons.dns_rounded,
                label: 'Open portal',
                focusNode: _openPortalFocus,
                tvRowId: 'iptv-open-portal',
                tvItemIndex: 0,
                onPressed: widget.ctrl.openPortalPanel,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlaySearchBar() {
    final query = widget.ctrl.browserSearch;
    return ShellSearchBar(
      controller: _searchCtrl,
      focusNode: _searchFocus,
      query: query,
      wrapSafeArea: false,
      hintText: 'Search channels or categories…',
      onChanged: widget.ctrl.setBrowserSearch,
      onClear: _clearSearchQuery,
      onEscape: _closeSearch,
      clearSuffix: query.isNotEmpty
          ? iptvCloseButton(context, onTap: _clearSearchQuery)
          : null,
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final categoryWidth = widget.compact
            ? (constraints.maxWidth * 0.32).clamp(148.0, 188.0)
            : (widget.wide ? 228.0 : 200.0);

        return Row(
          children: [
            SizedBox(
              width: categoryWidth,
              child: _buildCategorySidebar(compact: widget.compact),
            ),
            Expanded(
              // Floating reorder owns the remote — channels must not steal focus.
              child: ExcludeFocus(
                excluding: _tvFloatingReorder || _tvCategoryPinFocused,
                child: _buildChannelPane(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChannelPane() {
    final ctrl = widget.ctrl;
    if (_tvCategoryPendingCommit) {
      return _buildPressOkToOpenCategory();
    }
    final useGuide =
        !widget.compact &&
        !ShellScope.metricsOf(context).usesTvDensity &&
        ctrl.activeSection == IptvSection.live &&
        ctrl.liveBrowseLayout == IptvLiveBrowseLayout.guide;
    if (useGuide) {
      final list = _filteredStreams;
      if (list.isEmpty) return _buildStreamsEmpty();
      return IptvEpgGuideView(
        key: ValueKey(
          'epg-${ctrl.activePortal?.key}-${ctrl.browserSelectedCategoryId}',
        ),
        ctrl: ctrl,
        streams: list,
        onPlay: _onStreamTap,
      );
    }
    return widget.compact ? _buildStreamRows() : _buildStreamGrid();
  }

  Widget _buildPressOkToOpenCategory() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'Press OK to open',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySidebar({bool compact = false}) {
    final ctrl = widget.ctrl;
    final rowExtent = _categoryRowExtent(compact);
    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: ForjaShellColors.borderSubtle)),
      ),
      child: Builder(
        builder: (_) {
          final cats = _filteredCategories;
          final live = ctrl.activeSection == IptvSection.live;
          final canReorder = ctrl.canReorderLiveCategories;
          final fixed = <IptvCategory>[];
          final movable = <IptvCategory>[];
          for (final c in cats) {
            if (IptvLiveCatalog.isSyntheticId(c.id)) {
              fixed.add(c);
            } else {
              movable.add(c);
            }
          }

          Widget rowFor(IptvCategory cat, int listIndex, {int? reorderIndex}) {
            final synthetic = IptvLiveCatalog.isSyntheticId(cat.id);
            final movableIndex = canReorder ? reorderIndex : null;
            final floating = _tvFloatingCategoryId == cat.id;
            return _CategorySidebarRow(
              key: ValueKey(cat.id),
              label: cat.name.isEmpty ? 'Uncategorized' : cat.name,
              icon: _iptvCategoryIcon(cat.id),
              selected: cat.id == ctrl.browserSelectedCategoryId,
              compact: compact,
              listIndex: listIndex,
              pinnable: live && !synthetic,
              pinned: ctrl.isLiveCategoryPinned(cat.id),
              onTogglePin: live && !synthetic
                  ? () => _toggleCategoryPin(cat.id)
                  : null,
              reorderIndex: movableIndex,
              floating: floating,
              onEnterFloating: movableIndex != null
                  ? () {
                      if (!mounted) return;
                      _setTvFloatingCategory(cat.id);
                    }
                  : null,
              onExitFloating: () {
                if (!mounted) return;
                if (_tvFloatingCategoryId == cat.id) {
                  _setTvFloatingCategory(null);
                }
              },
              // Parent HardwareKeyboard owns ↑/↓ while floating (id-based +
              // scroll pin). Non-null enables long-press OK; row Focus only
              // traps ↑/↓ (does not move — HW already did; both paths fire).
              onTvReorderUp: movableIndex != null
                  ? () => _tvMoveFloatingCategory(-1)
                  : null,
              onTvReorderDown: movableIndex != null
                  ? () => _tvMoveFloatingCategory(1)
                  : null,
              onTap: () => _commitBrowserCategory(cat.id, enterStreams: true),
              onUpEdge: listIndex == 0
                  ? () => iptvFocusRowItem(
                      'iptv-sections',
                      iptvActiveSectionShelfIndex(ctrl),
                    )
                  : null,
              // → opens channels when not pinnable (pinnable uses → for pin).
              onRightEdge: () =>
                  _commitBrowserCategory(cat.id, enterStreams: true),
              onTvFocusChange: (focused) =>
                  _onCategoryTvFocus(cat.id, focused),
              onPinFocusChange: (focused) {
                if (!mounted) return;
                if (_tvCategoryPinFocused == focused) return;
                setState(() => _tvCategoryPinFocused = focused);
              },
            );
          }

          Widget movableSliver() {
            Widget item(int i) {
              final listIndex = fixed.length + i;
              return rowFor(
                movable[i],
                listIndex,
                reorderIndex: canReorder ? i : null,
              );
            }

            if (!canReorder) {
              // Fixed extent: fast ↑ must not correct estimated heights (jitter).
              return SliverFixedExtentList(
                itemExtent: rowExtent,
                delegate: SliverChildBuilderDelegate(
                  (context, i) => item(i),
                  childCount: movable.length,
                  addAutomaticKeepAlives: false,
                ),
              );
            }
            return SliverReorderableList(
              itemCount: movable.length,
              itemExtent: rowExtent,
              proxyDecorator: _iptvCategoryReorderProxy,
              onReorderItem: (oldIndex, newIndex) {
                unawaited(ctrl.reorderLiveCategories(oldIndex, newIndex));
              },
              itemBuilder: (context, i) => item(i),
            );
          }

          // Remount when search changes so a prior scroll offset doesn't leave
          // the short filtered list floating mid-viewport.
          return iptvCatalogRow(
            rowId: 'browser-categories',
            sortOrder: 2,
            itemCount: cats.length,
            orientation: ShellTvRowOrientation.vertical,
            onFocusUp: () => iptvFocusRowItem(
              'iptv-sections',
              iptvActiveSectionShelfIndex(ctrl),
            ),
            child: IptvTvScrollbar(
              controller: _categoryScroll,
              child: CustomScrollView(
                key: ValueKey('browser-cats|${ctrl.browserSearch.trim()}'),
                controller: _categoryScroll,
                scrollCacheExtent: ScrollCacheExtent.pixels(
                  rowExtent * _categoryScrollCacheRows,
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      vertical: _categoryListPadV,
                    ),
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        if (fixed.isNotEmpty)
                          SliverFixedExtentList(
                            itemExtent: rowExtent,
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => rowFor(fixed[i], i),
                              childCount: fixed.length,
                              addAutomaticKeepAlives: false,
                            ),
                          ),
                        if (movable.isNotEmpty) movableSliver(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStreamGrid() {
    final list = _filteredStreams;
    if (list.isEmpty) {
      return _buildStreamsEmpty();
    }
    return LayoutBuilder(
      builder: (ctx, c) {
        final tv = ShellScope.metricsOf(ctx).usesTvDensity;
        // Desktop: ~165px target → more columns, smaller live tiles.
        final cardW = tv ? shellMovieCardWidth(ctx) : 180.0;
        final cardH = shellMovieCardHeight(ctx);
        final gap = tv ? shellMovieCardRowGap(ctx) : 10.0;
        final hPad = tv ? 8.0 : 16.0;
        final cross = tv
            ? ((c.maxWidth - hPad + gap) / (cardW + gap)).floor().clamp(1, 24)
            : (c.maxWidth ~/ cardW).clamp(2, 9);
        _streamCrossAxisCount = cross;
        _streamTileExtent = cardH;
        _streamMainGap = gap;
        // Fixed column count on TV so D-pad Left/Right match the visual row
        // (MaxCrossAxisExtent can disagree with our focus math and wrap).
        final grid = GridView.builder(
          controller: _streamScroll,
          padding: EdgeInsets.fromLTRB(8, 8, 12, 12),
          addAutomaticKeepAlives: false,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
            childAspectRatio: tv ? cardW / cardH : 0.9,
          ),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final stream = list[i];
            final atRightEdge = (i % cross) == cross - 1;
            return _StreamCard(
              stream: stream,
              ctrl: widget.ctrl,
              showLogo: _streamShowLogo(stream),
              onTvFocusGained: _bumpChannelLogoSettle,
              gridIndex: i,
              gridColumns: cross,
              onUpEdge: i < cross
                  ? iptvStreamUpEdge(widget.ctrl, index: i, columns: cross)
                  : null,
              onRightEdge: atRightEdge
                  ? (widget.ctrl.portalPanelOpen
                      ? () => iptvFocusPortalList(widget.ctrl)
                      : () {})
                  : null,
              onLeftEdge: i % cross == 0
                  ? iptvStreamLeftEdge(widget.ctrl, stream)
                  : null,
              onTap: () => _onStreamTap(stream),
            );
          },
        );
        final scrollable = !_useStreamScrollListener
            ? grid
            : NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: grid,
              );
        return iptvCatalogRow(
          rowId: 'browser-streams',
          sortOrder: 3,
          itemCount: list.length,
          onFocusUp: () => iptvFocusRowItem(
            'iptv-sections',
            iptvActiveSectionShelfIndex(widget.ctrl),
          ),
          child: IptvTvScrollbar(controller: _streamScroll, child: scrollable),
        );
      },
    );
  }

  Widget _buildStreamRows() {
    final ctrl = widget.ctrl;
    final list = _filteredStreams;
    if (list.isEmpty) return _buildStreamsEmpty();

    final categoryNames = {for (final c in ctrl.categories) c.id: c.name};

    // Compact list: 44px thumb + vertical pad (no bottom gap — denser TV lists).
    _streamCrossAxisCount = 1;
    _streamTileExtent = 56;
    _streamMainGap = 0;

    final rows = ListView.builder(
      controller: _streamScroll,
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 12),
      itemCount: list.length,
      itemExtent: _streamTileExtent,
      addAutomaticKeepAlives: false,
      itemBuilder: (_, i) {
        final stream = list[i];
        return _StreamRowTile(
          stream: stream,
          ctrl: ctrl,
          categoryName: categoryNames[stream.categoryId] ?? '',
          listIndex: i,
          showLogo: _streamShowLogo(stream),
          onTvFocusGained: _bumpChannelLogoSettle,
          onLeftEdge: iptvStreamLeftEdge(ctrl, stream),
          onRightEdge: ctrl.portalPanelOpen
              ? () => iptvFocusPortalList(ctrl)
              : null,
          onUpEdge: i == 0
              ? iptvStreamUpEdge(ctrl, index: 0, columns: 1)
              : null,
          onTap: () => _onStreamTap(stream),
        );
      },
    );
    final scrollable = !_useStreamScrollListener
        ? rows
        : NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: rows,
          );
    return iptvCatalogRow(
      rowId: 'browser-streams',
      sortOrder: 3,
      itemCount: list.length,
      orientation: ShellTvRowOrientation.vertical,
      onFocusUp: () =>
          iptvFocusRowItem('iptv-sections', iptvActiveSectionShelfIndex(ctrl)),
      child: IptvTvScrollbar(controller: _streamScroll, child: scrollable),
    );
  }

  Widget _buildStreamsEmpty() {
    final ctrl = widget.ctrl;
    if (ctrl.browserAllStreams.isEmpty) {
      // Mid-open: spinner only — never Reload / fake "Failed to load".
      if (ctrl.isLoading) {
        return Center(
          child: CircularProgressIndicator(color: IptvShellStyle.accent),
        );
      }
      final err = ctrl.error;
      // Finished empty with no error — not a failure (do not show Reload).
      if (err == null) {
        return Center(
          child: Text(
            'No channels',
            style: GoogleFonts.plusJakartaSans(color: Colors.white60),
          ),
        );
      }
      final canReload = ctrl.activeSection != null;
      if (canReload &&
          iptvUseTvFocus(context) &&
          !_didRequestReloadFocus &&
          !_reloadEmptyFocus.hasFocus) {
        _didRequestReloadFocus = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_reloadEmptyFocus.canRequestFocus) {
            _reloadEmptyFocus.requestFocus();
          }
        });
      }
      final empty = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              err,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 16),
            IptvPrimaryButton(
              icon: Icons.refresh_rounded,
              label: 'Reload',
              focusNode: _reloadEmptyFocus,
              tvRowId: 'iptv-streams-reload',
              tvItemIndex: 0,
              onUpEdge: iptvFocusPortalTool,
              onLeftEdge: ctrl.categories.isNotEmpty
                  ? () => iptvFocusBrowserCategories(ctrl)
                  : null,
              onPressed: canReload
                  ? () => ctrl.reloadSection(ctrl.activeSection!)
                  : null,
            ),
          ],
        ),
      );
      if (!canReload) return empty;
      return iptvCatalogRow(
        rowId: 'iptv-streams-reload',
        sortOrder: 3,
        itemCount: 1,
        onFocusUp: iptvFocusPortalTool,
        child: empty,
      );
    }
    if (ctrl.activeSection == IptvSection.live && ctrl.liveOnly) {
      final msg = ctrl.isVerifyingAlive
          ? 'Checking streams…'
          : 'No alive streams found';
      return Center(
        child: Text(
          msg,
          style: GoogleFonts.plusJakartaSans(color: Colors.white60),
        ),
      );
    }
    final cat = ctrl.browserSelectedCategoryId;
    final emptyMsg = cat == IptvLiveCatalog.favoritesId
        ? 'No favorite channels yet - tap the star on a channel'
        : cat == IptvLiveCatalog.watchedId
        ? 'No recently watched channels'
        : 'No streams in this view';
    return Center(
      child: Text(
        emptyMsg,
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(color: Colors.white60),
      ),
    );
  }

  Future<void> _onStreamTap(IptvStream s) async {
    final ctrl = widget.ctrl;
    final p = ctrl.activePortal;
    if (p == null) return;
    if (s.kind == 'series') {
      ctrl.noteBrowserSearchPlayedStream(s);
      await openIptvSeriesDetails(context, series: s, portal: p);
      return;
    }
    if (s.kind == 'vod') {
      ctrl.noteBrowserSearchPlayedStream(s);
      await openIptvMovieDetails(context, movie: s, portal: p);
      return;
    }
    if (s.kind == 'live') {
      unawaited(ctrl.recordLiveWatched(s.streamId));
    }
    var focusStream = s;
    ctrl.noteBrowserSearchPlayedStream(s);
    final url = await IptvClient.resolvePlayUrl(p.portal, s, section: s.kind);
    if (!mounted) return;
    if (url == null || url.isEmpty) {
      ForjaToast.error('Could not open stream');
      return;
    }
    final channelGuide = s.kind == 'live'
        ? IptvChannelGuide.fromXtreamLive(
            portal: p,
            categories: ctrl.liveSortedCategories,
            streams: ctrl.liveSortedStreams(ctrl.browserAllStreams),
            initialStream: s,
            streamHealth: Map<String, bool>.from(ctrl.streamHealth),
          )
        : null;
    await pushShellRoute(
      context,
      AppRouter.slideShellRoute(
        (_) => IptvPtPlayerScreen.singleStream(
          url: url,
          stream: s,
          portalName: p.displayLabel,
          channelGuide: channelGuide,
          onChannelChanged: (next) => focusStream = next,
        ),
      ),
    );
    if (!mounted) return;
    _restoreFocusAfterPlayback(focusStream);
  }
}

class _IptvCatalogProgressPanel extends StatelessWidget {
  const _IptvCatalogProgressPanel({required this.step, required this.progress});

  final IptvCatalogLoadStep? step;
  final IptvCatalogLoadProgress progress;

  static String _fmt(int n) {
    if (n <= 0) return '-';
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  bool _done(IptvCatalogLoadStep row) {
    if (progress.finished) return true;
    const order = [
      IptvCatalogLoadStep.categories,
      IptvCatalogLoadStep.channels,
      IptvCatalogLoadStep.movies,
      IptvCatalogLoadStep.series,
      IptvCatalogLoadStep.finished,
    ];
    final cur = step == null ? -1 : order.indexOf(step!);
    final idx = order.indexOf(row);
    if (cur < 0 || idx < 0) return false;
    return idx < cur;
  }

  bool _active(IptvCatalogLoadStep row) => !progress.finished && step == row;

  @override
  Widget build(BuildContext context) {
    final fraction = progress.fraction.clamp(0.0, 1.0);
    final pct = (fraction * 100).round();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                progress.finished ? 'Finished' : 'Loading catalog',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                progress.finished
                    ? 'Live, Movies, and Series are ready'
                    : 'Fetching categories and streams from your portal',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 6,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Color(0x22FFFFFF)),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fraction,
                        child: ColoredBox(
                          color: progress.finished
                              ? ForjaShellColors.brandGreen
                              : IptvShellStyle.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                progress.finished ? '100%' : '$pct%',
                textAlign: TextAlign.right,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              _countRow(
                label: 'Categories',
                count: progress.categoryCount,
                done: _done(IptvCatalogLoadStep.categories),
                active: _active(IptvCatalogLoadStep.categories),
              ),
              const SizedBox(height: 12),
              _countRow(
                label: 'Channels',
                count: progress.channelCount,
                done: _done(IptvCatalogLoadStep.channels),
                active: _active(IptvCatalogLoadStep.channels),
              ),
              const SizedBox(height: 12),
              _countRow(
                label: 'Movies',
                count: progress.movieCount,
                done: _done(IptvCatalogLoadStep.movies),
                active: _active(IptvCatalogLoadStep.movies),
              ),
              const SizedBox(height: 12),
              _countRow(
                label: 'Series',
                count: progress.seriesCount,
                done: _done(IptvCatalogLoadStep.series),
                active: _active(IptvCatalogLoadStep.series),
              ),
              if (progress.finished) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: ForjaShellColors.brandGreen,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'All set',
                      style: GoogleFonts.plusJakartaSans(
                        color: ForjaShellColors.brandGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _countRow({
    required String label,
    required int count,
    required bool done,
    required bool active,
  }) {
    final color = done
        ? ForjaShellColors.brandGreen
        : active
        ? Colors.white
        : Colors.white38;
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: done
              ? Icon(Icons.check_rounded, size: 18, color: color)
              : active
              ? Padding(
                  padding: const EdgeInsets.all(2),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: IptvShellStyle.accent,
                  ),
                )
              : Icon(Icons.circle_outlined, size: 15, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 14,
              fontWeight: active || done ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          active && count <= 0 ? '…' : _fmt(count),
          style: GoogleFonts.plusJakartaSans(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

