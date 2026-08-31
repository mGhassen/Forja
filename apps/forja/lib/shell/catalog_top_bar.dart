import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_vertical_filters.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_vertical_filters_rail.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_nav_rail.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sentinel for the "All" entry in the categories popup menu.
const catalogAllCategoriesSentinel = '__all__';

/// Films / Series (or TV Shows) / Categories + Search overlaid on a hub hero.
class CatalogTopBar extends StatefulWidget {
  const CatalogTopBar({
    super.key,
    required this.tabId,
    required this.seriesLabel,
    required this.mediaCategory,
    required this.selectedCategoryId,
    required this.categories,
    required this.scrollOffset,
    required this.heroHeight,
    required this.onSearch,
  });

  final String tabId;
  final String seriesLabel;
  final ValueNotifier<ShellHomeCategory?> mediaCategory;
  final ValueNotifier<String?> selectedCategoryId;
  final List<({String id, String label})> categories;
  final ValueNotifier<double> scrollOffset;
  final ValueNotifier<double> heroHeight;

  /// Null when the pack does not declare `search` — Search tab is omitted.
  final VoidCallback? onSearch;

  static const hideSlideDistance = 56.0;

  @override
  State<CatalogTopBar> createState() => _CatalogTopBarState();
}

class _CatalogTopBarState extends State<CatalogTopBar> {
  final GlobalKey _categoriesKey = GlobalKey();
  bool _categoriesOpen = false;
  late final FocusNode _menuFocus = FocusNode(
    debugLabel: '${widget.tabId}-menu',
  );
  late final FocusNode _searchFocus = FocusNode(
    debugLabel: '${widget.tabId}-search',
  );
  late final FocusNode _providerLogoFocus = FocusNode(
    debugLabel: '${widget.tabId}-provider-logo',
  );
  late final FocusNode _categoriesTabFocus = FocusNode(
    debugLabel: '${widget.tabId}-categories-tab',
  );
  late final FocusNode _categoriesMenuFocus = FocusNode(
    debugLabel: '${widget.tabId}-categories-menu',
  );

  @override
  void initState() {
    super.initState();
    // First menu tab is Search — UP from hero gallery lands here.
    if (widget.tabId == 'home') {
      ShellTvFocus.homeMenu = _searchFocus;
      ShellTvFocus.homeSearch = _searchFocus;
    } else {
      ShellTvFocus.hubHeroSearch = _searchFocus;
    }
  }

  @override
  void dispose() {
    if (widget.tabId == 'home') {
      if (ShellTvFocus.homeMenu == _searchFocus) ShellTvFocus.homeMenu = null;
      if (ShellTvFocus.homeSearch == _searchFocus) {
        ShellTvFocus.homeSearch = null;
      }
    } else if (ShellTvFocus.hubHeroSearch == _searchFocus) {
      ShellTvFocus.hubHeroSearch = null;
    }
    _menuFocus.dispose();
    _searchFocus.dispose();
    _providerLogoFocus.dispose();
    _categoriesTabFocus.dispose();
    _categoriesMenuFocus.dispose();
    super.dispose();
  }

  String? _categoryLabel(String? id) {
    if (id == null) return null;
    for (final c in widget.categories) {
      if (c.id == id) return c.label;
    }
    return null;
  }

  void _toggleMediaFilter(ShellHomeCategory target) {
    final current = widget.mediaCategory.value;
    widget.mediaCategory.value = current == target ? null : target;
  }

