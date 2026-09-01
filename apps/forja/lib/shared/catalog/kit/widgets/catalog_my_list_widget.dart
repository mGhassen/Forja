import 'package:flutter/material.dart';
import 'package:forja/features/my_list/my_list_catalog_open.dart';
import 'package:forja/features/my_list/providers/external_lists_providers.dart';
import 'package:forja/features/my_list/providers/my_list_catalog_providers.dart';
import 'package:forja/features/my_list/providers/my_list_providers.dart';
import 'package:forja/shared/catalog/kit/cards/hub_poster_card.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_status_tabs.dart';
import 'package:forja/shared/catalog/kit/rows/hub_catalog_section.dart';
import 'package:forja/shared/catalog/kit/meta/catalog_meta_movie.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rust/rust.dart';

/// Layout widget `host.my_list` — local + Simkl lists as hub-style rails.
class CatalogMyListWidget extends ConsumerStatefulWidget {
  const CatalogMyListWidget({
    super.key,
    required this.tabId,
    required this.refreshEpoch,
    this.tvRowOrder = 0,
  });

  final String tabId;
  final int refreshEpoch;
  final int tvRowOrder;

  @override
  ConsumerState<CatalogMyListWidget> createState() =>
      _CatalogMyListWidgetState();
}

class _CatalogMyListWidgetState extends ConsumerState<CatalogMyListWidget> {
  final _scroll = ScrollController();
  final FocusNode _filmsFocus = FocusNode(debugLabel: 'mylist-films');

  String _status = 'plantowatch';
  String? _kind;

  static const _railSpecs = [
    (id: 'films', title: 'Films', kind: 'movie'),
    (id: 'tv', title: 'TV Shows', kind: 'tv'),
    (id: 'anime', title: 'Anime', kind: 'anime'),
  ];

  @override
  void initState() {
    super.initState();
    TvHeroActions.bind(
      widget.tabId,
      enterFromNavFocus: _focusEntry,
      restoreFocus: () {
        if (_focusRow(kCatalogMyListKindRowId, 0)) return true;
        if (_focusRow(kCatalogMyListStatusRowId, 0)) return true;
        return _focusFirstRail();
      },
    );
  }

  @override
  void didUpdateWidget(CatalogMyListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshEpoch != oldWidget.refreshEpoch) {
      ref.invalidate(myListRevisionProvider);
      ref.invalidate(simklWatchlistProvider);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _filmsFocus.dispose();
    ShellTvFocusCoordinator.clearTab(widget.tabId);
    super.dispose();
  }

  bool _focusRow(String rowId, int index) =>
      ShellTvFocusCoordinator.focusRowItem(widget.tabId, rowId, index);

  bool _focusRowLast(String rowId) {
    final handle = ShellTvFocusCoordinator.rowHandle(widget.tabId, rowId);
    if (handle == null || handle.itemCount <= 0) return false;
    final idx = handle.lastFocusedIndex.clamp(0, handle.itemCount - 1);
    return _focusRow(rowId, idx);
  }

  bool _focusFirstRail() {
    for (final spec in _visibleRailSpecs(const [])) {
      if (_focusRow(spec.id, 0)) return true;
    }
    return false;
  }

