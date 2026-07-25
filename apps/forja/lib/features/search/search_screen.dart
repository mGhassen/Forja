import 'dart:async';
import 'package:rust/rust.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_search_bar.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/horizontal_scroller.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/widgets/tv_search_browse_overlay.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';

part 'search_models.dart';
part 'search_widgets.dart';
part 'search_search.dart';
part 'search_tv.dart';
part 'search_build.dart';

/// Search tab - RFC-024 R24-A11: query-driven only; no ShellTabRefresh / auto stale refetch.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.overlay = false});

  /// Slide-in overlay from Home / hubs (vs mounted Search tab).
  final bool overlay;

  @override
  State<SearchScreen> createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin, _SearchSearch, _SearchTv, _SearchBuild {
  final TextEditingController _controller = TextEditingController();
  final TmdbApi _api = TmdbApi();
  final StremioService _stremio = StremioService();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _closeFocusNode = FocusNode(debugLabel: 'search-close');
  final FocusNode _firstHelperFocusNode = FocusNode();
  final ScrollController _helpersScrollController = ScrollController();
  final ScrollController _resultsScrollController = ScrollController();

  Timer? _debounce;
  String _query = '';

  /// All search-capable addon providers (loaded once).
  List<Map<String, dynamic>> _addonProviders = [];

  /// Currently visible sections (populated dynamically as results arrive).
  final List<_SearchSection> _sections = [];

  /// Track which search generation we're on to discard stale results.
  int _searchGeneration = 0;

  /// True while at least one provider hasn't responded yet.
  bool _isSearching = false;

  int? _helperFocusedIndex;
  int? _gridFocusedIndex;

  /// After picking a proposition, focus the matching grid card once results exist.
  int? _pendingGridFocusIndex;

  List<String> _trendingHelperTitles = [];
  bool _searchFieldEditing = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    ShellTvFocusCoordinator.registerTabDefaults(
      'search',
      defaultFocus: () => _focusNode,
      enterFromNavFocus: _focusSearchFieldBrowse,
      restoreFocus: _restoreSearchTvFocusIfEmpty,
    );
    ShellBus.registerFindShortcutHandler(_handleFindShortcut);
    _focusNode.addListener(_onSearchFieldFocusChange);
    _focusNode.onKeyEvent = _searchFieldKeyEvent;
    _loadProviders();
    _loadTrendingHelpers();
    ShellBus.stremioSearchNotifier.addListener(_onExternalSearch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ShellBus.notifyShellChromeChanged();
      // Overlay from Home (incl. TV desktop layout) must land on the field.
      if (widget.overlay && mounted) {
        _focusSearchFieldBrowse();
      }
    });
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
    _firstHelperFocusNode.dispose();
    _helpersScrollController.dispose();
    _resultsScrollController.dispose();
    super.dispose();
  }

}

