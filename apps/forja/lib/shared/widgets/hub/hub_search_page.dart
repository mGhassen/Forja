import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/widgets/shell_error_retry_panel.dart';
import 'package:forja/shared/widgets/tv_search_browse_overlay.dart';

class HubSearchResult {
  const HubSearchResult({
    required this.key,
    required this.title,
    required this.posterUrl,
    this.backdropUrl,
    this.subtitle,
    this.rating,
    required this.payload,
  });

  final String key;
  final String title;
  final String posterUrl;
  final String? backdropUrl;
  final String? subtitle;
  final double? rating;
  final Object payload;
}

typedef HubSearchQuery = Future<List<HubSearchResult>> Function(String query);
typedef HubRecommendationsLoader = Future<List<String>> Function();
typedef HubSearchOpen = void Function(HubSearchResult result);

/// Hub search overlay - desktop split layout with recommendations + result grid
/// (same structure as [SearchScreen]).
class HubSearchPage extends StatefulWidget {
  const HubSearchPage({
    super.key,
    required this.hintText,
    required this.tvTabId,
    required this.onSearch,
    required this.onOpen,
    required this.loadRecommendations,
    this.debounceMs = 500,
  });

  final String hintText;
  final String tvTabId;
  final HubSearchQuery onSearch;
  final HubSearchOpen onOpen;
  final HubRecommendationsLoader loadRecommendations;
  final int debounceMs;

  @override
  State<HubSearchPage> createState() => _HubSearchPageState();
}

