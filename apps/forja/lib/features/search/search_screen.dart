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
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';

/// A single result section that streams in dynamically.
class _SearchSection {
  final String key;
  final String title;
  final String? icon; // network icon URL (for addon sections)
  final bool isTmdb;
  List<dynamic> results; // Movie for TMDB, Map<String,dynamic> for addons

  _SearchSection({
    required this.key,
    required this.title,
    this.icon,
    this.isTmdb = false,
    List<dynamic>? results,
  }) : results = results ?? [];
}

class _FlatSearchResult {
  const _FlatSearchResult({
    required this.key,
    required this.title,
    required this.overview,
    required this.posterUrl,
    this.backdropUrl,
    this.year,
    this.rating,
    required this.isTmdb,
    required this.raw,
  });

  final String key;
  final String title;
  final String overview;
  final String posterUrl;
  final String? backdropUrl;
  final String? year;
  final double? rating;
  final bool isTmdb;
  final dynamic raw;
}

/// Search tab — RFC-024 R24-A11: query-driven only; no ShellTabRefresh / auto stale refetch.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.overlay = false});

  /// Slide-in overlay from Home / hubs (vs mounted Search tab).
  final bool overlay;

  @override
  State<SearchScreen> createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _controller = TextEditingController();
  final TmdbApi _api = TmdbApi();
  final StremioService _stremio = StremioService();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _firstHelperFocusNode = FocusNode();

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
  int _gridFocusedIndex = 0;

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
    );
    _focusNode.addListener(_onSearchFieldFocusChange);
    _focusNode.onKeyEvent = _searchFieldKeyEvent;
    _loadProviders();
    _loadTrendingHelpers();
    ShellBus.stremioSearchNotifier.addListener(_onExternalSearch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ShellBus.notifyShellChromeChanged();
      if (widget.overlay && mounted && !_isDesktopLayout(context)) {
        _focusNode.requestFocus();
      }
    });
  }

  Future<void> _loadProviders() async {
    final catalogs = await _stremio.getAllCatalogs();
    final Map<String, Map<String, dynamic>> providers = {};
    for (final c in catalogs) {
      if (c['supportsSearch'] != true) continue;
      final key = c['addonBaseUrl'] as String;
      if (!providers.containsKey(key)) {
        providers[key] = {
          'id': key,
          'name': c['addonName'],
          'icon': c['addonIcon'],
          'baseUrl': key,
          'catalogs': <Map<String, dynamic>>[],
        };
      }
      (providers[key]!['catalogs'] as List).add(c);
    }
    if (mounted) {
      setState(() => _addonProviders = providers.values.toList());
    }
  }

  Future<void> _loadTrendingHelpers() async {
    try {
      final movies = await _api.getTrending();
      final shows = await _api.getTrendingTv();
      final titles = <String>[];
      for (final item in [...movies, ...shows]) {
        if (item.title.isEmpty || titles.contains(item.title)) continue;
        titles.add(item.title);
        if (titles.length >= 12) break;
      }
      if (mounted) {
        setState(() => _trendingHelperTitles = titles);
        shellTvRegisterRow(
          tabId: 'search',
          rowId: 'helpers',
          sortOrder: 0,
          itemCount: titles.length,
        );
        if (_query.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_tvFocus(context) &&
                ShellTvFocus.currentNavTabId == 'search' &&
                !_focusNode.hasFocus) {
              _focusSearchFieldBrowse();
            }
          });
        }
      }
    } catch (_) {}
  }

  void _applyHelperQuery(String title) {
    _pendingGridFocusIndex = 0;
    _controller.text = title;
    _onSearchChanged(title);
  }

  void _onExternalSearch() async {
    final data = ShellBus.stremioSearchNotifier.value;
    if (data == null || (data['query'] ?? '').isEmpty) return;
    final query = data['query']!;
    if (_addonProviders.isEmpty) await _loadProviders();
    if (mounted) {
      _controller.text = query;
      _onSearchChanged(query);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _query = query;
      _helperFocusedIndex = null;
      _gridFocusedIndex = 0;
    });
    ShellBus.notifyShellChromeChanged();
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _sections.clear();
        _isSearching = false;
        _helperFocusedIndex = null;
      _gridFocusedIndex = 0;
        _pendingGridFocusIndex = null;
      });
      if (_tvFocus(context) && _focusNode.hasFocus) {
        _focusSearchFieldBrowse();
      } else if (_tvFocus(context) && _trendingHelperTitles.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusFirstHelper();
        });
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performUnifiedSearch(query);
    });
  }

  /// Fire all search APIs in parallel; results stream in as they arrive.
  Future<void> _performUnifiedSearch(String query) async {
    if (query.trim().isEmpty) return;

    final gen = ++_searchGeneration;
    setState(() {
      _sections.clear();
      _isSearching = true;
      _helperFocusedIndex = null;
      _gridFocusedIndex = 0;
    });

    int pendingCount = 1 + _addonProviders.length; // TMDB + each addon

    void decPending() {
      pendingCount--;
      if (pendingCount <= 0 && gen == _searchGeneration && mounted) {
        setState(() => _isSearching = false);
      }
    }

    // ── TMDB ──
    _searchTmdb(query, gen).then((_) => decPending());

    // ── Stremio Addons ──
    for (final provider in _addonProviders) {
      _searchAddon(query, provider, gen).then((_) => decPending());
    }
  }

  Future<void> _searchTmdb(String query, int gen) async {
    try {
      final results = await _api.searchMulti(query);
      if (gen != _searchGeneration || !mounted) return;

      final movies = results.where((m) => m.mediaType == 'movie').toList();
      final shows = results.where((m) => m.mediaType == 'tv').toList();

      setState(() {
        if (movies.isNotEmpty) {
          _sections.insert(0, _SearchSection(
            key: 'tmdb_movies',
            title: 'TMDB Movies',
            isTmdb: true,
            results: movies,
          ));
        }
        if (shows.isNotEmpty) {
          // Insert after tmdb_movies if it exists, else at 0
          final idx = _sections.indexWhere((s) => s.key == 'tmdb_movies');
          _sections.insert(idx >= 0 ? idx + 1 : 0, _SearchSection(
            key: 'tmdb_shows',
            title: 'TMDB Shows',
            isTmdb: true,
            results: shows,
          ));
        }
      });
      _scheduleFocusOnResultCardIfPending();
    } catch (e) {
      debugPrint('TMDB search error: $e');
    }
  }

  Future<void> _searchAddon(String query, Map<String, dynamic> provider, int gen) async {
    final providerBaseUrl = provider['baseUrl'] as String;
    final providerName = provider['name'] as String;
    final providerIcon = provider['icon']?.toString() ?? '';
    final catalogs = provider['catalogs'] as List<Map<String, dynamic>>;

    // Group results by type (movie / series)
    final Map<String, List<Map<String, dynamic>>> byType = {};

    await Future.wait(catalogs.map((cat) async {
      try {
        final results = await _stremio.getCatalog(
          baseUrl: cat['addonBaseUrl'],
          type: cat['catalogType'],
          id: cat['catalogId'],
          search: query,
        );
        for (final r in results) {
          r['_addonBaseUrl'] = providerBaseUrl;
          r['_addonName'] = providerName;
        }
        final type = cat['catalogType']?.toString() ?? 'other';
        byType.putIfAbsent(type, () => []);
        byType[type]!.addAll(results);
      } catch (_) {}
    }));

    if (gen != _searchGeneration || !mounted) return;

    setState(() {
      for (final entry in byType.entries) {
        // Deduplicate within this type
        final seen = <String>{};
        final deduped = entry.value.where((r) {
          final id = r['id']?.toString() ?? '';
          if (id.isEmpty || seen.contains(id)) return false;
          seen.add(id);
          return true;
        }).toList();

        if (deduped.isEmpty) continue;

        final typeLabel = entry.key == 'series' ? 'Shows' : (entry.key == 'movie' ? 'Movies' : entry.key);
        _sections.add(_SearchSection(
          key: '${providerBaseUrl}_${entry.key}',
          title: '$providerName $typeLabel',
          icon: providerIcon,
          results: deduped,
        ));
      }
    });
    _scheduleFocusOnResultCardIfPending();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation helpers (unchanged from original)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _openDetails(Movie movie) async {
    if (!mounted) return;
    await AppRouter.openMovie(context, movie: movie);
  }

  Future<void> _openStremioItem(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    final type = item['type']?.toString() ?? 'movie';
    final name = item['name']?.toString() ?? 'Unknown';
    final poster = item['poster']?.toString() ?? '';
    final isCustomId = !id.startsWith('tt');
    final isCollection = id.startsWith('ctmdb.') || type == 'collections';

    if (!isCustomId && !isCollection) {
      try {
        final movie = await _api.findByImdbId(id, mediaType: type == 'series' ? 'tv' : 'movie');
        if (movie != null && mounted) {
          await AppRouter.openDetails(context, movie: movie, stremioItem: item);
          return;
        }
      } catch (_) {}
    }

    if (!isCustomId && !isCollection) {
      try {
        final results = await _api.searchMulti(name);
        if (results.isNotEmpty && mounted) {
          final match = results.firstWhere(
            (m) => m.title.toLowerCase() == name.toLowerCase(),
            orElse: () => results.first,
          );
          await AppRouter.openDetails(context, movie: match, stremioItem: item);
          return;
        }
      } catch (_) {}
    }

    if (mounted) {
      final actualType = isCollection ? 'collections' : (type == 'series' ? 'tv' : 'movie');
      final movie = Movie(
        id: id.hashCode,
        imdbId: id.startsWith('tt') ? id : null,
        title: name,
        posterPath: poster,
        backdropPath: item['background']?.toString() ?? poster,
        voteAverage: double.tryParse(item['imdbRating']?.toString() ?? '') ?? 0,
        releaseDate: item['releaseInfo']?.toString() ?? '',
        overview: item['description']?.toString() ?? '',
        mediaType: actualType,
      );
      final updatedItem = Map<String, dynamic>.from(item);
      if (isCollection) updatedItem['type'] = 'collections';
      await AppRouter.openDetails(context, movie: movie, stremioItem: updatedItem);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onSearchFieldFocusChange);
    ShellTvFocusCoordinator.clearTab('search');
    ShellBus.stremioSearchNotifier.removeListener(_onExternalSearch);
    _controller.dispose();
    _debounce?.cancel();
    _focusNode.dispose();
    _firstHelperFocusNode.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────────────────

  List<_FlatSearchResult> _flatResults() {
    final seen = <String>{};
    final out = <_FlatSearchResult>[];
    for (final section in _sections) {
      for (final item in section.results) {
        if (item is Movie) {
          final key = 'tmdb:${item.id}:${item.mediaType}';
          if (!seen.add(key)) continue;
          out.add(_FlatSearchResult(
            key: key,
            title: item.title,
            overview: item.overview,
            posterUrl: item.posterPath.isNotEmpty ? TmdbApi.getImageUrl(item.posterPath) : '',
            backdropUrl: item.backdropPath.isNotEmpty ? TmdbApi.getImageUrl(item.backdropPath) : null,
            year: item.releaseDate.length >= 4 ? item.releaseDate.substring(0, 4) : null,
            rating: item.voteAverage > 0 ? item.voteAverage : null,
            isTmdb: true,
            raw: item,
          ));
        } else {
          final map = item as Map<String, dynamic>;
          final id = map['id']?.toString() ?? map['name']?.toString() ?? '';
          final key = 'addon:$id';
          if (id.isEmpty || !seen.add(key)) continue;
          final poster = map['poster']?.toString() ?? '';
          final ratingStr = map['imdbRating']?.toString() ?? '';
          out.add(_FlatSearchResult(
            key: key,
            title: map['name']?.toString() ?? 'Unknown',
            overview: map['description']?.toString() ?? '',
            posterUrl: poster,
            backdropUrl: map['background']?.toString() ?? poster,
            year: map['releaseInfo']?.toString(),
            rating: double.tryParse(ratingStr),
            isTmdb: false,
            raw: map,
          ));
        }
      }
    }
    return out;
  }

  _FlatSearchResult? get _focusedResult {
    final results = _flatResults();
    if (results.isEmpty) return null;
    final index = _gridFocusedIndex.clamp(0, results.length - 1);
    return results[index];
  }

  void _openResult(_FlatSearchResult result) {
    if (result.isTmdb) {
      _openDetails(result.raw as Movie);
    } else {
      _openStremioItem(result.raw as Map<String, dynamic>);
    }
  }

  void _clearHelperFocusedIndex(int index) {
    if (_helperFocusedIndex == index) {
      setState(() => _helperFocusedIndex = null);
    }
  }

  void _setHelperFocusedIndex(int index) {
    final count = _helperItemCount();
    if (count == 0) return;
    setState(() => _helperFocusedIndex = index.clamp(0, count - 1));
  }

  void _setGridFocusedIndex(int index) {
    final count = _flatResults().length;
    if (count == 0) return;
    setState(() => _gridFocusedIndex = index.clamp(0, count - 1));
  }

  int _helperItemCount() {
    if (_query.trim().isNotEmpty) return _flatResults().length;
    return _trendingHelperTitles.length;
  }

  void _focusResultCardAt(int index) {
    final count = _flatResults().length;
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
      ShellTvFocusCoordinator.focusRowItem('search', 'results', clamped);
    });
  }

  void _focusResultCard() => _focusResultCardAt(_gridFocusedIndex);

  void _scheduleFocusOnResultCardIfPending() {
    final pending = _pendingGridFocusIndex;
    if (pending == null) return;
    final count = _flatResults().length;
    if (count == 0) return;

    _pendingGridFocusIndex = null;
    _focusNode.unfocus();
    final index = pending.clamp(0, count - 1);
    if (_gridFocusedIndex != index) {
      setState(() => _gridFocusedIndex = index);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ShellTvFocusCoordinator.focusRowItem('search', 'results', index);
    });
  }

  bool _isDesktopLayout(BuildContext context) => shellUsesWideLayout(context);

  bool _tvFocus(BuildContext context) =>
      ShellScope.inputPolicyOf(context).useFocusableMoodChips;

  void _syncHelperResultsRow(int count) {
    if (count <= 0) {
      shellTvUnregisterRow(tabId: 'search', rowId: 'helper-results');
      return;
    }
    shellTvRegisterRow(
      tabId: 'search',
      rowId: 'helper-results',
      sortOrder: 0,
      itemCount: count,
    );
  }

  void _focusHelperAtIndex(int index) {
    final rowId = _query.trim().isEmpty ? 'helpers' : 'helper-results';
    final count = _helperItemCount();
    if (count == 0) return;
    final clamped = index.clamp(0, count - 1);
    setState(() => _helperFocusedIndex = clamped);
    final node = ShellTvFocusCoordinator.itemNode('search', rowId, clamped);
    if (node != null && node.canRequestFocus) {
      node.requestFocus();
      return;
    }
    _focusFirstHelper();
  }

  void _focusHelperAtLast() => _focusHelperAtIndex(_helperFocusedIndex ?? 0);

  void _onSearchFieldFocusChange() {
    if (!_focusNode.hasFocus) {
      if (_searchFieldEditing && mounted) {
        setState(() => _searchFieldEditing = false);
      }
      return;
    }
    ShellTvFocusCoordinator.saveFocus(
      'search',
      ShellTvFocusMemory(zone: ShellTvZone.topBar, node: _focusNode),
    );
  }

  void _focusSearchFieldBrowse() {
    if (!_focusNode.canRequestFocus) return;
    if (_searchFieldEditing) {
      setState(() => _searchFieldEditing = false);
    }
    _focusNode.requestFocus();
  }

  void _beginSearchFieldEditing() {
    setState(() => _searchFieldEditing = true);
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  bool _focusFirstHelper() {
    if (!_firstHelperFocusNode.canRequestFocus) return false;
    _firstHelperFocusNode.requestFocus();
    return true;
  }

  KeyEventResult _searchFieldKeyEvent(FocusNode node, KeyEvent event) {
    if (!mounted || !_tvFocus(context)) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        _focusFirstHelper()) {
      return KeyEventResult.handled;
    }
    if (shellTvIsActivateKey(event) && !_searchFieldEditing) {
      _beginSearchFieldEditing();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  double _searchPageTopInset(BuildContext context) => ShellTokens.searchPageInset;

  PreferredSizeWidget _buildOverlayAppBar() {
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
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: ForjaShellColors.sectionAccent,
        decoration: InputDecoration(
          hintText: 'Search movies, shows…',
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
            onTap: () {
              _controller.clear();
              _onSearchChanged('');
            },
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget buildShellSearchBar() {
    if (_isDesktopLayout(context)) return const SizedBox.shrink();
    return ShellSearchBar(
      controller: _controller,
      focusNode: _focusNode,
      query: _query,
      onChanged: _onSearchChanged,
      onClear: () {
        _controller.clear();
        _onSearchChanged('');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.overlay) {
      return ValueListenableBuilder<AppThemePreset>(
        valueListenable: AppTheme.themeNotifier,
        builder: (context, _, _) {
          if (_isDesktopLayout(context)) {
            return ColoredBox(
              color: AppTheme.bgDark,
              child: _buildDesktopLayout(context),
            );
          }
          return Scaffold(
            backgroundColor: AppTheme.bgDark,
            appBar: _buildOverlayAppBar(),
            body: _buildMobileBody(context),
          );
        },
      );
    }

    if (_isDesktopLayout(context)) {
      return _buildDesktopLayout(context);
    }
    return _buildMobileBody(context);
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final focused = _focusedResult;
    final results = _flatResults();
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
          padding: EdgeInsets.fromLTRB(
            ShellTokens.searchPageInset,
            _searchPageTopInset(context),
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
                      child: _buildHelpersList(context, results),
                    ),
                    const SizedBox(width: ShellTokens.searchColumnGap),
                    Expanded(
                      flex: 7,
                      child: _buildResultsColumn(context, results),
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
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: !tvFocus,
      readOnly: browseOnly,
      showCursor: !browseOnly,
      enableInteractiveSelection: !browseOnly,
      onChanged: _onSearchChanged,
      style: TextStyle(
        color: ForjaShellColors.textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.15,
      ),
      cursorColor: ForjaShellColors.textPrimary,
      decoration: InputDecoration(
        hintText: 'Search movies, shows...',
        hintStyle: TextStyle(
          color: ForjaShellColors.textSecondary.withValues(alpha: 0.7),
          fontSize: 32,
          fontWeight: FontWeight.w600,
        ),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        suffixIcon: _query.isNotEmpty
            ? ForjaCloseButton.compact(
                tooltip: null,
                color: ForjaShellColors.textSecondary,
                onTap: () {
                  _controller.clear();
                  _onSearchChanged('');
                },
              )
            : null,
      ),
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

  Widget _buildHelpersList(BuildContext context, List<_FlatSearchResult> results) {
    final hasQuery = _query.trim().isNotEmpty;

    if (hasQuery) {
      if (results.isEmpty && _isSearching) {
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
      if (results.isEmpty) return const SizedBox.shrink();

      _syncHelperResultsRow(results.length);

      return FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ListView.separated(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        itemCount: results.length,
        separatorBuilder: (_, _) => const SizedBox(height: 2),
        itemBuilder: (context, index) {
          final item = results[index];
          return shellFocusableTap(
            context: context,
            onTap: () => _focusResultCardAt(index),
            borderRadius: 4,
            scaleOnFocus: 1.0,
            navLeftAlways: true,
            listIndex: index,
            tvTabId: 'search',
            tvRowId: 'helper-results',
            tvZone: ShellTvZone.chipStrip,
            tvItemIndex: index,
            focusNode: index == 0 ? _firstHelperFocusNode : null,
            onUpEdge: index == 0 ? _focusSearchFieldBrowse : null,
            onRightEdge: _focusResultCard,
            onFocusChange: (focused) {
              if (focused) {
                _setHelperFocusedIndex(index);
              } else {
                _clearHelperFocusedIndex(index);
              }
            },
            child: _buildHelperTitle(
              item.title,
              selected: _helperFocusedIndex == index,
            ),
          );
        },
      ),
      );
    }

    if (_trendingHelperTitles.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: ListView.separated(
      clipBehavior: Clip.none,
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      itemCount: _trendingHelperTitles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final title = _trendingHelperTitles[index];
        return shellFocusableTap(
          context: context,
          onTap: () => _applyHelperQuery(title),
          borderRadius: 4,
          scaleOnFocus: 1.0,
          navLeftAlways: true,
          listIndex: index,
          tvTabId: 'search',
          tvRowId: 'helpers',
          tvZone: ShellTvZone.chipStrip,
          tvItemIndex: index,
          focusNode: index == 0 ? _firstHelperFocusNode : null,
          onUpEdge: index == 0 ? _focusSearchFieldBrowse : null,
          onFocusChange: (focused) {
            if (focused) {
              _setHelperFocusedIndex(index);
            } else {
              _clearHelperFocusedIndex(index);
            }
          },
          child: _buildHelperTitle(
            title,
            selected: _helperFocusedIndex == index,
          ),
        );
      },
    ),
    );
  }

  Widget _buildResultsColumn(
    BuildContext context,
    List<_FlatSearchResult> results,
  ) {
    if (_query.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: _buildEmpty(hint: 'Start typing to search'),
      );
    }
    if (results.isEmpty && _isSearching) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.current.primaryColor),
      );
    }
    if (results.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: _buildEmpty(hint: 'No results found'),
      );
    }

    const gridColumns = 4;
    final tvFocus = _tvFocus(context);

    if (tvFocus && results.isNotEmpty) {
      shellTvRegisterRow(
        tabId: 'search',
        rowId: 'results',
        sortOrder: 1,
        itemCount: results.length,
      );
    }

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: GridView.builder(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(bottom: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: gridColumns,
          mainAxisSpacing: 16,
          crossAxisSpacing: 14,
          childAspectRatio: 2 / 3,
        ),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final item = results[index];
          final firstColumn = index % gridColumns == 0;
          return Padding(
            padding: const EdgeInsets.all(4),
            child: _SearchFilmCard(
              result: item,
              selected: index == _gridFocusedIndex,
              gridIndex: index,
              gridColumns: gridColumns,
              onTap: () => _setGridFocusedIndex(index),
              onOpen: () => _openResult(item),
              onLeftEdge: firstColumn && tvFocus ? _focusHelperAtLast : null,
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
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    final isWide = shellUsesWideLayout(context);
    final bottomPad = isWide ? 24.0 : ShellTokens.bottomNavHeight;

    Widget body;
    if (_query.isEmpty) {
      body = _buildEmpty();
    } else if (_sections.isEmpty && _isSearching) {
      body = Center(child: CircularProgressIndicator(color: AppTheme.current.primaryColor));
    } else if (_sections.isEmpty && !_isSearching) {
      body = _buildEmpty(hint: 'No results found');
    } else {
      body = ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomPad),
        itemCount: _sections.length + (_isSearching ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _sections.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24))),
            );
          }
          final section = _sections[index];
          return _buildSliderSection(section);
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ShellTokens.bodyHorizontalPadding),
      child: body,
    );
  }

  Widget _buildSliderSection(_SearchSection section) {
    final isWide = shellUsesWideLayout(context);
    final cardWidth = isWide
        ? ShellTokens.searchCardWidthDesktop
        : ShellTokens.searchCardWidthCompact;
    final cardHeight = cardWidth * 1.5;

    return Padding(
      padding: const EdgeInsets.only(top: ShellTokens.sectionTopSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (section.icon != null && section.icon!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: section.icon!,
                    width: 20, height: 20,
                    errorWidget: (_, _, _) => const Icon(Icons.extension, size: 16, color: Colors.white38),
                  ),
                ),
                const SizedBox(width: 8),
              ] else if (section.isTmdb) ...[
                const Icon(Icons.movie, size: 18, color: Colors.amber),
                const SizedBox(width: 8),
              ],
              Text(
                section.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${section.results.length}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ScrollableSlider(
            height: cardHeight + 32,
            itemCount: section.results.length,
            cardWidth: cardWidth,
            itemBuilder: (context, index) {
              final item = section.results[index];
              if (item is Movie) {
                return SizedBox(
                  width: cardWidth,
                  child: _SearchCard(
                    movie: item,
                    listIndex: index,
                    onTap: () => _openDetails(item),
                  ),
                );
              } else {
                final map = item as Map<String, dynamic>;
                return SizedBox(
                  width: cardWidth,
                  child: _StremioSearchCard(
                    item: map,
                    listIndex: index,
                    onTap: () => _openStremioItem(map),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty({String? hint}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 80, color: Colors.white.withValues(alpha: 0.05)),
          const SizedBox(height: 16),
          Text(
            hint ?? (_query.isEmpty ? 'Search for your favorite content' : 'No results found'),
            style: const TextStyle(color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

class _SearchFilmCard extends StatelessWidget {
  const _SearchFilmCard({
    required this.result,
    required this.selected,
    required this.onTap,
    required this.onOpen,
    this.onFocusChange,
    this.onLeftEdge,
    this.gridIndex,
    this.gridColumns,
  });

  final _FlatSearchResult result;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final ValueChanged<bool>? onFocusChange;
  final VoidCallback? onLeftEdge;
  final int? gridIndex;
  final int? gridColumns;

  @override
  Widget build(BuildContext context) {
    final titleSize = shellHubCardTitleFontSize(context);
    final tvActivateOpens =
        ShellScope.inputPolicyOf(context).useFocusableMoodChips;

    return shellFocusableTap(
      context: context,
      onTap: tvActivateOpens ? onOpen : onTap,
      borderRadius: 14,
      onLeftEdge: onLeftEdge,
      gridIndex: gridIndex,
      gridColumns: gridColumns,
      tvTabId: 'search',
      tvRowId: 'results',
      tvZone: ShellTvZone.grid,
      tvItemIndex: gridIndex,
      onFocusChange: onFocusChange,
      child: GestureDetector(
        onDoubleTap: onOpen,
        child: SizedBox.expand(
          child: AnimatedContainer(
            duration: ShellTokens.navSelectionAnimation,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: selected
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: selected ? 0.65 : 0.5),
                  blurRadius: selected ? 20 : 16,
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
                  child: result.posterUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: result.posterUrl,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          placeholder: (_, _) => ColoredBox(color: AppTheme.bgDark),
                          errorWidget: (_, _, _) => Center(
                            child: Text(
                              result.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10, color: Colors.white24),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            result.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, color: Colors.white24),
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
                if (result.rating != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text(
                            result.rating!.toStringAsFixed(1),
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
                        result.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: titleSize,
                          height: 1.2,
                        ),
                      ),
                      if (result.year != null && result.year!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          result.year!,
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

// ═════════════════════════════════════════════════════════════════════════════
// Scrollable slider with left/right arrows
// ═════════════════════════════════════════════════════════════════════════════

class _ScrollableSlider extends StatefulWidget {
  final double height;
  final int itemCount;
  final double cardWidth;
  final IndexedWidgetBuilder itemBuilder;

  const _ScrollableSlider({
    required this.height,
    required this.itemCount,
    required this.cardWidth,
    required this.itemBuilder,
  });

  @override
  State<_ScrollableSlider> createState() => _ScrollableSliderState();
}

class _ScrollableSliderState extends State<_ScrollableSlider> {
  final ScrollController _scrollController = ScrollController();
  bool _showLeft = false;
  bool _showRight = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateArrows);
  }

  void _updateArrows() {
    if (!mounted) return;
    final pos = _scrollController.position;
    final newLeft = pos.pixels > 10;
    final newRight = pos.pixels < pos.maxScrollExtent - 10;
    if (newLeft != _showLeft || newRight != _showRight) {
      setState(() {
        _showLeft = newLeft;
        _showRight = newRight;
      });
    }
  }

  void _scroll(double direction) {
    final target = _scrollController.offset + direction * (widget.cardWidth + 12) * 3;
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.itemCount,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: widget.itemBuilder,
          ),
          // Left arrow
          if (_showLeft)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: _ArrowButton(
                icon: Icons.chevron_left,
                onTap: () => _scroll(-1),
                alignment: Alignment.centerLeft,
              ),
            ),
          // Right arrow
          if (_showRight && widget.itemCount > 2)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: _ArrowButton(
                icon: Icons.chevron_right,
                onTap: () => _scroll(1),
                alignment: Alignment.centerRight,
              ),
            ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Alignment alignment;

  const _ArrowButton({required this.icon, required this.onTap, required this.alignment});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        alignment: alignment,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: alignment == Alignment.centerLeft ? Alignment.centerLeft : Alignment.centerRight,
            end: alignment == Alignment.centerLeft ? Alignment.centerRight : Alignment.centerLeft,
            colors: [
              AppTheme.bgDark.withValues(alpha: 0.9),
              AppTheme.bgDark.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white70, size: 18),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Result Cards
// ═════════════════════════════════════════════════════════════════════════════

class _SearchCard extends StatelessWidget {
  final Movie movie;
  final VoidCallback onTap;
  final int? listIndex;

  const _SearchCard({
    required this.movie,
    required this.onTap,
    this.listIndex,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = movie.posterPath.isNotEmpty ? TmdbApi.getImageUrl(movie.posterPath) : '';

    return shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: 12,
      listIndex: listIndex,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: AppTheme.bgCard),
                errorWidget: (_, _, _) => const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
              )
            else
              Center(child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(movie.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
              )),

            if (movie.voteAverage > 0)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(movie.voteAverage.toStringAsFixed(1), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
                ),
              ),

            Positioned(
              bottom: 0, left: 0, right: 0,
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
                  movie.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ),

            Positioned(
              top: 6, left: 6,
              child: _AddToMyListButton(movie: movie),
            ),
          ],
        ),
      ),
    );
  }
}

class _StremioSearchCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final int? listIndex;

  const _StremioSearchCard({
    required this.item,
    required this.onTap,
    this.listIndex,
  });

  @override
  Widget build(BuildContext context) {
    final poster = item['poster']?.toString() ?? '';
    final name = item['name']?.toString() ?? 'Unknown';
    final rating = item['imdbRating']?.toString() ?? '';
    final type = item['type']?.toString() ?? '';

    return shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: 12,
      listIndex: listIndex,
      child: Container(
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
            if (poster.isNotEmpty)
              CachedNetworkImage(
                imageUrl: poster,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: AppTheme.bgCard),
                errorWidget: (_, _, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.white38)),
                  ),
                ),
              )
            else
              Center(child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.white38)),
              )),

            if (type.isNotEmpty)
              Positioned(
                top: 5, left: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: type == 'series' ? Colors.blue.withValues(alpha: 0.7) : AppTheme.current.primaryColor.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(type.toUpperCase(), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),

            if (rating.isNotEmpty)
              Positioned(
                top: 5, right: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 9, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(rating, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
                    ],
                  ),
                ),
              ),

            Positioned(
              bottom: 0, left: 0, right: 0,
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
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ),

            Positioned(
              bottom: 30, right: 5,
              child: _AddToMyListStremioButton(item: item),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My List button helpers for search cards
// ─────────────────────────────────────────────────────────────────────────────

class _AddToMyListButton extends StatelessWidget {
  final Movie movie;
  const _AddToMyListButton({required this.movie});

  @override
  Widget build(BuildContext context) {
    final uid = MyListService.movieId(movie.id, movie.mediaType);
    return ValueListenableBuilder<int>(
      valueListenable: MyListService.changeNotifier,
      builder: (context, _, _) {
        final inList = MyListService().contains(uid);
        return GestureDetector(
          onTap: () async {
            final added = await MyListService().toggleMovie(
              tmdbId: movie.id,
              imdbId: movie.imdbId,
              title: movie.title,
              posterPath: movie.posterPath,
              mediaType: movie.mediaType,
              voteAverage: movie.voteAverage,
              releaseDate: movie.releaseDate,
            );
            if (context.mounted) {
              ForjaToast.success(added ? 'Added to My List' : 'Removed from My List', duration: const Duration(seconds: 1));
            }
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              inList ? Icons.bookmark : Icons.add,
              size: 16,
              color: inList ? AppTheme.primaryColor : Colors.white70,
            ),
          ),
        );
      },
    );
  }
}

class _AddToMyListStremioButton extends StatelessWidget {
  final Map<String, dynamic> item;
  const _AddToMyListStremioButton({required this.item});

  @override
  Widget build(BuildContext context) {
    final uid = MyListService.stremioItemId(item);
    return ValueListenableBuilder<int>(
      valueListenable: MyListService.changeNotifier,
      builder: (context, _, _) {
        final inList = MyListService().contains(uid);
        return GestureDetector(
          onTap: () async {
            final added = await MyListService().toggleStremioItem(item);
            if (context.mounted) {
              ForjaToast.success(added ? 'Added to My List' : 'Removed from My List', duration: const Duration(seconds: 1));
            }
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              inList ? Icons.bookmark : Icons.add,
              size: 16,
              color: inList ? AppTheme.primaryColor : Colors.white70,
            ),
          ),
        );
      },
    );
  }
}