  Future<void> _openCategoriesMenu() async {
    final box = _categoriesKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final offset = box.localToGlobal(Offset.zero);
    final selectedId = widget.selectedCategoryId.value;

    setState(() => _categoriesOpen = true);

    final picked = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss categories',
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, _) {
        final shellScope = ShellScope.of(context);
        final tvFocus = shellScope.inputPolicy.useFocusableMoodChips;
        void dismissMenu() => Navigator.of(dialogContext).pop();

        Widget menu = Stack(
          children: [
            Positioned(
              left: offset.dx,
              top: offset.dy + box.size.height + 4,
              child: Material(
                color: ForjaShellColors.cinematic.menuSurface,
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ForjaShellColors.cinematic.borderSubtle,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: IntrinsicWidth(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: ShellTokens.homeCategoriesMenuMaxHeight,
                        ),
                        child: SingleChildScrollView(
                          padding: EdgeInsets.zero,
                          physics: const ClampingScrollPhysics(),
                          child: FocusTraversalGroup(
                            policy: ReadingOrderTraversalPolicy(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _FlatMenuRow(
                                  label: 'All',
                                  selected: selectedId == null,
                                  listIndex: 0,
                                  tvFocus: tvFocus,
                                  tabId: widget.tabId,
                                  focusNode: tvFocus
                                      ? _categoriesMenuFocus
                                      : null,
                                  onUpEdge: tvFocus ? dismissMenu : null,
                                  onLeftEdge: tvFocus ? dismissMenu : null,
                                  onTap: () => Navigator.of(
                                    dialogContext,
                                  ).pop(catalogAllCategoriesSentinel),
                                ),
                                for (var i = 0; i < widget.categories.length; i++)
                                  _FlatMenuRow(
                                    label: widget.categories[i].label,
                                    selected:
                                        widget.categories[i].id == selectedId,
                                    listIndex: i + 1,
                                    tvFocus: tvFocus,
                                    tabId: widget.tabId,
                                    onLeftEdge: tvFocus ? dismissMenu : null,
                                    onTap: () => Navigator.of(
                                      dialogContext,
                                    ).pop(widget.categories[i].id),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );

        if (tvFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_categoriesMenuFocus.canRequestFocus) {
              _categoriesMenuFocus.requestFocus();
            }
          });
          menu = PopScope(
            canPop: true,
            child: Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.escape):
                    _DismissCategoriesIntent(),
                SingleActivator(LogicalKeyboardKey.goBack):
                    _DismissCategoriesIntent(),
              },
              child: Actions(
                actions: {
                  _DismissCategoriesIntent:
                      CallbackAction<_DismissCategoriesIntent>(
                        onInvoke: (_) {
                          dismissMenu();
                          return null;
                        },
                      ),
                },
                child: menu,
              ),
            ),
          );
        }

        return ShellScope(
          profile: shellScope.profile,
          config: shellScope.config,
          child: menu,
        );
      },
    );

