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
  /// Portal+section identity — re-land focus/scroll when the shelf changes
  /// without a loading flash (session cache).
  String? _landedCatalogKey;
  /// Last highlight we scrolled/focused — re-land after Favorites/Watched hydrate.
  String? _landedHighlightId;
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
    // Own nav enter / restore so we scroll + focus last category/channel.
    // Re-bind post-frame: IptvPtScreen's init callback would otherwise overwrite.
    void bindNav() {
      TvHeroActions.bind(
        'iptv',
        pageBack: _handleCatalogPageBack,
        enterFromNavFocus: _enterFromNav,
        restoreFocus: () {
          _landRestoredCatalog();
          return true;
        },
      );
    }

    bindNav();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      bindNav();
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
    setState(() {
      _tvFloatingCategoryId = categoryId;
      // HW OK/← exits via this path — not the row's `_exitFloating` — so pin
      // chrome ExcludeFocus must clear here or OK/→ never reach channels.
      if (categoryId == null) _tvCategoryPinFocused = false;
    });
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

  /// Pin/unpin: follow the row to its new list index (scroll + focus).
  void _toggleCategoryPin(String categoryId) {
    unawaited(widget.ctrl.toggleLiveCategoryPin(categoryId));
    // Drop pin chrome ExcludeFocus — focus lands on the category row.
    if (_tvCategoryPinFocused) {
      setState(() => _tvCategoryPinFocused = false);
    }
    void scrollAndFocusPinned() {
      if (!mounted) return;
      final idx = widget.ctrl.browserSidebarCategories
          .indexWhere((c) => c.id == categoryId);
      if (idx < 0) return;
      // Keep Favorites / Already watched above when the pin sits under them.
      final keepAbove = idx.clamp(0, 2);
      _scrollCategorySidebarToIndex(idx, keepAbove: keepAbove);
      iptvFocusRowItem('browser-categories', idx);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollAndFocusPinned();
      // Second frame: row must be mounted after lazy sliver jump.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollAndFocusPinned();
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
      _landedCatalogKey = null;
      _landedHighlightId = null;
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
    final catalogKey = widget.ctrl.activePortal == null
        ? null
        : '${widget.ctrl.activePortal!.key}|${widget.ctrl.activeSection?.name}';
    final shelfLanded = !loading &&
        catalogKey != null &&
        catalogKey != _landedCatalogKey &&
        (widget.ctrl.categories.isNotEmpty ||
            widget.ctrl.browserAllStreams.isNotEmpty);
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
      final highlightId = widget.ctrl.browserHighlightedStreamId;
      final highlightReady = highlightId != null &&
          highlightId.isNotEmpty &&
          highlightId != _landedHighlightId &&
          _filteredStreams.any((x) => x.streamId == highlightId);
      if (finishedLoad || !_didInitialFocus || shelfLanded || highlightReady) {
        if (widget.ctrl.categories.isNotEmpty ||
            widget.ctrl.browserAllStreams.isNotEmpty) {
          if (catalogKey != null) _landedCatalogKey = catalogKey;
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
    final selected = widget.ctrl.browserSelectedCategoryId;
    if (selected == null) return;
    final idx = widget.ctrl.browserSidebarCategories
        .indexWhere((c) => c.id == selected);
    if (idx < 0) return;
    // Leave 3 rows above so the selection lands as the 4th visible category.
    _scrollCategorySidebarToIndex(idx, keepAbove: 3);
  }

  /// Jump the category rail so [listIndex] is visible (selected restore).
  void _scrollCategorySidebarToIndex(int listIndex, {int keepAbove = 0}) {
    var tries = 0;
    void attempt() {
      if (!mounted) return;
      if (!_categoryScroll.hasClients) {
        if (tries++ < 4) {
          WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        }
        return;
      }
      if (listIndex < 0) return;
      final rowH = _categoryRowExtent(widget.compact);
      final target =
          (_categoryListPadV + (listIndex - keepAbove) * rowH).clamp(
        0.0,
        _categoryScroll.position.maxScrollExtent,
      );
      if ((_categoryScroll.offset - target).abs() > 0.5) {
        _categoryScroll.jumpTo(target);
      }
    }

    attempt();
    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  bool get _letterJumpEnabled =>
      !iptvLeanbackOnly(context) && !_searchOpen && !_tvFloatingReorder;

  int _letterJumpAnchorInJumpList(
    List<IptvCategory> jumpCats,
    List<IptvCategory> cats,
  ) {
    final handle = ShellTvFocusCoordinator.rowHandle('iptv', 'browser-categories');
    if (handle != null && handle.itemCount > 0 && cats.isNotEmpty) {
      final fullIdx = handle.lastFocusedIndex.clamp(0, cats.length - 1);
      final jumpIdx = jumpCats.indexWhere((c) => c.id == cats[fullIdx].id);
      if (jumpIdx >= 0) return jumpIdx;
    }
    final selected = widget.ctrl.browserSelectedCategoryId;
    if (selected != null && !IptvLiveCatalog.isSyntheticId(selected)) {
      final jumpIdx = jumpCats.indexWhere((c) => c.id == selected);
      if (jumpIdx >= 0) return jumpIdx;
    }
    return -1;
  }

  int _letterJumpStreamAnchor() {
    final handle = ShellTvFocusCoordinator.rowHandle('iptv', 'browser-streams');
    if (handle == null || handle.itemCount <= 0) return -1;
    return handle.lastFocusedIndex.clamp(0, handle.itemCount - 1);
  }

  void _letterJumpCategory(int index) {
    final cats = _filteredCategories;
    if (index < 0 || index >= cats.length) return;
    void go() {
      if (!mounted) return;
      _scrollCategorySidebarToIndex(index, keepAbove: 2);
      iptvFocusRowItem('browser-categories', index);
    }
    go();
    WidgetsBinding.instance.addPostFrameCallback((_) => go());
  }

  void _letterJumpStream(int index) {
    final list = _filteredStreams;
    if (index < 0 || index >= list.length) return;
    // Lazy grid/list: scroll first, then retry focus until the tile exists.
    var tries = 0;
    void go() {
      if (!mounted) return;
      _scrollStreamsToIndex(index);
      if (iptvFocusBrowserStreamAt(index)) return;
      if (tries++ < 12) {
        WidgetsBinding.instance.addPostFrameCallback((_) => go());
      }
    }
    go();
    WidgetsBinding.instance.addPostFrameCallback((_) => go());
  }

  void _scrollStreamsToIndex(int index) {
    if (!_streamScroll.hasClients || index < 0) return;
    final cross = _streamCrossAxisCount.clamp(1, 999);
    final row = widget.compact ? index : index ~/ cross;
    final extent = _streamTileExtent + _streamMainGap;
    // Grid/list top padding (8) — without it far rows land short of the tile.
    const topPad = 8.0;
    final target = (topPad + row * extent).clamp(
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
      _landRestoredCatalog();
    }
  }

  void _enterFromNav() {
    if (!mounted) return;
    if (_needsPortal) {
      _focusOpenPortalButton();
      return;
    }
    if (widget.ctrl.isLoading) return;
    _landRestoredCatalog();
  }

  void _focusOpenPortalButton() {
    if (!_openPortalFocus.canRequestFocus) return;
    _openPortalFocus.requestFocus();
    _didInitialFocus = false;
  }

  /// Select + scroll last category; if a last-played channel is in the list,
  /// scroll and focus it (no autoplay). Favorites / Already watched included.
  void _landRestoredCatalog() {
    if (!mounted || _needsPortal || widget.ctrl.isLoading) return;
    // Don't steal catalog focus/scroll while the player overlay owns the page.
    if (ShellBus.playerSurfaceActive.value ||
        ShellBus.shellOverlayHasPage.value) {
      return;
    }
    _didInitialFocus = true;
    final selected = widget.ctrl.browserSelectedCategoryId;
    final highlightId = widget.ctrl.browserHighlightedStreamId;
    final list = _filteredStreams;
    final channelIdx = (highlightId != null && highlightId.isNotEmpty)
        ? list.indexWhere((x) => x.streamId == highlightId)
        : -1;
    final focusChannel = channelIdx >= 0;

    if (iptvUseTvFocus(context) && selected != null) {
      setState(() {
        _tvFocusedCategoryId = selected;
        _tvCategoryRailFocused = !focusChannel;
      });
    }
    _scrollCategorySidebarToSelected();

    if (focusChannel) {
      _landedHighlightId = highlightId;
      _scrollAndFocusStreamAt(channelIdx);
      return;
    }
    _landedHighlightId = null;
    if (!iptvUseTvFocus(context)) return;
    if (!iptvFocusBrowserCategories(widget.ctrl)) {
      if (widget.ctrl.browserSidebarCategories.isEmpty) {
        iptvFocusRowItem('browser-streams', 0);
      }
    }
  }

  /// Scroll lazy grid/list then focus the tile — highlight only, no play.
  void _scrollAndFocusStreamAt(int index) {
    if (index < 0) return;
    final tv = iptvUseTvFocus(context);
    var tries = 0;
    var scrolledFor = -1;
    void attempt() {
      if (!mounted) return;
      if (ShellBus.shellOverlayHasPage.value ||
          ShellBus.playerSurfaceActive.value) {
        if (tries++ < 24) {
          WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        }
        return;
      }
      if (scrolledFor != index) {
        _scrollStreamsToIndex(index);
        scrolledFor = index;
        tries++;
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        return;
      }
      if (!tv) return;
      if (iptvFocusBrowserStreamAt(index)) return;
      scrolledFor = -1;
      if (tries++ < 24) {
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
      } else {
        iptvFocusBrowserCategories(widget.ctrl);
      }
    }

    attempt();
    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  /// Alias used by panel-close / load paths.
  void _focusCatalogGroup() => _landRestoredCatalog();

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

  /// Jump so [index] is mountable, then focus — HoldAccel strides skip past
  /// the lazy window otherwise and the green fill trails the key-repeat.
  void _focusCategoryAt(int index) {
    final cats = _filteredCategories;
    if (cats.isEmpty) return;
    final clamped = index.clamp(0, cats.length - 1);
    _jumpCategoryListToIndex(clamped);
    if (ShellTvFocusCoordinator.focusRowItemExact(
      'iptv',
      'browser-categories',
      clamped,
    )) {
      return;
    }
    var tries = 0;
    void attempt() {
      if (!mounted) return;
      _jumpCategoryListToIndex(clamped);
      if (ShellTvFocusCoordinator.focusRowItemExact(
        'iptv',
        'browser-categories',
        clamped,
      )) {
        return;
      }
      if (tries++ < 12) {
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  /// Instant keep-visible jump (same idea as the Portals panel).
  void _jumpCategoryListToIndex(int index) {
    if (!_categoryScroll.hasClients || index < 0) return;
    final rowH = _categoryRowExtent(widget.compact);
    final position = _categoryScroll.position;
    final viewport = position.viewportDimension;
    if (viewport <= 0) return;
    final itemTop = _categoryListPadV + index * rowH;
    final itemBottom = itemTop + rowH;
    final viewTop = position.pixels;
    final viewBottom = viewTop + viewport;
    final margin = rowH * 2;
    double? target;
    if (itemTop < viewTop + margin) {
      target = itemTop - margin;
    } else if (itemBottom > viewBottom - margin) {
      target = itemBottom - viewport + margin;
    }
    if (target == null) return;
    _categoryScroll.jumpTo(target.clamp(0.0, position.maxScrollExtent));
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

    if (!focused) {
      // Blur races ahead of the next category's focus callback. Clearing
      // `_tvCategoryRailFocused` here forced a full browser rebuild on every
      // ↑/↓ (green fill lagged the scroll). Defer — only leave rail mode if
      // nothing else claimed this category id.
      if (_tvFocusedCategoryId != categoryId) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_tvFocusedCategoryId != categoryId) return;
        if (!_tvCategoryRailFocused) return;
        setState(() => _tvCategoryRailFocused = false);
      });
      return;
    }

    final selected = widget.ctrl.browserSelectedCategoryId;
    final nowPending = categoryId != selected;
    final alreadyPendingRail = _tvCategoryRailFocused &&
        _tvFocusedCategoryId != null &&
        _tvFocusedCategoryId != selected;

    // Holding ↑/↓ across unopened groups: pane already shows "Press OK" —
    // skip full browser rebuild (was fighting fixed-extent scroll).
    if (alreadyPendingRail && nowPending) {
      _tvFocusedCategoryId = categoryId;
      return;
    }
    if (_tvFocusedCategoryId == categoryId && _tvCategoryRailFocused) {
      return;
    }
    setState(() {
      _tvFocusedCategoryId = categoryId;
      _tvCategoryRailFocused = true;
    });
  }

  /// While D-pad is on an unopened group, keep logos off the channel pane.
  /// Leanback only — desktop hybrid hover/focus must keep the open category.
  bool get _tvCategoryPendingCommit {
    if (!iptvLeanbackOnly(context) || !_tvCategoryRailFocused) return false;
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
                  tooltip: 'Reload $_sectionTitle',
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
            IptvCatalogLoadStyle.verbose => _IptvCatalogLoadingTicker(
              section: ctrl.activeSection ?? IptvSection.live,
              step: ctrl.catalogLoadStep ?? IptvCatalogLoadStep.cache,
            ),
            IptvCatalogLoadStyle.none =>
              ctrl.isLoading
                  ? _IptvCatalogLoadingTicker(
                      section: ctrl.activeSection ?? IptvSection.live,
                      step: IptvCatalogLoadStep.catalog,
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
        highlightStreamId: ctrl.browserHighlightedStreamId,
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
                  : () => _focusCategoryAt(
                      listIndex - ShellTvHoldAccel.lastStep,
                    ),
              onDownEdge: () => _focusCategoryAt(
                listIndex + ShellTvHoldAccel.lastStep,
              ),
              // → opens channels when not pinnable (pinnable uses → for pin).
              onRightEdge: () =>
                  _commitBrowserCategory(cat.id, enterStreams: true),
              onTvFocusChange: (focused) =>
                  _onCategoryTvFocus(cat.id, focused),
              onPinFocusChange: (focused) {
                // May fire from row dispose during reorder — never setState
                // while the framework is locked in finalizeTree.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (_tvCategoryPinFocused == focused) return;
                  setState(() => _tvCategoryPinFocused = focused);
                });
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
          final jumpCats = [
            for (final c in cats)
              if (!IptvLiveCatalog.isSyntheticId(c.id)) c,
          ];
          final list = ListLetterJumpScope(
            enabled: _letterJumpEnabled && jumpCats.isNotEmpty,
            itemCount: jumpCats.length,
            anchorIndex: _letterJumpAnchorInJumpList(jumpCats, cats),
            labelAt: (i) {
              final name = jumpCats[i].name;
              return name.isEmpty ? 'Uncategorized' : name;
            },
            onJump: (i) {
              final fullIdx = cats.indexWhere((c) => c.id == jumpCats[i].id);
              if (fullIdx >= 0) _letterJumpCategory(fullIdx);
            },
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

          return iptvCatalogRow(
            rowId: 'browser-categories',
            sortOrder: 2,
            itemCount: cats.length,
            orientation: ShellTvRowOrientation.vertical,
            onFocusUp: () => iptvFocusRowItem(
              'iptv-sections',
              iptvActiveSectionShelfIndex(ctrl),
            ),
            child: list,
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
        final aspect = tv ? cardW / cardH : 0.9;
        // Must match GridView cell height — not cardH alone (desktop uses 0.9).
        const padL = 8.0, padR = 12.0;
        final innerW =
            (c.maxWidth - padL - padR - gap * (cross - 1)).clamp(1.0, 1e9);
        final cellH = (innerW / cross) / aspect;
        _streamCrossAxisCount = cross;
        _streamTileExtent = cellH;
        _streamMainGap = gap;
        final lastRowStart = ((list.length - 1) ~/ cross) * cross;
        // Fixed column count on TV so D-pad Left/Right match the visual row
        // (MaxCrossAxisExtent can disagree with our focus math and wrap).
        final grid = GridView.builder(
          controller: _streamScroll,
          padding: EdgeInsets.fromLTRB(padL, 8, padR, 12),
          addAutomaticKeepAlives: false,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
            childAspectRatio: aspect,
          ),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final stream = list[i];
            final atRightEdge = (i % cross) == cross - 1;
            return _StreamCard(
              stream: stream,
              ctrl: widget.ctrl,
              highlighted:
                  stream.streamId == widget.ctrl.browserHighlightedStreamId,
              showLogo: _streamShowLogo(stream),
              onTvFocusGained: _bumpChannelLogoSettle,
              gridIndex: i,
              gridColumns: cross,
              onUpEdge: i < cross
                  ? iptvStreamUpEdge(widget.ctrl, index: i, columns: cross)
                  : null,
              onDownEdge: i >= lastRowStart ? () {} : null,
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
          child: ListLetterJumpScope(
            enabled: _letterJumpEnabled,
            itemCount: list.length,
            anchorIndex: _letterJumpStreamAnchor(),
            labelAt: (i) => list[i].name,
            onJump: _letterJumpStream,
            child: IptvTvScrollbar(controller: _streamScroll, child: scrollable),
          ),
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
          highlighted: stream.streamId == ctrl.browserHighlightedStreamId,
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
          onDownEdge: i == list.length - 1 ? () {} : null,
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
      child: ListLetterJumpScope(
        enabled: _letterJumpEnabled,
        itemCount: list.length,
        anchorIndex: _letterJumpStreamAnchor(),
        labelAt: (i) => list[i].name,
        onJump: _letterJumpStream,
        child: IptvTvScrollbar(controller: _streamScroll, child: scrollable),
      ),
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
    if (s.kind == 'live') {
      unawaited(ctrl.rememberLivePlayedChannel(s.streamId));
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
    await IptvPtPlayerScreen.open(
      context,
      IptvPtPlayerScreen.singleStream(
        url: url,
        stream: s,
        portalName: p.displayLabel,
        portalPlatform: p.portal.platform,
        channelGuide: channelGuide,
        onChannelChanged: (next) {
          focusStream = next;
          unawaited(ctrl.rememberLivePlayedChannel(next.streamId));
        },
        onStreamDead: ctrl.markStreamDead,
      ),
    );
    if (!mounted) return;
    _restoreFocusAfterPlayback(focusStream);
  }
}

/// Center catalog loading ticker — one shelf at a time with step copy.
class _IptvCatalogLoadingTicker extends StatelessWidget {
  const _IptvCatalogLoadingTicker({
    required this.section,
    required this.step,
  });

  final IptvSection section;
  final IptvCatalogLoadStep step;

  String get _title => switch (section) {
        IptvSection.live => 'Loading channels',
        IptvSection.vod => 'Loading movies',
        IptvSection.series => 'Loading series',
      };

  String get _detail => switch (step) {
        IptvCatalogLoadStep.cache => 'Checking device cache…',
        IptvCatalogLoadStep.catalog => switch (section) {
            IptvSection.live =>
              'Fetching categories and channels from your portal…',
            IptvSection.vod =>
              'Fetching categories and movies from your portal…',
            IptvSection.series =>
              'Fetching categories and series from your portal…',
          },
        IptvCatalogLoadStep.liveLists =>
          'Loading favorites and watched channels…',
        IptvCatalogLoadStep.finished => 'Almost ready…',
      };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: IptvShellStyle.accent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _detail,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