class _HubSearchPageState extends State<HubSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _closeFocusNode = FocusNode(debugLabel: 'hub-search-close');
  final FocusNode _firstHelperFocusNode = FocusNode();
  final ScrollController _helpersScrollController = ScrollController();
  final ScrollController _resultsScrollController = ScrollController();

  Timer? _debounce;
  String _query = '';
  int _searchGeneration = 0;
  bool _isSearching = false;
  String? _error;
  List<HubSearchResult> _results = [];

  List<String> _recommendationTitles = [];
  int? _helperFocusedIndex;
  int _gridFocusedIndex = 0;
  int? _pendingGridFocusIndex;
  bool _searchFieldEditing = false;
  bool _initialFocusScheduled = false;
  ModalRoute<void>? _route;
  AnimationStatusListener? _routeAnimationListener;

  static const _helpersRowId = 'search-helpers';
  static const _helperResultsRowId = 'search-helper-results';
  static const _resultsRowId = 'search-results';

  @override
  void initState() {
    super.initState();
    ShellBus.registerFindShortcutHandler(_handleFindShortcut);
    _focusNode.addListener(_onSearchFieldFocusChange);
    _focusNode.onKeyEvent = _searchFieldKeyEvent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ShellBus.shellOverlayHasPage.addListener(_onShellOverlayChanged);
    });
    _loadRecommendations();
  }

  void _scheduleEnsureSearchFieldFocused() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureSearchFieldFocused();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      _detachRouteAnimationListener();
      _route = route;
      final animation = route?.animation;
      if (animation != null) {
        _routeAnimationListener = (status) {
          if (status == AnimationStatus.completed && mounted) {
            _scheduleEnsureSearchFieldFocused();
          }
        };
        animation.addStatusListener(_routeAnimationListener!);
        if (animation.isCompleted) {
          _scheduleEnsureSearchFieldFocused();
        }
      }
    }

    if (!_initialFocusScheduled) {
      _initialFocusScheduled = true;
      _scheduleEnsureSearchFieldFocused();
    }
  }

  void _detachRouteAnimationListener() {
    final listener = _routeAnimationListener;
    final animation = _route?.animation;
    if (listener != null && animation != null) {
      animation.removeStatusListener(listener);
    }
    _routeAnimationListener = null;
  }

  void _onShellOverlayChanged() {
    if (ShellBus.shellOverlayHasPage.value) {
      _scheduleEnsureSearchFieldFocused();
    }
  }

  void _ensureSearchFieldFocused({int attempt = 0}) {
    if (!mounted) return;
    if (!_tvFocus(context)) {
      if (!_isWideLayout(context)) {
        _focusNode.requestFocus();
      }
      return;
    }
    if (_query.trim().isNotEmpty) return;

    _focusSearchFieldBrowse();

    if (_focusNode.hasFocus || attempt >= 12) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureSearchFieldFocused(attempt: attempt + 1);
    });
  }

  Future<void> _loadRecommendations() async {
    try {
      final titles = await widget.loadRecommendations();
      if (!mounted) return;
      setState(() => _recommendationTitles = titles);
      if (_query.isEmpty && _tvFocus(context)) {
        _scheduleEnsureSearchFieldFocused();
      }
    } catch (_) {}
  }

  void _onSearchFieldFocusChange() {
    if (mounted) setState(() {});
    if (!_focusNode.hasFocus) {
      if (_searchFieldEditing && mounted) {
        setState(() => _searchFieldEditing = false);
      }
      return;
    }
    ShellTvFocusCoordinator.saveFocus(
      widget.tvTabId,
      ShellTvFocusMemory(zone: ShellTvZone.topBar, node: _focusNode),
    );
  }

  bool _handleFindShortcut() {
    _focusSearchFieldBrowse();
    return true;
  }

  void _focusSearchFieldBrowse() {
    if (!_focusNode.canRequestFocus) return;
    if (_searchFieldEditing) {
      setState(() => _searchFieldEditing = false);
    }
    _resetHelpersScroll();
    _focusNode.requestFocus();
    ShellTvFocusCoordinator.saveFocus(
      widget.tvTabId,
      ShellTvFocusMemory(zone: ShellTvZone.topBar, node: _focusNode),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _query.trim().isNotEmpty) return;
      if (!_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  void _beginSearchFieldEditing() {
    setState(() => _searchFieldEditing = true);
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    ShellBus.unregisterFindShortcutHandler(_handleFindShortcut);
    ShellBus.shellOverlayHasPage.removeListener(_onShellOverlayChanged);
    _detachRouteAnimationListener();
    _focusNode.removeListener(_onSearchFieldFocusChange);
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _closeFocusNode.dispose();
    _firstHelperFocusNode.dispose();
    _helpersScrollController.dispose();
    _resultsScrollController.dispose();
    super.dispose();
  }

  bool _isWideLayout(BuildContext context) => shellUsesWideLayout(context);

  bool _tvFocus(BuildContext context) =>
      ShellScope.inputPolicyOf(context).useFocusableMoodChips;

  void _onSearchChanged(String query) {
    setState(() {
      _query = query;
      _helperFocusedIndex = null;
      _gridFocusedIndex = 0;
      _error = null;
    });
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
        _pendingGridFocusIndex = null;
      });
      if (_tvFocus(context) && _focusNode.hasFocus) {
        _focusSearchFieldBrowse();
      }
      return;
    }
    _debounce = Timer(Duration(milliseconds: widget.debounceMs), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;
    final gen = ++_searchGeneration;
    setState(() {
      _results = [];
      _isSearching = true;
      _error = null;
      _helperFocusedIndex = null;
      _gridFocusedIndex = 0;
    });
    try {
      final results = await widget.onSearch(query);
      if (gen != _searchGeneration || !mounted) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
      _scheduleFocusOnResultCardIfPending();
    } catch (e) {
      if (gen != _searchGeneration || !mounted) return;
      setState(() {
        _isSearching = false;
        _error = 'Search failed';
      });
    }
  }

  void _applyHelperQuery(String title) {
    _pendingGridFocusIndex = 0;
    _controller.text = title;
    _onSearchChanged(title);
  }

  HubSearchResult? get _focusedResult {
    if (_results.isEmpty) return null;
    final index = _gridFocusedIndex.clamp(0, _results.length - 1);
    return _results[index];
  }

  void _focusResultCardAt(int index) {
    final count = _results.length;
    if (count == 0) {
      _pendingGridFocusIndex = index;
      return;
    }
    _pendingGridFocusIndex = null;
    _focusNode.unfocus();
    final clamped = index.clamp(0, count - 1);
    setState(() {
      _gridFocusedIndex = clamped;
      _helperFocusedIndex = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ShellTvFocusCoordinator.focusRowItem(
        widget.tvTabId,
        _resultsRowId,
        clamped,
      );
    });
  }

  void _scheduleFocusOnResultCardIfPending() {
    final pending = _pendingGridFocusIndex;
    if (pending == null || _results.isEmpty) return;
    _pendingGridFocusIndex = null;
    _focusNode.unfocus();
    final index = pending.clamp(0, _results.length - 1);
    if (_gridFocusedIndex != index) {
      setState(() => _gridFocusedIndex = index);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ShellTvFocusCoordinator.focusRowItem(
        widget.tvTabId,
        _resultsRowId,
        index,
      );
    });
  }

  String _helpersRowIdForFocus() =>
      _query.trim().isEmpty ? _helpersRowId : _helperResultsRowId;

  void _focusHelperAtIndex(int index) {
    final rowId = _helpersRowIdForFocus();
    final count = _helperItemCount();
    if (count == 0) return;
    final clamped = index.clamp(0, count - 1);
    setState(() => _helperFocusedIndex = clamped);

    void tryFocus({int attempt = 0}) {
      if (ShellTvFocusCoordinator.focusRowItem(
        widget.tvTabId,
        rowId,
        clamped,
      )) {
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
    final node =
        ShellTvFocusCoordinator.itemNode(widget.tvTabId, rowId, index);
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
      final y0 = _tvItemCenterGlobalY(_resultsRowId, row * gridColumns);
      final y1 =
          _tvItemCenterGlobalY(_resultsRowId, (row + 1) * gridColumns);
      if (y0 != null && y1 != null) return y1 - y0;
    }
    final box = _tvItemRenderBox(_resultsRowId, 0);
    if (box == null) return null;
    return box.size.height + 16;
  }

  int _closestGridRowForGlobalY(double helperCenterY, int maxRow) {
    const gridColumns = 4;
    var bestRow = 0;
    var bestDelta = double.infinity;
    var sawRenderedRow = false;

    for (var row = 0; row <= maxRow; row++) {
      final centerY =
          _tvItemCenterGlobalY(_resultsRowId, row * gridColumns);
      if (centerY == null) continue;
      sawRenderedRow = true;
      final delta = (centerY - helperCenterY).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        bestRow = row;
      }
    }

    if (sawRenderedRow) return bestRow;

    final anchorY = _tvItemCenterGlobalY(_resultsRowId, 0);
    final stride = _gridRowScrollStride();
    if (anchorY != null && stride != null && stride > 0) {
      return ((helperCenterY - anchorY) / stride).round().clamp(0, maxRow);
    }
    return 0;
  }

  void _ensureGridRowVisible(int row) {
    const gridColumns = 4;
    final index = row * gridColumns;
    final node = ShellTvFocusCoordinator.itemNode(
      widget.tvTabId,
      _resultsRowId,
      index,
    );
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
    if (!_resultsScrollController.hasClients) return;
    final stride = _gridRowScrollStride();
    if (stride == null || stride <= 0) return;
    final maxExtent = _resultsScrollController.position.maxScrollExtent;
    _resultsScrollController.jumpTo((row * stride).clamp(0.0, maxExtent));
  }

  /// Right from a recommendation → film card on the visually aligned grid row.
  void _focusResultCardAtVisualLevel(int helperIndex) {
    const gridColumns = 4;
    final count = _results.length;
    if (count == 0) return;

    final maxRow = (count - 1) ~/ gridColumns;
    final helperRowId = _helpersRowIdForFocus();
    final helperY = _tvItemCenterGlobalY(helperRowId, helperIndex);
    final targetRow = helperY == null
        ? 0
        : _closestGridRowForGlobalY(helperY, maxRow);
    final targetIndex = (targetRow * gridColumns).clamp(0, count - 1);

    _ensureGridRowVisible(targetRow);

    void tryFocus({int attempt = 0}) {
      if (!mounted) return;
      if (ShellTvFocusCoordinator.focusRowItem(
        widget.tvTabId,
        _resultsRowId,
        targetIndex,
      )) {
        _pendingGridFocusIndex = null;
        _focusNode.unfocus();
        setState(() {
          _gridFocusedIndex = targetIndex;
          _helperFocusedIndex = null;
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
    if (!_helpersScrollController.hasClients) return;
    if (_helpersScrollController.offset <= 0) return;
    _helpersScrollController.jumpTo(0);
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
    if (_results.isEmpty) return null;
    return () => _focusResultCardAtVisualLevel(index);
  }

  int _helperItemCount() {
    if (_query.trim().isNotEmpty) return _results.length;
    return _recommendationTitles.length;
  }

  void _focusSearchClose() {
    if (!_closeFocusNode.canRequestFocus) return;
    _closeFocusNode.requestFocus();
    ShellTvFocusCoordinator.saveFocus(
      widget.tvTabId,
      ShellTvFocusMemory(zone: ShellTvZone.topBar, node: _closeFocusNode),
    );
  }

  /// Left from a film card → recommendation at the visually aligned helper row.
  void _focusHelperAtVisualLevelFromGrid(int gridIndex) {
    final count = _helperItemCount();
    if (count <= 0) return;
    final helperRowId = _helpersRowIdForFocus();
    final cardY = _tvItemCenterGlobalY(_resultsRowId, gridIndex);
    if (cardY == null) {
      _focusFirstHelper();
      return;
    }
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < count; i++) {
      final y = _tvItemCenterGlobalY(helperRowId, i);
      if (y == null) continue;
      final dist = (y - cardY).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    _focusHelperAtIndex(best);
  }

  void _focusFilmCardsFromClose() {
    if (_results.isNotEmpty) {
      _focusResultCardAt(0);
      return;
    }
    if (_helperItemCount() > 0) {
      _focusFirstHelper();
    }
  }

  KeyEventResult _searchCloseKeyEvent(FocusNode node, KeyEvent event) {
    if (!mounted || !_tvFocus(context)) return KeyEventResult.ignored;
    if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _focusSearchFieldBrowse();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _focusFilmCardsFromClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _searchFieldKeyEvent(FocusNode node, KeyEvent event) {
    if (!mounted || !_tvFocus(context)) return KeyEventResult.ignored;
    if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      // Browse: trap - nav exit is Down → suggestions → Left.
      // Editing: ignore so the caret can move.
      if (_searchFieldEditing) return KeyEventResult.ignored;
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_helperItemCount() <= 0) return KeyEventResult.ignored;
      _focusFirstHelper();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
        _query.isNotEmpty) {
      _focusSearchClose();
      return KeyEventResult.handled;
    }
    if (shellTvIsActivateKey(event) && !_searchFieldEditing) {
      _beginSearchFieldEditing();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  PreferredSizeWidget _buildCompactAppBar() {
    return AppBar(
      backgroundColor: AppTheme.bgDark,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      titleSpacing: 0,
      title: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        onChanged: _onSearchChanged,
        onSubmitted: (v) => _performSearch(v.trim()),
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: ForjaShellColors.sectionAccent,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: ForjaShellColors.cinematic.textSecondary
                .withValues(alpha: 0.7),
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
        ),
      ),
      actions: [
        if (_controller.text.isNotEmpty)
          ForjaCloseButton.compact(
            tooltip: null,
            color: ForjaShellColors.cinematic.textPrimary,
            focusNode: _closeFocusNode,
            onKeyEvent: _searchCloseKeyEvent,
            onTap: () {
              _controller.clear();
              _onSearchChanged('');
              _focusSearchFieldBrowse();
            },
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return TvFocusGraph(
      tabId: widget.tvTabId,
      child: ValueListenableBuilder<AppThemePreset>(
        valueListenable: AppTheme.themeNotifier,
        builder: (context, _, _) {
          if (_isWideLayout(context)) {
            return ColoredBox(
              color: AppTheme.bgDark,
              child: _buildWideLayout(context),
            );
          }
          return Scaffold(
            backgroundColor: AppTheme.bgDark,
            appBar: _buildCompactAppBar(),
            body: _buildCompactBody(context),
          );
        },
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    final focused = _focusedResult;
    final backdropUrl = focused?.backdropUrl ?? focused?.posterUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (backdropUrl != null && backdropUrl.isNotEmpty)
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: backdropUrl,
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppTheme.bgDark,
                  AppTheme.bgDark.withValues(alpha: 0.92),
                  AppTheme.bgDark.withValues(alpha: 0.55),
                ],
                stops: const [0.0, 0.42, 1.0],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ShellTokens.searchPageInset,
            ShellTokens.searchPageInset,
            ShellTokens.searchPageInset,
            ShellTokens.searchPageInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchField(context),
              const SizedBox(height: 24),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildHelpersList(context),
                    ),
                    const SizedBox(width: ShellTokens.searchColumnGap),
                    Expanded(
                      flex: 7,
                      child: _buildResultsColumn(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final tvFocus = _tvFocus(context);
    final browseOnly = tvFocus && !_searchFieldEditing;
    final hintStyle = TextStyle(
      color: ForjaShellColors.textSecondary.withValues(alpha: 0.7),
      fontSize: 32,
      fontWeight: FontWeight.w600,
      height: 1.15,
    );
    final showBrowsePlaceholder =
        browseOnly && _focusNode.hasFocus && _query.isEmpty;

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          readOnly: browseOnly,
          showCursor: !browseOnly || _query.isNotEmpty,
          enableInteractiveSelection: !browseOnly,
          onChanged: _onSearchChanged,
          style: TextStyle(
            color: ForjaShellColors.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
          cursorColor: ForjaShellColors.textPrimary,
          cursorHeight: 36,
          decoration: InputDecoration(
            hintText: showBrowsePlaceholder ? null : widget.hintText,
            hintStyle: hintStyle,
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            suffixIcon: _query.isNotEmpty
                ? ForjaCloseButton.compact(
                    tooltip: null,
                    color: ForjaShellColors.textSecondary,
                    focusNode: _closeFocusNode,
                    onKeyEvent: _searchCloseKeyEvent,
                    onTap: () {
                      _controller.clear();
                      _onSearchChanged('');
                      _focusSearchFieldBrowse();
                    },
                  )
                : null,
          ),
        ),
        if (showBrowsePlaceholder)
          TvSearchBrowsePlaceholder(
            active: true,
            placeholder: widget.hintText,
            hintStyle: hintStyle,
            caretHeight: 36,
          ),
      ],
    );
  }

  Widget _buildHelperTitle(String title, {required bool selected}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected
                ? ForjaShellColors.textPrimary
                : ForjaShellColors.textSecondary,
            fontSize: selected ? 17 : 15,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            height: 1.25,
          ),
        ),
      ),
    );
  }

  Widget _buildHelpersList(BuildContext context) {
    final hasQuery = _query.trim().isNotEmpty;

    if (hasQuery) {
      if (_results.isEmpty && _isSearching) {
        return Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.current.primaryColor,
            ),
          ),
        );
      }
      if (_results.isEmpty) return const SizedBox.shrink();

      return TvCatalogRow(
        tabId: widget.tvTabId,
        rowId: _helperResultsRowId,
        sortOrder: 0,
        itemCount: _results.length,
        orientation: ShellTvRowOrientation.vertical,
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: ListView.separated(
            controller: _helpersScrollController,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            itemCount: _results.length,
            separatorBuilder: (_, _) => const SizedBox(height: 2),
            itemBuilder: (context, index) {
              final item = _results[index];
              final count = _results.length;
              return shellFocusableTap(
                context: context,
                onTap: () => _focusResultCardAt(index),
                borderRadius: 4,
                scaleOnFocus: 1.0,
                navLeftAlways: true,
                listIndex: index,
                tvTabId: widget.tvTabId,
                tvRowId: _helperResultsRowId,
                tvZone: ShellTvZone.chipStrip,
                tvItemIndex: index,
                focusNode: index == 0 ? _firstHelperFocusNode : null,
                onUpEdge: _helperUpEdge(index),
                onDownEdge: _helperDownEdge(index, count),
                onRightEdge: _helperRightEdge(index),
                ensureVisibleMode: ShellTvEnsureVisibleMode.row,
                onFocusChange: (focused) {
                  setState(() {
                    if (focused) {
                      _helperFocusedIndex = index;
                    } else if (_helperFocusedIndex == index) {
                      _helperFocusedIndex = null;
                    }
                  });
                },
                child: _buildHelperTitle(
                  item.title,
                  selected: _helperFocusedIndex == index,
                ),
              );
            },
          ),
        ),
      );
    }

    if (_recommendationTitles.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return TvCatalogRow(
      tabId: widget.tvTabId,
      rowId: _helpersRowId,
      sortOrder: 0,
      itemCount: _recommendationTitles.length,
      orientation: ShellTvRowOrientation.vertical,
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: ListView.separated(
          controller: _helpersScrollController,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.only(right: 8, bottom: 8),
          itemCount: _recommendationTitles.length,
          separatorBuilder: (_, _) => const SizedBox(height: 2),
          itemBuilder: (context, index) {
            final title = _recommendationTitles[index];
            final count = _recommendationTitles.length;
            return shellFocusableTap(
              context: context,
              onTap: () => _applyHelperQuery(title),
              borderRadius: 4,
              scaleOnFocus: 1.0,
              navLeftAlways: true,
              listIndex: index,
              tvTabId: widget.tvTabId,
              tvRowId: _helpersRowId,
              tvZone: ShellTvZone.chipStrip,
              tvItemIndex: index,
              focusNode: index == 0 ? _firstHelperFocusNode : null,
              onUpEdge: _helperUpEdge(index),
              onDownEdge: _helperDownEdge(index, count),
              onRightEdge: _helperRightEdge(index),
              ensureVisibleMode: ShellTvEnsureVisibleMode.row,
              onFocusChange: (focused) {
                setState(() {
                  if (focused) {
                    _helperFocusedIndex = index;
                  } else if (_helperFocusedIndex == index) {
                    _helperFocusedIndex = null;
                  }
                });
              },
              child: _buildHelperTitle(
                title,
                selected: _helperFocusedIndex == index,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildResultsColumn(BuildContext context) {
    if (_query.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: _buildEmpty(hint: 'Start typing to search'),
      );
    }
    if (_error != null) {
      return Align(
        alignment: Alignment.topLeft,
        child: _buildError(),
      );
    }
    if (_results.isEmpty && _isSearching) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.current.primaryColor),
      );
    }
    if (_results.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: _buildEmpty(hint: 'No results found'),
      );
    }

    const gridColumns = 4;
    final tvFocus = _tvFocus(context);

    return TvGrid(
      tabId: widget.tvTabId,
      rowId: _resultsRowId,
      sortOrder: 1,
      columns: gridColumns,
      itemCount: _results.length,
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: GridView.builder(
          controller: _resultsScrollController,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.only(bottom: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridColumns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 14,
            childAspectRatio: 2 / 3,
          ),
          itemCount: _results.length,
          itemBuilder: (context, index) {
            final item = _results[index];
            final firstColumn = index % gridColumns == 0;
            final firstRow = index ~/ gridColumns == 0;
            return Padding(
              padding: const EdgeInsets.all(4),
              child: _HubSearchFilmCard(
                result: item,
                selected: index == _gridFocusedIndex,
                gridIndex: index,
                onTap: () => setState(() => _gridFocusedIndex = index),
                onOpen: () => widget.onOpen(item),
                onLeftEdge: firstColumn && tvFocus
                    ? () => _focusHelperAtVisualLevelFromGrid(index)
                    : null,
                onUpEdge: firstRow && tvFocus ? _focusSearchFieldBrowse : null,
                onFocusChange: (focused) {
                  if (focused) {
                    setState(() {
                      _gridFocusedIndex = index;
                      _helperFocusedIndex = null;
                    });
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompactBody(BuildContext context) {
    if (_error != null) return _buildError();
    if (_query.isEmpty) return _buildEmpty();
    if (_isSearching && _results.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.current.primaryColor),
      );
    }
    if (_results.isEmpty) {
      return _buildEmpty(hint: 'No results found');
    }

    final cardWidth = ShellTokens.searchCardWidthCompact;
    final cardHeight = cardWidth * 1.5;
    final padding = ShellTokens.homeSectionHorizontalPadding;

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(padding, 12, padding, 24),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: cardWidth + 16,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: cardWidth / cardHeight,
      ),
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final item = _results[i];
        return Align(
          alignment: Alignment.topCenter,
          child: _HubSearchCompactCard(
            result: item,
            onTap: () => widget.onOpen(item),
          ),
        );
      },
    );
  }

  Widget _buildEmpty({String? hint}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: Colors.white.withValues(alpha: 0.05),
          ),
          const SizedBox(height: 16),
          Text(
            hint ??
                (_query.isEmpty
                    ? 'Search for your favorite content'
                    : 'No results found'),
            style: const TextStyle(color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return ShellErrorRetryPanel(
      message: _error!,
      onRetry: () => _performSearch(_query),
    );
  }
}

class _HubSearchFilmCard extends StatefulWidget {
  const _HubSearchFilmCard({
    required this.result,
    required this.selected,
    required this.onTap,
    required this.onOpen,
    this.onFocusChange,
    this.onLeftEdge,
    this.onUpEdge,
    this.gridIndex,
  });

  final HubSearchResult result;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final ValueChanged<bool>? onFocusChange;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onUpEdge;
  final int? gridIndex;

  @override
  State<_HubSearchFilmCard> createState() => _HubSearchFilmCardState();
}

class _HubSearchFilmCardState extends State<_HubSearchFilmCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final titleSize = shellHubCardTitleFontSize(context);
    final tvActivateOpens =
        ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final grid = TvGridScope.maybeOf(context);
    final index = widget.gridIndex;
    final meta = index != null ? grid?.metaFor(index) : null;

    return shellFocusableTap(
      context: context,
      onTap: tvActivateOpens ? widget.onOpen : widget.onTap,
      borderRadius: 14,
      showFocusBorder: true,
      onLeftEdge: widget.onLeftEdge,
      onUpEdge: widget.onUpEdge,
      gridIndex: meta?.gridIndex ?? index,
      gridColumns: meta?.gridColumns,
      tvTabId: meta?.tvTabId,
      tvRowId: meta?.tvRowId,
      tvZone: meta?.tvZone ?? ShellTvZone.grid,
      tvItemIndex: meta?.tvItemIndex ?? index,
      onFocusChange: widget.onFocusChange,
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: GestureDetector(
        onDoubleTap: widget.onOpen,
        child: SizedBox.expand(
          child: AnimatedContainer(
            duration: ShellTokens.navSelectionAnimation,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: widget.selected
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: widget.selected ? 0.65 : 0.5,
                  ),
                  blurRadius: widget.selected ? 20 : 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: AppTheme.bgDark,
                    child: widget.result.posterUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.result.posterUrl,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                            placeholder: (_, _) =>
                                ColoredBox(color: AppTheme.bgDark),
                            errorWidget: (_, _, _) => Center(
                              child: Text(
                                widget.result.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              widget.result.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white24,
                              ),
                            ),
                          ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.95),
                        ],
                        stops: const [0.0, 0.45, 0.8, 1.0],
                      ),
                    ),
                  ),
                  if (_hovered)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.35),
                        child: Center(
                          child: Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              hoverColor: ForjaShellColors.inkHover,
                              splashColor: ForjaShellColors.inkSplash,
                              highlightColor: ForjaShellColors.inkSplash,
                              onTap: widget.onOpen,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (widget.result.rating != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              widget.result.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.result.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: titleSize,
                            height: 1.2,
                          ),
                        ),
                        if (widget.result.subtitle != null &&
                            widget.result.subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.result.subtitle!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HubSearchCompactCard extends StatelessWidget {
  const _HubSearchCompactCard({
    required this.result,
    required this.onTap,
  });

  final HubSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardWidth = ShellTokens.searchCardWidthCompact;
    final cardHeight = cardWidth * 1.5;

    return shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: 12,
      showFocusBorder: true,
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (result.posterUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: result.posterUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: AppTheme.bgCard),
                errorWidget: (_, _, _) =>
                    const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    result.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            if (result.rating != null)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    result.rating!.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Text(
                  result.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
