import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/my_list/providers/external_lists_providers.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:rust/rust.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

class ListsScreen extends ConsumerStatefulWidget {
  const ListsScreen({super.key, this.embedded = false});

  /// When true, render as a Settings hub body (no Scaffold / AppBar).
  final bool embedded;

  @override
  ConsumerState<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends ConsumerState<ListsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TraktService _trakt = TraktService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _createTraktList() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String privacy = 'private';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF141414),
          title: const Text('Create Trakt List', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'List name',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Description (optional)',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: privacy,
                dropdownColor: const Color(0xFF141414),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                items: const [
                  DropdownMenuItem(value: 'private', child: Text('Private')),
                  DropdownMenuItem(value: 'friends', child: Text('Friends')),
                  DropdownMenuItem(value: 'public', child: Text('Public')),
                ],
                onChanged: (v) => setDialogState(() => privacy = v ?? 'private'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Create', style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      final created = await _trakt.createList(
        name: nameController.text.trim(),
        description: descController.text.trim().isEmpty ? null : descController.text.trim(),
        privacy: privacy,
      );
      if (created != null) {
        ref.invalidate(traktUserListsProvider);
        if (mounted) {
          ForjaToast.success('List created!');
        }
      }
    }
    nameController.dispose();
    descController.dispose();
  }

  void _openTraktListItems(Map<String, dynamic> list) {
    final ids = list['ids'] as Map<String, dynamic>? ?? {};
    final slug = ids['slug']?.toString() ?? ids['trakt']?.toString() ?? '';
    final name = list['name']?.toString() ?? 'List';
    final itemCount = list['item_count'] as int? ?? 0;

    pushShellRoute(
      context,
      AppRouter.slideShellRoute(
        (_) => ColoredBox(
          color: AppTheme.bgDark,
          child: _TraktListItemsScreen(
            listId: slug,
            listName: name,
            itemCount: itemCount,
          ),
        ),
      ),
    );
  }

  void _openMdblistItems(Map<String, dynamic> list, {bool isUserList = false}) {
    final id = list['id'] as int? ?? 0;
    final name = list['name']?.toString() ?? 'List';

    pushShellRoute(
      context,
      AppRouter.slideShellRoute(
        (_) => ColoredBox(
          color: AppTheme.bgDark,
          child: _MdblistItemsScreen(
            listId: id,
            listName: name,
            isUserList: isUserList,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useTvTabs = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    const tabLabels = ['Trakt', 'MDBlist', 'Top Lists'];
    final tvTabId = widget.embedded ? 'settings' : 'mylist';
    final tvZone =
        widget.embedded ? ShellTvZone.settings : ShellTvZone.chipStrip;

    final tabs = useTvTabs
        ? SizedBox(
            height: 46,
            child: Row(
              children: [
                for (var i = 0; i < tabLabels.length; i++)
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        final selected = _tabController.index == i;
                        return shellFocusableTap(
                          context: context,
                          onTap: () => _tabController.animateTo(i),
                          borderRadius: 0,
                          listIndex: i,
                          tvTabId: tvTabId,
                          tvZone: tvZone,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                tabLabels[i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: selected
                                      ? ForjaShellColors.textPrimary
                                      : ForjaShellColors.textSecondary,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                height: 2,
                                color: selected
                                    ? ForjaShellColors.brandGreen
                                    : Colors.transparent,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          )
        : TabBar(
            controller: _tabController,
            indicatorColor: ForjaShellColors.brandGreen,
            labelColor: ForjaShellColors.textPrimary,
            unselectedLabelColor: ForjaShellColors.textSecondary,
            tabs: const [
              Tab(text: 'Trakt'),
              Tab(text: 'MDBlist'),
              Tab(text: 'Top Lists'),
            ],
          );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tabs,
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTraktTab(),
              _buildMdblistTab(),
              _buildTopListsTab(),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return ColoredBox(color: AppTheme.bgDark, child: body);
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: const Text(
          'Lists',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: body,
    );
  }

  static const _loadingSpinner =
      Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));

  static const _loadErrorText = Center(
    child: Text(
      'Failed to load lists',
      style: TextStyle(color: Colors.white54, fontSize: 16),
      textAlign: TextAlign.center,
    ),
  );

  Widget _buildTraktTab() {
    final gate = ref.watch(externalListsGateProvider);
    return gate.when(
      data: (gate) {
        if (!gate.traktLoggedIn) {
          return const Center(
            child: Text(
              'Login to Trakt in Settings → Accounts',
              style: TextStyle(color: Colors.white54, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        }
        final lists = ref.watch(traktUserListsProvider);
        return lists.when(
          data: _traktListsBody,
          loading: () => _loadingSpinner,
          error: (_, _) => _loadErrorText,
        );
      },
      loading: () => _loadingSpinner,
      error: (_, _) => _loadErrorText,
    );
  }

  Widget _traktListsBody(List<Map<String, dynamic>> traktLists) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ForjaButton.primary(
              label: 'Create New List',
              icon: Icons.add_rounded,
              onPressed: _createTraktList,
            ),
          ),
        ),
        Expanded(
          child: traktLists.isEmpty
            ? const Center(child: Text('No lists yet', style: TextStyle(color: Colors.white38)))
            : ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: traktLists.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: ForjaShellColors.borderSubtle.withValues(alpha: 0.6),
                ),
                itemBuilder: (context, index) {
                  final list = traktLists[index];
                  final name = list['name']?.toString() ?? 'Unnamed';
                  final desc = list['description']?.toString() ?? '';
                  final itemCount = list['item_count'] as int? ?? 0;
                  final privacy = list['privacy']?.toString() ?? 'private';

                  return _listCard(
                    name: name,
                    subtitle: '$itemCount items • $privacy',
                    description: desc,
                    icon: Icons.list_rounded,
                    color: const Color(0xFFED1C24),
                    onTap: () => _openTraktListItems(list),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildMdblistTab() {
    final gate = ref.watch(externalListsGateProvider);
    return gate.when(
      data: (gate) {
        if (!gate.mdblistConfigured) {
          return const Center(
            child: Text(
              'Configure MDBlist in Settings → Accounts',
              style: TextStyle(color: Colors.white54, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        }
        final lists = ref.watch(mdblistUserListsProvider);
        return lists.when(
          data: _mdblistListsBody,
          loading: () => _loadingSpinner,
          error: (_, _) => _loadErrorText,
        );
      },
      loading: () => _loadingSpinner,
      error: (_, _) => _loadErrorText,
    );
  }

  Widget _mdblistListsBody(List<Map<String, dynamic>> mdblistLists) {
    return mdblistLists.isEmpty
      ? const Center(child: Text('No lists yet', style: TextStyle(color: Colors.white38)))
      : ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: mdblistLists.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            color: ForjaShellColors.borderSubtle.withValues(alpha: 0.6),
          ),
          itemBuilder: (context, index) {
            final list = mdblistLists[index];
            final name = list['name']?.toString() ?? 'Unnamed';
            final itemCount = list['items'] as int? ?? 0;

            return _listCard(
              name: name,
              subtitle: '$itemCount items',
              icon: Icons.list_alt_rounded,
              color: const Color(0xFF5799EF),
              onTap: () => _openMdblistItems(list, isUserList: true),
            );
          },
        );
  }

  Widget _buildTopListsTab() {
    final gate = ref.watch(externalListsGateProvider);
    return gate.when(
      data: (gate) {
        if (!gate.mdblistConfigured) {
          return const Center(
            child: Text(
              'Configure MDBlist in Settings → Accounts',
              style: TextStyle(color: Colors.white54, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        }
        final lists = ref.watch(mdblistTopListsProvider);
        return lists.when(
          data: _topListsBody,
          loading: () => _loadingSpinner,
          error: (_, _) => _loadErrorText,
        );
      },
      loading: () => _loadingSpinner,
      error: (_, _) => _loadErrorText,
    );
  }

  Widget _topListsBody(List<Map<String, dynamic>> topLists) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: topLists.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: ForjaShellColors.borderSubtle.withValues(alpha: 0.6),
      ),
      itemBuilder: (context, index) {
        final list = topLists[index];
        final name = list['name']?.toString() ?? 'Unnamed';
        final itemCount = list['items'] as int? ?? 0;
        final likes = list['likes'] as int? ?? 0;

        return _listCard(
          name: name,
          subtitle: '$itemCount items • $likes likes',
          icon: Icons.trending_up_rounded,
          color: const Color(0xFFFFD700),
          onTap: () => _openMdblistItems(list),
        );
      },
    );
  }

  Widget _listCard({
    required String name,
    required String subtitle,
    String description = '',
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final tvTabId = widget.embedded ? 'settings' : 'mylist';
    return shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: 0,
      // Standalone My List: Left from a card returns to the nav rail.
      // Embedded in Settings detail: stay in the pane (Back exits).
      navLeftAlways: !widget.embedded,
      showFocusBorder: widget.embedded,
      showFocusFill: widget.embedded,
      tvTabId: tvTabId,
      tvZone: widget.embedded ? ShellTvZone.settings : ShellTvZone.row,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: ForjaShellColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ForjaShellColors.textSecondary.withValues(
                          alpha: 0.7,
                        ),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: ForjaShellColors.iconMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TRAKT LIST ITEMS SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class _TraktListItemsScreen extends StatefulWidget {
  final String listId;
  final String listName;
  final int itemCount;

  const _TraktListItemsScreen({
    required this.listId,
    required this.listName,
    required this.itemCount,
  });

  @override
  State<_TraktListItemsScreen> createState() => _TraktListItemsScreenState();
}

class _TraktListItemsScreenState extends State<_TraktListItemsScreen> {
  final TraktService _trakt = TraktService();
  final TmdbApi _api = TmdbApi();
  List<Movie> _movies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final items = await _trakt.getListItems(widget.listId);
      final entries = items.map((item) {
        final media = item['movie'] ?? item['show'];
        if (media == null) return null;
        final type = item.containsKey('show') ? 'tv' : 'movie';
        final ids = media['ids'] as Map<String, dynamic>? ?? {};
        final tmdbId = ids['tmdb'] as int?;
        if (tmdbId == null) return null;
        return (tmdbId: tmdbId, type: type);
      }).whereType<({int tmdbId, String type})>().toList();

      final movies = <Movie>[];
      for (var i = 0; i < entries.length; i += 5) {
        final batch = entries.skip(i).take(5);
        final results = await Future.wait(
          batch.map((e) async {
            try {
              return e.type == 'tv'
                  ? await _api.getTvDetails(e.tmdbId)
                  : await _api.getMovieDetails(e.tmdbId);
            } catch (_) { return null; }
          }),
        );
        movies.addAll(results.whereType<Movie>());
      }
      if (mounted) setState(() { _movies = movies; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeItem(Movie movie) async {
    final type = movie.mediaType == 'tv' ? 'shows' : 'movies';
    final entry = <String, dynamic>{
      'ids': {'tmdb': movie.id},
    };
    final success = await _trakt.removeFromList(
      listId: widget.listId,
      movies: type == 'movies' ? [entry] : [],
      shows: type == 'shows' ? [entry] : [],
    );
    if (success && mounted) {
      setState(() => _movies.removeWhere((m) => m.id == movie.id));
      ForjaToast.success('Removed "${movie.title}"');
    } else if (mounted) {
      ForjaToast.error('Failed to remove item');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ListItemsPage(
      title: widget.listName,
      loading: _loading,
      movies: _movies,
      onTap: (movie) => AppRouter.openDetails(context, movie: movie),
      onRemove: _removeItem,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  MDBLIST ITEMS SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class _MdblistItemsScreen extends StatefulWidget {
  final int listId;
  final String listName;
  final bool isUserList;

  const _MdblistItemsScreen({
    required this.listId,
    required this.listName,
    this.isUserList = false,
  });

  @override
  State<_MdblistItemsScreen> createState() => _MdblistItemsScreenState();
}

class _MdblistItemsScreenState extends State<_MdblistItemsScreen> {
  final MdblistService _mdblist = MdblistService();
  final TmdbApi _api = TmdbApi();
  List<Movie> _movies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final items = await _mdblist.getListItems(widget.listId);
      final entries = items.map((item) {
        final tmdbId = item['tmdb_id'] as int? ?? item['id'] as int?;
        final mediaType = item['mediatype']?.toString() ?? 'movie';
        if (tmdbId == null) return null;
        return (tmdbId: tmdbId, type: mediaType);
      }).whereType<({int tmdbId, String type})>().toList();

      final movies = <Movie>[];
      for (var i = 0; i < entries.length; i += 5) {
        final batch = entries.skip(i).take(5);
        final results = await Future.wait(
          batch.map((e) async {
            try {
              return e.type == 'show'
                  ? await _api.getTvDetails(e.tmdbId)
                  : await _api.getMovieDetails(e.tmdbId);
            } catch (_) { return null; }
          }),
        );
        movies.addAll(results.whereType<Movie>());
      }
      if (mounted) setState(() { _movies = movies; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeItem(Movie movie) async {
    final success = await _mdblist.removeFromList(
      listId: widget.listId,
      tmdbId: movie.id,
      mediaType: movie.mediaType,
    );
    if (success && mounted) {
      setState(() => _movies.removeWhere((m) => m.id == movie.id));
      ForjaToast.success('Removed "${movie.title}"');
    } else if (mounted) {
      ForjaToast.error('Failed to remove item');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ListItemsPage(
      title: widget.listName,
      loading: _loading,
      movies: _movies,
      onTap: (movie) => AppRouter.openDetails(context, movie: movie),
      onRemove: widget.isUserList ? _removeItem : null,
    );
  }
}

class _ListItemsPage extends StatelessWidget {
  const _ListItemsPage({
    required this.title,
    required this.loading,
    required this.movies,
    required this.onTap,
    this.onRemove,
  });

  final String title;
  final bool loading;
  final List<Movie> movies;
  final void Function(Movie movie) onTap;
  final Future<void> Function(Movie movie)? onRemove;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = shellGridCrossAxisCount(context);
    return Material(
      color: AppTheme.bgDark,
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        appBar: AppBar(
          backgroundColor: AppTheme.bgDark,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: ColoredBox(
          color: AppTheme.bgDark,
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                )
              : movies.isEmpty
                  ? const Center(
                      child: Text(
                        'No items',
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : TvFocusGraph(
                      tabId: 'settings',
                      child: TvGrid(
                        rowId: 'list-items',
                        sortOrder: 0,
                        columns: crossAxisCount,
                        itemCount: movies.length,
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            ShellTokens.bodyHorizontalPadding,
                            8,
                            ShellTokens.bodyHorizontalPadding,
                            ShellTokens.bodyHorizontalPadding,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 2 / 3,
                          ),
                          itemCount: movies.length,
                          itemBuilder: (context, index) {
                            final movie = movies[index];
                            return _ListPosterCard(
                              movie: movie,
                              gridIndex: index,
                              onTap: () => onTap(movie),
                              onRemove: onRemove == null
                                  ? null
                                  : () => onRemove!(movie),
                            );
                          },
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}

class _ListPosterCard extends StatelessWidget {
  const _ListPosterCard({
    required this.movie,
    required this.onTap,
    required this.gridIndex,
    this.onRemove,
  });

  final Movie movie;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final int gridIndex;

  @override
  Widget build(BuildContext context) {
    final posterUrl = movie.posterPath.isNotEmpty
        ? TmdbApi.getImageUrl(movie.posterPath)
        : '';
    final policy = ShellScope.inputPolicyOf(context);
    final meta = TvGridScope.maybeOf(context)?.metaFor(gridIndex);

    return shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: 12,
      showFocusBorder: true,
      gridIndex: meta?.gridIndex ?? gridIndex,
      gridColumns: meta?.gridColumns,
      tvTabId: meta?.tvTabId ?? 'settings',
      tvRowId: meta?.tvRowId ?? 'list-items',
      tvZone: meta?.tvZone ?? ShellTvZone.grid,
      tvItemIndex: meta?.tvItemIndex ?? gridIndex,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: AppTheme.bgCard,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (posterUrl.isNotEmpty)
                Image.network(
                  posterUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _titleFallback(movie.title),
                )
              else
                _titleFallback(movie.title),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                    stops: [0.55, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: onRemove != null ? 28 : 8,
                bottom: 8,
                child: Text(
                  movie.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              if (onRemove != null)
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: ExcludeFocus(
                    excluding: !policy.scaleOnHover,
                    child: shellFocusableTap(
                      context: context,
                      onTap: onRemove,
                      borderRadius: 20,
                      scaleOnFocus: ShellTokens.focusActiveScale,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xCCF44336),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleFallback(String title) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: Colors.white38),
        ),
      ),
    );
  }
}