  void _focusEntry() {
    bool tryFocus() {
      if (_filmsFocus.context != null && _filmsFocus.canRequestFocus) {
        _filmsFocus.requestFocus();
        return true;
      }
      return _focusRow(kCatalogMyListKindRowId, 0);
    }

    if (tryFocus()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ShellTvFocus.currentNavTabId != widget.tabId) return;
      tryFocus();
    });
  }

  void _selectStatus(String id) {
    if (_status == id) return;
    setState(() => _status = id);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _toggleKind(String kind) {
    setState(() => _kind = _kind == kind ? null : kind);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  List<({String id, String title, String kind})> _visibleRailSpecs(
    List<({String id, String title, String kind})> all,
  ) {
    if (_kind == null) return all;
    return all.where((s) => s.kind == _kind).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(myListCatalogProvider(_status));
    ref.listen(myListCatalogProvider(_status), (prev, next) {
      if (!next.hasValue) return;
      final gate = ref.read(externalListsGateProvider).valueOrNull;
      if (gate?.simklLoggedIn != true) return;
      final cards = [
        for (final entry in next.requireValue.entriesForKind(null))
          entry.legacyRow,
      ];
      ref.read(myListHiddenKeysProvider.notifier).retainOnlyPresentIn(cards);
    });

    return TvFocusGraph(
      tabId: widget.tabId,
      child: ColoredBox(
        color: AppTheme.bgDark,
        child: pageAsync.when(
          loading: () => _chrome(context, loading: true, page: null),
          error: (e, _) => _chrome(
            context,
            loading: false,
            page: null,
            error: e.toString(),
          ),
          data: (page) => _chrome(context, loading: page.loadingSimkl, page: page),
        ),
      ),
    );
  }

  Widget _chrome(
    BuildContext context, {
    required bool loading,
    required MyListCatalogPage? page,
    String? error,
  }) {
    final filteredCount = page == null
        ? null
        : page.entriesForKind(_kind).length;
    final rails = _visibleRailSpecs(_railSpecs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KindMenu(
          tabId: widget.tabId,
          selected: _kind,
          count: loading ? null : filteredCount,
          onSelect: _toggleKind,
          filmsFocus: _filmsFocus,
          onDown: () =>
              _focusRowLast(kCatalogMyListStatusRowId) ||
              _focusRow(kCatalogMyListStatusRowId, 0),
        ),
        CatalogStatusTabs(
          tabId: widget.tabId,
          selected: _status,
          onSelect: _selectStatus,
          onUp: () =>
              _focusRowLast(kCatalogMyListKindRowId) ||
              _focusRow(kCatalogMyListKindRowId, 0),
          onDown: () => _focusFirstRail(),
        ),
        Expanded(
          child: error != null
              ? Center(
                  child: Text(
                    error,
                    style: TextStyle(color: ForjaShellColors.textSecondary),
                  ),
                )
              : loading && page == null
              ? _loadingRails(context)
              : page == null
              ? const SizedBox.shrink()
              : _body(context, page, rails, loadingSimkl: loading),
        ),
      ],
    );
  }

  Widget _body(
    BuildContext context,
    MyListCatalogPage page,
    List<({String id, String title, String kind})> rails, {
    required bool loadingSimkl,
  }) {
    if (loadingSimkl && page.totalCount == 0) {
      return _loadingRails(context);
    }
    final visibleRails = [
      for (final spec in rails)
        if (page.entriesForKind(spec.kind).isNotEmpty) spec,
    ];
    if (visibleRails.isEmpty) {
      return _emptyState(kind: _kind);
    }
    return CustomScrollView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        for (var i = 0; i < visibleRails.length; i++)
          hubRowSliver(
            context,
            _rail(
              context,
              spec: visibleRails[i],
              entries: page.entriesForKind(visibleRails[i].kind),
              tvRowOrder: widget.tvRowOrder + 2 + i,
              tvFocusUp: i == 0
                  ? () =>
                      _focusRowLast(kCatalogMyListStatusRowId) ||
                      _focusRow(kCatalogMyListStatusRowId, 0)
                  : null,
            ),
            isFirstAfterHero: i == 0,
          ),
        SliverToBoxAdapter(
          child: SizedBox(height: shellTvCatalogScrollBottomGap(context)),
        ),
      ],
    );
  }

  Widget _rail(
    BuildContext context, {
    required ({String id, String title, String kind}) spec,
    required List<MyListCatalogEntry> entries,
    required int tvRowOrder,
    VoidCallback? tvFocusUp,
  }) {
    final metas = [for (final e in entries) e.meta];
    return HubCatalogSection<CatalogMetaItem>(
      title: spec.title,
      items: metas,
      itemKey: (item) => item.id,
      tvTabId: widget.tabId,
      tvRowId: spec.id,
      tvRowOrder: tvRowOrder,
      tvFocusUp: tvFocusUp,
      cardBuilder: (context, item, index) {
        final entry = entries[index];
        return _card(context, entry, index, rowId: spec.id);
      },
    );
  }

  HubPosterCard _card(
    BuildContext context,
    MyListCatalogEntry entry,
    int index, {
    required String rowId,
  }) {
    final meta = entry.meta;
    return HubPosterCard(
      imageUrl: myListPosterUrl(meta),
      title: meta.name,
      subtitle: hubPosterCardSubtitle(meta),
      rating: (meta.rating ?? 0) > 0 ? meta.rating : null,
      badge: meta.type == 'anime' ? null : meta.badge,
      listIndex: index,
      listPin: myListEntryPin(context, entry, _status),
      tvTabId: widget.tabId,
      tvRowId: rowId,
      onTap: () => openMyListCatalogEntry(context, entry),
    );
  }

  Widget _loadingRails(BuildContext context) {
    return homeLoadingShimmer(
      ListView(
        padding: EdgeInsets.only(top: shellHomeSectionTitleTop(context)),
        children: [
          for (var i = 0; i < 2; i++)
            SizedBox(
              height: HubCatalogSection.sectionHeight(context),
              child: Row(
                children: List.generate(
                  4,
                  (_) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(
                          shellCardBorderRadius(context),
                        ),
                      ),
                      child: SizedBox(
                        width: HubPosterCard.cardWidth(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState({String? kind}) {
    final filtered = kind != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 40,
              color: ForjaShellColors.textSecondary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 14),
            Text(
              filtered
                  ? 'Nothing in ${switch (kind) {
                      'tv' => 'TV Shows',
                      'anime' => 'Anime',
                      _ => 'Films',
                    }}'
                  : 'Nothing in this list',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              filtered
                  ? 'Tap Films, TV Shows, or Anime again to show everything'
                  : 'Tap + on a title to set Plan to Watch / Watching / On Hold / Completed / Dropped',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ForjaShellColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String myListPosterUrl(CatalogMetaItem meta) {
  final poster = meta.poster;
  if (poster.isEmpty) return '';
  if (poster.startsWith('http')) return poster;
  if (poster.startsWith('/')) return TmdbApi.getImageUrl(poster);
  return poster;
}

class _KindMenu extends StatelessWidget {
  const _KindMenu({
    required this.tabId,
    required this.selected,
    required this.onSelect,
    required this.onDown,
    required this.filmsFocus,
    this.count,
  });

  final String tabId;
  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onDown;
  final FocusNode filmsFocus;
  final int? count;

  static const _items = [
    (id: 'movie', label: 'Films'),
    (id: 'tv', label: 'TV Shows'),
    (id: 'anime', label: 'Anime'),
  ];

  @override
  Widget build(BuildContext context) {
    final useTv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final tabGap = useTv
        ? 28.0
        : MediaQuery.sizeOf(context).width < 560
        ? 20.0
        : 36.0;
    return TvCatalogRow(
      tabId: tabId,
      rowId: kCatalogMyListKindRowId,
      sortOrder: 0,
      itemCount: _items.length,
      onFocusUp: () {},
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ShellTokens.compactChromeLeadingInset(context),
          ShellTokens.tabHeaderTopPadding,
          ShellTokens.bodyHorizontalPadding,
          4,
        ),
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) SizedBox(width: tabGap),
                _KindTab(
                  label: _items[i].label,
                  isActive: selected == _items[i].id,
                  onTap: () => onSelect(_items[i].id),
                  tvFocus: useTv,
                  tabId: tabId,
                  listIndex: i,
                  onDownEdge: onDown,
                  focusNode: i == 0 ? filmsFocus : null,
                ),
              ],
              const Spacer(),
              if (count != null && count! > 0)
                Text(
                  '$count',
                  style: const TextStyle(color: Colors.white38, fontSize: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindTab extends StatefulWidget {
  const _KindTab({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.tvFocus,
    required this.tabId,
    required this.listIndex,
    required this.onDownEdge,
    this.focusNode,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool tvFocus;
  final String tabId;
  final int listIndex;
  final VoidCallback onDownEdge;
  final FocusNode? focusNode;

  @override
  State<_KindTab> createState() => _KindTabState();
}

class _KindTabState extends State<_KindTab> {
  static const _animDuration = Duration(milliseconds: 280);
  static const _hoverT = 0.62;
  static const _selectedT = 1.0;

  bool _hovered = false;
  bool _focused = false;

  double get _visualTarget {
    if (widget.isActive) return _selectedT;
    final policy = ShellScope.inputPolicyOf(context);
    if (_hovered || policy.focusStyled(context, focused: _focused)) {
      return _hoverT;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final child = TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _visualTarget),
      duration: _animDuration,
      curve: Curves.easeInOutCubic,
      builder: (context, t, _) {
        final idle = ForjaShellColors.cinematic.textSecondary;
        final hoverWhite = Colors.white.withValues(alpha: 0.92);
        final color = t <= 0
            ? idle
            : t < _hoverT
            ? Color.lerp(idle, hoverWhite, t / _hoverT)!
            : Color.lerp(
                hoverWhite,
                Colors.white,
                (t - _hoverT) / (_selectedT - _hoverT),
              )!;
        final tabHeight = shellScaled(context, 34).clamp(28.0, 34.0);
        final tabFont = shellScaled(context, 17).clamp(14.0, 17.0);
        final hoverW = shellScaled(context, 28).clamp(14.0, 28.0);
        final underline = t <= 0
            ? 0.0
            : t < _hoverT
            ? hoverW * (t / _hoverT)
            : hoverW +
                  shellScaled(context, 4).clamp(2.0, 4.0) *
                      ((t - _hoverT) / (_selectedT - _hoverT));
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: tabHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: tabFont,
                    fontWeight: FontWeight.lerp(
                      FontWeight.w500,
                      FontWeight.w700,
                      t,
                    ),
                    color: color,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: shellScaled(
                context,
                ShellTokens.shellCategoryUnderlineGap,
              ).clamp(2.0, ShellTokens.shellCategoryUnderlineGap),
            ),
            Container(
              height: shellScaled(
                context,
                ShellTokens.shellNavUnderlineHeight,
              ).clamp(1.0, ShellTokens.shellNavUnderlineHeight),
              width: underline,
              decoration: BoxDecoration(
                color: underline > 0 ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        );
      },
    );

    if (widget.tvFocus) {
      return shellFocusableTap(
        context: context,
        onTap: widget.onTap,
        borderRadius: 4,
        scaleOnFocus: ShellTokens.focusActiveScale,
        listIndex: widget.listIndex,
        tvTabId: widget.tabId,
        tvRowId: kCatalogMyListKindRowId,
        tvZone: ShellTvZone.row,
        tvItemIndex: widget.listIndex,
        onDownEdge: widget.onDownEdge,
        focusNode: widget.focusNode,
        onFocusChange: (f) => setState(() => _focused = f),
        onHoverChange: (h) => setState(() => _hovered = h),
        child: child,
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }
}