    if (!mounted) return;
    setState(() => _categoriesOpen = false);
    // Always return focus to the Categories tab. Otherwise after the dialog
    // pops, focus lands on a remounted catalog card and ensureVisible scrolls
    // the Home page to the middle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _categoriesTabFocus.canRequestFocus) {
        _categoriesTabFocus.requestFocus();
      }
    });
    if (picked == null) return;

    final next = picked == catalogAllCategoriesSentinel ? null : picked;
    if (next != widget.selectedCategoryId.value) {
      widget.selectedCategoryId.value = next;
    }
  }

  Widget _buildMenuScroll({
    required Widget tabs,
    required bool compactNav,
    required bool tvFocus,
    required double tabGap,
  }) {
    if (!compactNav || tvFocus) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: tabs,
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 34,
            child: Center(
              child: ShellNavMenuButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
          SizedBox(width: tabGap),
          tabs,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compactNav =
        MediaQuery.sizeOf(context).width < ShellTokens.shellNavCompactMaxWidth;
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;

    return ValueListenableBuilder<String?>(
      valueListenable: CatalogVerticalFiltersRegistry.selectedIdFor(
        widget.tabId,
      ),
      builder: (context, selectedFilterId, _) {
        final spec = CatalogVerticalFiltersRegistry.specFor(widget.tabId);
        final hasFilterLogo = spec?.showSelectedInTopBar == true &&
            selectedFilterId != null;
        final usesTv = ShellScope.metricsOf(context).usesTvDensity;
        final logoWidth = usesTv
            ? ShellTokens.shellProviderTopBarIconWidthTv
            : ShellTokens.shellProviderTopBarIconWidth;
        final logoHeight = usesTv
            ? ShellTokens.shellProviderTopBarIconHeightTv
            : ShellTokens.shellProviderTopBarIconHeight;
        final barContentHeight = ShellTokens.homeTopBarHeight;

        return ValueListenableBuilder<double>(
          valueListenable: widget.scrollOffset,
          builder: (context, scrollOffset, child) {
            return ValueListenableBuilder<double>(
              valueListenable: widget.heroHeight,
              builder: (context, heroHeight, menu) {
                final topInset = MediaQuery.paddingOf(context).top;
                final barHeight = topInset + barContentHeight;
                final hideStart = math.max(0.0, heroHeight - barHeight);
                final hideProgress = heroHeight <= 0
                    ? 0.0
                    : ((scrollOffset - hideStart) /
                              CatalogTopBar.hideSlideDistance)
                          .clamp(0.0, 1.0);

                return Transform.translate(
                  offset: Offset(0, -barHeight * hideProgress),
                  child: child,
                );
              },
            );
          },
          child: SafeArea(
            bottom: false,
            left: false,
            right: false,
            child: SizedBox(
              height: barContentHeight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compactNav
                      ? ShellTokens.compactMenuLeadingInset(context)
                      : ShellTokens.bodyHorizontalPadding +
                            ShellTokens.homeTopBarMenuLeadingInset,
                  ShellTokens.shellHeaderTopPadding,
                  ShellTokens.bodyHorizontalPadding,
                  0,
                ),
                child: ValueListenableBuilder<ShellHomeCategory?>(
                  valueListenable: widget.mediaCategory,
                  builder: (context, mediaFilter, _) {
                    return ValueListenableBuilder<String?>(
                      valueListenable: widget.selectedCategoryId,
                      builder: (context, categoryId, _) {
                        final categoriesLabel =
                            _categoryLabel(categoryId) ?? 'Categories';
                        final categoriesActive =
                            _categoriesOpen || categoryId != null;
                        final tabGap = usesTv
                            ? 28.0
                            : MediaQuery.sizeOf(context).width < 560
                            ? 20.0
                            : 36.0;
                        final tabTextHeight =
                            shellScaled(context, 34).clamp(28.0, 34.0);
                        // Provider logo (Home) → Search? → Films → Series → Categories
                        final hasSearch = widget.onSearch != null;
                        final searchIndex = hasFilterLogo ? 1 : 0;
                        final filmsIndex =
                            searchIndex + (hasSearch ? 1 : 0);
                        final seriesIndex = filmsIndex + 1;
                        final categoriesIndex = filmsIndex + 2;

                        final tabs = FocusTraversalGroup(
                          policy: ReadingOrderTraversalPolicy(),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasFilterLogo) ...[
                                Transform.translate(
                                  offset: Offset(
                                    0,
                                    (tabTextHeight - logoHeight) / 2,
                                  ),
                                  child: SizedBox(
                                    width: logoWidth,
                                    height: logoHeight,
                                    child: CatalogVerticalFilterTopBarLogo(
                                      tabId: widget.tabId,
                                      width: logoWidth,
                                      height: logoHeight,
                                      tvFocus: tvFocus,
                                      focusNode:
                                          tvFocus ? _providerLogoFocus : null,
                                      listIndex: tvFocus ? 0 : null,
                                      onDownEdge: tvFocus
                                          ? () => ShellTvFocus
                                              .focusHomeHeroGallery()
                                          : null,
                                    ),
                                  ),
                                ),
                                SizedBox(width: tabGap),
                              ],
                              if (hasSearch) ...[
                                _CategoryTab(
                                  label: 'Search',
                                  icon: Icons.search_rounded,
                                  isActive: false,
                                  onTap: widget.onSearch!,
                                  tvFocus: tvFocus,
                                  tabId: widget.tabId,
                                  listIndex: searchIndex,
                                  focusNode: tvFocus ? _searchFocus : null,
                                  onDownEdge: tvFocus
                                      ? () =>
                                            ShellTvFocus.focusHomeHeroGallery()
                                      : null,
                                ),
                                SizedBox(width: tabGap),
                              ],
                              _CategoryTab(
                                label: 'Films',
                                isActive:
                                    mediaFilter == ShellHomeCategory.films,
                                onTap: () => _toggleMediaFilter(
                                  ShellHomeCategory.films,
                                ),
                                tvFocus: tvFocus,
                                tabId: widget.tabId,
                                listIndex: filmsIndex,
                                focusNode: tvFocus ? _menuFocus : null,
                                onDownEdge: tvFocus
                                    ? () =>
                                          ShellTvFocus.focusHomeHeroGallery()
                                    : null,
                              ),
                              SizedBox(width: tabGap),
                              _CategoryTab(
                                label: widget.seriesLabel,
                                isActive:
                                    mediaFilter == ShellHomeCategory.tvShows,
                                onTap: () => _toggleMediaFilter(
                                  ShellHomeCategory.tvShows,
                                ),
                                tvFocus: tvFocus,
                                tabId: widget.tabId,
                                listIndex: seriesIndex,
                                onDownEdge: tvFocus
                                    ? () =>
                                          ShellTvFocus.focusHomeHeroGallery()
                                    : null,
                              ),
                              SizedBox(width: tabGap),
                              _CategoryTab(
                                key: _categoriesKey,
                                label: categoriesLabel,
                                isActive: categoriesActive,
                                showChevron: true,
                                onTap: _openCategoriesMenu,
                                tvFocus: tvFocus,
                                tabId: widget.tabId,
                                listIndex: categoriesIndex,
                                focusNode:
                                    tvFocus ? _categoriesTabFocus : null,
                                onDownEdge: tvFocus
                                    ? () =>
                                          ShellTvFocus.focusHomeHeroGallery()
                                    : null,
                              ),
                            ],
                          ),
                        );

                        final menuRow = _buildMenuScroll(
                          tabs: tabs,
                          compactNav: compactNav,
                          tvFocus: tvFocus,
                          tabGap: tabGap,
                        );

                        return TvCatalogRow(
                          tabId: widget.tabId,
                          rowId: 'top-bar',
                          sortOrder: -2,
                          itemCount: tvFocus ? (categoriesIndex + 1) : 0,
                          child: menuRow,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryTab extends StatefulWidget {
  const _CategoryTab({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.tabId,
    this.icon,
    this.showChevron = false,
    this.tvFocus = false,
    this.listIndex,
    this.onDownEdge,
    this.focusNode,
  });

  final String label;
  final IconData? icon;
  final bool isActive;
  final VoidCallback onTap;
  final String tabId;
  final bool showChevron;
  final bool tvFocus;
  final int? listIndex;
  final VoidCallback? onDownEdge;
  final FocusNode? focusNode;

  @override
  State<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<_CategoryTab> {
  static const _animDuration = Duration(milliseconds: 280);
  static const _animCurve = Curves.easeInOutCubic;
  static const _hoverT = 0.62;
  static const _selectedT = 1.0;

  bool _hovered = false;
  bool _focused = false;

  double get _visualTarget {
    if (widget.isActive) return _selectedT;
    final policy = ShellScope.inputPolicyOf(context);
    if (_hovered ||
        policy.focusStyled(context, focused: _focused)) {
      return _hoverT;
    }
    return 0;
  }

  Color _lerpTabColor(double t) {
    final idle = ForjaShellColors.cinematic.textSecondary;
    const white = Colors.white;
    final hoverWhite = Colors.white.withValues(alpha: 0.92);
    if (t <= 0) return idle;
    if (t < _hoverT) {
      return Color.lerp(idle, hoverWhite, t / _hoverT)!;
    }
    return Color.lerp(
      hoverWhite,
      white,
      (t - _hoverT) / (_selectedT - _hoverT),
    )!;
  }

  double _underlineWidth(double t, BuildContext context) {
    final hoverW = shellScaled(context, 28).clamp(14.0, 28.0);
    final selectedExtra = shellScaled(context, 4).clamp(2.0, 4.0);
    if (t <= 0) return 0;
    if (t < _hoverT) return hoverW * (t / _hoverT);
    return hoverW + selectedExtra * ((t - _hoverT) / (_selectedT - _hoverT));
  }

  Widget _buildContent() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _visualTarget),
      duration: _animDuration,
      curve: _animCurve,
      builder: (context, t, _) {
        final textColor = _lerpTabColor(t);
        final fontWeight = FontWeight.lerp(
          FontWeight.w500,
          FontWeight.w700,
          t,
        )!;
        final underlineWidth = _underlineWidth(t, context);
        final tabHeight = shellScaled(context, 34).clamp(28.0, 34.0);
        final tabFont = shellScaled(context, 17).clamp(14.0, 17.0);
        final chevronSize = shellScaled(context, 18).clamp(14.0, 18.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: tabHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        size: chevronSize,
                        color: textColor,
                      ),
                      SizedBox(width: shellScaled(context, 6).clamp(4.0, 6.0)),
                    ],
                    Text(
                      widget.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: tabFont,
                        fontWeight: fontWeight,
                        color: textColor,
                        letterSpacing: 0.1,
                      ),
                    ),
                    if (widget.showChevron) ...[
                      SizedBox(width: shellScaled(context, 4).clamp(2.0, 4.0)),
                      Icon(
                        Icons.expand_more_rounded,
                        size: chevronSize,
                        color: textColor,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(
              height: shellScaled(
                context,
                ShellTokens.shellCategoryUnderlineGap,
              ).clamp(2.0, ShellTokens.shellCategoryUnderlineGap),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: shellScaled(
                  context,
                  ShellTokens.shellNavUnderlineHeight,
                ).clamp(1.0, ShellTokens.shellNavUnderlineHeight),
                width: underlineWidth,
                decoration: BoxDecoration(
                  color: underlineWidth > 0 ? textColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tvFocus) {
      return shellFocusableTap(
        context: context,
        onTap: widget.onTap,
        borderRadius: 4,
        scaleOnFocus: ShellTokens.focusActiveScale,
        listIndex: widget.listIndex,
        tvTabId: widget.tabId,
        tvRowId: 'top-bar',
        tvZone: ShellTvZone.topBar,
        tvItemIndex: widget.listIndex,
        onDownEdge: widget.onDownEdge,
        focusNode: widget.focusNode,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onHoverChange: (hovered) => setState(() => _hovered = hovered),
        child: _buildContent(),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: _buildContent(),
      ),
    );
  }
}

class _FlatMenuRow extends StatefulWidget {
  const _FlatMenuRow({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.tabId,
    this.listIndex,
    this.tvFocus = false,
    this.focusNode,
    this.onUpEdge,
    this.onLeftEdge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String tabId;
  final int? listIndex;
  final bool tvFocus;
  final FocusNode? focusNode;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;

  @override
  State<_FlatMenuRow> createState() => _FlatMenuRowState();
}

class _FlatMenuRowState extends State<_FlatMenuRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    final policy = ShellScope.inputPolicyOf(context);
    final focusStyled = policy.focusStyled(context, focused: _focused);
    final highlight = widget.selected || _hovered || focusStyled;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        widget.label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
          color: highlight ? Colors.white : cinematic.textSecondary,
        ),
      ),
    );

    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 4,
      listIndex: widget.listIndex,
      focusNode: widget.focusNode,
      onUpEdge: widget.onUpEdge,
      onLeftEdge: widget.onLeftEdge,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      tvTabId: widget.tvFocus ? widget.tabId : null,
      tvZone: widget.tvFocus ? ShellTvZone.topBar : null,
      tvItemIndex: widget.listIndex,
      child: row,
    );
  }
}

class _DismissCategoriesIntent extends Intent {
  const _DismissCategoriesIntent();
}
