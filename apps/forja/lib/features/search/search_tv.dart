part of 'search_screen.dart';

mixin _SearchTv on State<SearchScreen> {
  SearchScreenState get _s => this as SearchScreenState;

  List<_FlatSearchResult> _flatResults() {
    final seen = <String>{};
    final out = <_FlatSearchResult>[];
    for (final section in _s._sections) {
      for (final item in section.results) {
        if (item is Movie) {
          final key = 'tmdb:${item.id}:${item.mediaType}';
          if (!seen.add(key)) continue;
          out.add(
            _FlatSearchResult(
              key: key,
              title: item.title,
              overview: item.overview,
              posterUrl: item.posterPath.isNotEmpty
                  ? TmdbApi.getImageUrl(item.posterPath)
                  : '',
              backdropUrl: item.backdropPath.isNotEmpty
                  ? TmdbApi.getImageUrl(item.backdropPath)
                  : null,
              year: item.releaseDate.length >= 4
                  ? item.releaseDate.substring(0, 4)
                  : null,
              rating: item.voteAverage > 0 ? item.voteAverage : null,
              isTmdb: true,
              raw: item,
            ),
          );
        } else {
          final map = item as Map<String, dynamic>;
          final id = map['id']?.toString() ?? map['name']?.toString() ?? '';
          final key = 'addon:$id';
          if (id.isEmpty || !seen.add(key)) continue;
          final poster = map['poster']?.toString() ?? '';
          final ratingStr = map['imdbRating']?.toString() ?? '';
          out.add(
            _FlatSearchResult(
              key: key,
              title: map['name']?.toString() ?? 'Unknown',
              overview: map['description']?.toString() ?? '',
              posterUrl: poster,
              backdropUrl: map['background']?.toString() ?? poster,
              year: map['releaseInfo']?.toString(),
              rating: double.tryParse(ratingStr),
              isTmdb: false,
              raw: map,
            ),
          );
        }
      }
    }
    return out;
  }

  _FlatSearchResult? get _focusedResult {
    final results = _flatResults();
    if (results.isEmpty) return null;
    final index = _s._gridFocusedIndex.clamp(0, results.length - 1);
    return results[index];
  }

  void _openResult(_FlatSearchResult result) {
    if (result.isTmdb) {
      _s._openDetails(result.raw as Movie);
    } else {
      _s._openStremioItem(result.raw as Map<String, dynamic>);
    }
  }

  void _clearHelperFocusedIndex(int index) {
    if (_s._helperFocusedIndex == index) {
      setState(() => _s._helperFocusedIndex = null);
    }
  }

  void _setHelperFocusedIndex(int index) {
    final count = _helperItemCount();
    if (count == 0) return;
    setState(() => _s._helperFocusedIndex = index.clamp(0, count - 1));
  }

  void _setGridFocusedIndex(int index) {
    final count = _flatResults().length;
    if (count == 0) return;
    setState(() => _s._gridFocusedIndex = index.clamp(0, count - 1));
  }

  int _helperItemCount() => _s._trendingHelperTitles.length;

  void _focusResultCardAt(int index) {
    final count = _flatResults().length;
    if (count == 0) {
      _s._pendingGridFocusIndex = index;
      return;
    }
    _s._pendingGridFocusIndex = null;
    _s._focusNode.unfocus();
    final clamped = index.clamp(0, count - 1);
    setState(() => _s._gridFocusedIndex = clamped);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ShellTvFocusCoordinator.focusRowItem('search', 'results', clamped);
    });
  }

  void _scheduleFocusOnResultCardIfPending() {
    final pending = _s._pendingGridFocusIndex;
    if (pending == null) return;
    final count = _flatResults().length;
    if (count == 0) return;

    _s._pendingGridFocusIndex = null;
    _s._focusNode.unfocus();
    final index = pending.clamp(0, count - 1);
    if (_s._gridFocusedIndex != index) {
      setState(() => _s._gridFocusedIndex = index);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ShellTvFocusCoordinator.focusRowItem('search', 'results', index);
    });
  }

  bool _isDesktopLayout(BuildContext context) => shellUsesWideLayout(context);

  bool _tvFocus(BuildContext context) =>
      ShellScope.inputPolicyOf(context).useFocusableMoodChips;

  void _focusHelperAtIndex(int index) {
    final count = _helperItemCount();
    if (count == 0) return;
    final clamped = index.clamp(0, count - 1);
    setState(() => _s._helperFocusedIndex = clamped);

    void tryFocus({int attempt = 0}) {
      if (ShellTvFocusCoordinator.focusRowItem('search', 'helpers', clamped)) {
        return;
      }
      if (attempt >= 4) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        tryFocus(attempt: attempt + 1);
      });
    }

    tryFocus();
  }

  void _focusFirstHelper() => _focusHelperAtIndex(0);

  RenderBox? _tvItemRenderBox(String rowId, int index) {
    final node = ShellTvFocusCoordinator.itemNode('search', rowId, index);
    final ctx = node?.context;
    if (ctx == null || !ctx.mounted) return null;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.hasSize ||
        !renderObject.attached) {
      return null;
    }
    return renderObject;
  }

  double? _tvItemCenterGlobalY(String rowId, int index) {
    final box = _tvItemRenderBox(rowId, index);
    if (box == null) return null;
    return box.localToGlobal(box.size.center(Offset.zero)).dy;
  }

  double? _gridRowScrollStride() {
    const gridColumns = 4;
    for (var row = 0; row < 24; row++) {
      final y0 = _tvItemCenterGlobalY('results', row * gridColumns);
      final y1 = _tvItemCenterGlobalY('results', (row + 1) * gridColumns);
      if (y0 != null && y1 != null) return y1 - y0;
    }
    final box = _tvItemRenderBox('results', 0);
    if (box == null) return null;
    return box.size.height + 16;
  }

  int _closestGridRowForGlobalY(double helperCenterY, int maxRow) {
    const gridColumns = 4;
    var bestRow = 0;
    var bestDelta = double.infinity;
    var sawRenderedRow = false;

    for (var row = 0; row <= maxRow; row++) {
      final centerY = _tvItemCenterGlobalY('results', row * gridColumns);
      if (centerY == null) continue;
      sawRenderedRow = true;
      final delta = (centerY - helperCenterY).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        bestRow = row;
      }
    }

    if (sawRenderedRow) return bestRow;

    final anchorY = _tvItemCenterGlobalY('results', 0);
    final stride = _gridRowScrollStride();
    if (anchorY != null && stride != null && stride > 0) {
      return ((helperCenterY - anchorY) / stride).round().clamp(0, maxRow);
    }
    return 0;
  }

  void _ensureGridRowVisible(int row) {
    const gridColumns = 4;
    final index = row * gridColumns;
    final node = ShellTvFocusCoordinator.itemNode('search', 'results', index);
    final ctx = node?.context;
    if (ctx != null && ctx.mounted) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.2,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (!_s._resultsScrollController.hasClients) return;
    final stride = _gridRowScrollStride();
    if (stride == null || stride <= 0) return;
    final maxExtent = _s._resultsScrollController.position.maxScrollExtent;
    _s._resultsScrollController.jumpTo((row * stride).clamp(0.0, maxExtent));
  }

  /// Right from a recommendation → film card on the visually aligned grid row.
  void _focusResultCardAtVisualLevel(int helperIndex) {
    const gridColumns = 4;
    final count = _flatResults().length;
    if (count == 0) return;

    final maxRow = (count - 1) ~/ gridColumns;
    final helperY = _tvItemCenterGlobalY('helpers', helperIndex);
    final targetRow = helperY == null
        ? 0
        : _closestGridRowForGlobalY(helperY, maxRow);
    final targetIndex = (targetRow * gridColumns).clamp(0, count - 1);

    _ensureGridRowVisible(targetRow);

    void tryFocus({int attempt = 0}) {
      if (!mounted) return;
      if (ShellTvFocusCoordinator.focusRowItem(
        'search',
        'results',
        targetIndex,
      )) {
        _s._pendingGridFocusIndex = null;
        _s._focusNode.unfocus();
        setState(() {
          _s._gridFocusedIndex = targetIndex;
          _s._helperFocusedIndex = null;
        });
        return;
      }
      if (attempt >= 4) {
        _focusResultCardAt(targetIndex);
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        tryFocus(attempt: attempt + 1);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => tryFocus());
  }

  void _resetHelpersScroll() {
    if (!_s._helpersScrollController.hasClients) return;
    if (_s._helpersScrollController.offset <= 0) return;
    _s._helpersScrollController.jumpTo(0);
  }

  VoidCallback? _helperUpEdge(int index) {
    if (index == 0) return _focusSearchFieldBrowse;
    return () => _focusHelperAtIndex(index - 1);
  }

  VoidCallback? _helperDownEdge(int index, int count) {
    if (index >= count - 1) return () {};
    return () => _focusHelperAtIndex(index + 1);
  }

  VoidCallback? _helperRightEdge(int index) {
    if (_s._query.trim().isEmpty || _flatResults().isEmpty) return null;
    return () => _focusResultCardAtVisualLevel(index);
  }

  void _onSearchFieldFocusChange() {
    if (mounted) setState(() {});
    ShellBus.notifyShellChromeChanged();
    if (!_s._focusNode.hasFocus) {
      if (_s._searchFieldEditing && mounted) {
        setState(() => _s._searchFieldEditing = false);
      }
      return;
    }
    ShellTvFocusCoordinator.saveFocus(
      'search',
      ShellTvFocusMemory(zone: ShellTvZone.topBar, node: _s._focusNode),
    );
  }

  void _focusSearchFieldBrowse() {
    if (!_s._focusNode.canRequestFocus) return;
    if (_s._searchFieldEditing) {
      setState(() => _s._searchFieldEditing = false);
      ShellBus.notifyShellChromeChanged();
    }
    _resetHelpersScroll();
    _s._focusNode.requestFocus();
    ShellTvFocusCoordinator.saveFocus(
      'search',
      ShellTvFocusMemory(zone: ShellTvZone.topBar, node: _s._focusNode),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _s._query.trim().isNotEmpty) return;
      if (ShellTvFocus.currentNavTabId != 'search') return;
      if (!_s._focusNode.hasFocus) {
        _s._focusNode.requestFocus();
      }
    });
  }

  /// Called when the Search tab becomes selected (shell tab switch).
  void focusTvBrowseFieldIfEmpty() {
    if (!ShellTokens.isAndroidTvDevice) return;
    if (_s._query.trim().isNotEmpty) return;
    _focusSearchFieldBrowse();
  }

  /// TV: opening Search with no query — browse field, not first recommendation.
  bool _restoreSearchTvFocusIfEmpty() {
    if (!ShellTokens.isAndroidTvDevice) return false;
    if (_s._query.trim().isNotEmpty) return false;
    _focusSearchFieldBrowse();
    return true;
  }

  void _beginSearchFieldEditing() {
    setState(() => _s._searchFieldEditing = true);
    ShellBus.notifyShellChromeChanged();
    if (!_s._focusNode.hasFocus) {
      _s._focusNode.requestFocus();
    }
  }

  /// TV: OK / Enter after typing — run pending search and focus first result card.
  void _submitSearchField() {
    if (!_tvFocus(context)) return;
    final query = _s._controller.text.trim();
    if (query.isEmpty) return;

    final hadPendingDebounce = _s._debounce?.isActive ?? false;
    _s._debounce?.cancel();

    if (_s._searchFieldEditing && mounted) {
      setState(() => _s._searchFieldEditing = false);
      ShellBus.notifyShellChromeChanged();
    }

    _s._pendingGridFocusIndex = 0;

    if (hadPendingDebounce) {
      _s._performUnifiedSearch(query);
    }

    _scheduleFocusOnResultCardIfPending();
  }

  KeyEventResult _searchFieldKeyEvent(FocusNode node, KeyEvent event) {
    if (!mounted || !_tvFocus(context)) return KeyEventResult.ignored;
    if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_helperItemCount() <= 0) return KeyEventResult.ignored;
      _focusFirstHelper();
      return KeyEventResult.handled;
    }
    if (shellTvIsActivateKey(event) && _s._searchFieldEditing) {
      _submitSearchField();
      return KeyEventResult.handled;
    }
    if (shellTvIsActivateKey(event) && !_s._searchFieldEditing) {
      _beginSearchFieldEditing();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}
