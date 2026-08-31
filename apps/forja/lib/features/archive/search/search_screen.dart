import 'dart:async';
import 'package:rust/rust.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/archive/search/providers/search_providers.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_search_bar.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/search/search_recent_queries.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/horizontal_scroller.dart';
import 'package:forja/shared/widgets/recent_search_helper_tile.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/widgets/tv_search_browse_overlay.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

part 'search_models.dart';
part 'search_widgets.dart';
part 'search_search.dart';
part 'search_tv.dart';
part 'search_filters.dart';
part 'search_build.dart';

/// Search tab - RFC-024 R24-A11: query-driven only; no ShellTabRefresh / auto stale refetch.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.overlay = false});

  /// Slide-in overlay from Home / hubs (vs mounted Search tab).
  final bool overlay;

  @override
  ConsumerState<SearchScreen> createState() => SearchScreenState();
}

class SearchScreenState extends ConsumerState<SearchScreen>
    with AutomaticKeepAliveClientMixin, _SearchSearch, _SearchTv, _SearchBuild {
  final TextEditingController _controller = TextEditingController();
  final TmdbApi _api = TmdbApi();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _closeFocusNode = FocusNode(debugLabel: 'search-close');
  final FocusNode _firstHelperFocusNode = FocusNode();
  final ScrollController _helpersScrollController = ScrollController();
  final ScrollController _resultsScrollController = ScrollController();

  Timer? _debounce;
  String _query = '';

  /// Debounced query driving [searchResultsProvider].
  String _activeSearchQuery = '';

  /// Currently visible sections (from Riverpod search results).
  List<_SearchSection> _sections = [];

  /// True while [searchResultsProvider] is loading for [_activeSearchQuery].
  bool _isSearching = false;

  int? _helperFocusedIndex;
  int? _gridFocusedIndex;

  /// After picking a proposition, focus the matching grid card once results exist.
  int? _pendingGridFocusIndex;

  /// Last typed queries for the empty-state helpers column (before trending).
  List<String> _recentQueries = const [];

  bool _searchFieldEditing = false;

  /// Ignore IME/key submit from the same OK that opened the field.
  /// Android TV OK often delivers both Select and Enter.
  bool _searchSubmitArmed = false;

  SearchFilters _filters = SearchFilters.empty;
  bool _filtersOpen = false;
  final FocusNode _filterFocusNode = FocusNode(debugLabel: 'search-filter');
  /// First control in the open filter lens (All type chip) — Down from field.
  final FocusNode _filterLensFirstFocusNode =
      FocusNode(debugLabel: 'search-filter-lens-first');
  int _searchEditEpoch = 0;

  /// Cached for debounce/invalidate without inherited lookup on inactive elements.
  ProviderContainer? _container;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    TvHeroActions.bind(
      'search',
      defaultFocus: () => _focusNode,
      enterFromNavFocus: _focusSearchFieldBrowse,
      restoreFocus: _restoreSearchTvFocusIfEmpty,
    );
    ShellBus.registerFindShortcutHandler(_handleFindShortcut);
    _focusNode.addListener(_onSearchFieldFocusChange);
    _focusNode.onKeyEvent = _searchFieldKeyEvent;
    ShellBus.stremioSearchNotifier.addListener(_onExternalSearch);
    _loadRecentQueries();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ShellBus.notifyShellChromeChanged();
      // Overlay from Home (incl. TV desktop layout) must land on the field.
      if (widget.overlay && mounted) {
        _focusSearchFieldBrowse();
      }
    });
  }

  Future<void> _loadRecentQueries() async {
    final recent = await SearchRecentQueries.load(SearchRecentQueries.scopeSearch);
    if (!mounted) return;
    setState(() => _recentQueries = recent);
  }


  void focusFromFindShortcut() => _focusSearchFieldBrowse();

  bool _handleFindShortcut() {
    _focusSearchFieldBrowse();
    return true;
  }

  @override
  void dispose() {
    ShellBus.unregisterFindShortcutHandler(_handleFindShortcut);
    _focusNode.removeListener(_onSearchFieldFocusChange);
    ShellTvFocusCoordinator.clearTab('search');
    ShellBus.stremioSearchNotifier.removeListener(_onExternalSearch);
    _controller.dispose();
    _debounce?.cancel();
    _focusNode.dispose();
    _closeFocusNode.dispose();
    _filterFocusNode.dispose();
    _filterLensFirstFocusNode.dispose();
    _firstHelperFocusNode.dispose();
    _helpersScrollController.dispose();
    _resultsScrollController.dispose();
    super.dispose();
  }

}

