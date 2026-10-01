import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/engine/runtime/nav/chrome_menu_item.dart';
import 'package:forja/shared/engine/runtime/nav/vertical_filters.dart';
import 'package:forja/shell/chrome/vertical_filters_rail.dart';
import 'package:forja/shell/core/forja_shell_layout.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/blocks/shell/catalog_density.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:google_fonts/google_fonts.dart';

export 'package:forja_foundation/widgets/chrome/hub_top_bar.dart' show HubTopBar;

/// Sentinel for the "All" entry in the categories popup menu.
const catalogAllCategoriesSentinel = '__all__';

/// Pack-driven hub chrome: Search? + [menus] + Categories? overlaid on hero.
class KitChromeTopBar extends StatefulWidget {
  const KitChromeTopBar({
    super.key,
    required this.tabId,
    required this.selectedMenuId,
    required this.selectedCategoryId,
    required this.menus,
    required this.categories,
    required this.scrollOffset,
    required this.heroHeight,
    required this.onSearch,
  });

  final String tabId;
  final ValueNotifier<String?> selectedMenuId;
  final ValueNotifier<String?> selectedCategoryId;

  /// Pack `filters.menus[]` — any count / labels (host does not invent Films).
  final List<ChromeMenuItem> menus;
  final List<({String id, String label})> categories;
  final ValueNotifier<double> scrollOffset;
  final ValueNotifier<double> heroHeight;

  /// Null when the pack does not declare `search` — Search tab is omitted.
  final VoidCallback? onSearch;

  static const hideSlideDistance = ShellTokens.kitTopBarHideSlideDistance;

  @override
  State<KitChromeTopBar> createState() => _KitChromeTopBarState();
}

class _KitChromeTopBarState extends State<KitChromeTopBar> {
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
    _syncSharedSearchFocus();
  }

  /// KeepAlive hubs all mount — only the active tab owns [hubHeroSearch].
  void _syncSharedSearchFocus() {
    if (ShellTvFocus.currentNavTabId != widget.tabId) return;
    ShellTvFocus.hubHeroSearch = _searchFocus;
  }

  @override
  void dispose() {
    if (ShellTvFocus.hubHeroSearch == _searchFocus) {
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

  void _toggleMenu(String id) {
    final current = widget.selectedMenuId.value;
    widget.selectedMenuId.value = current == id ? null : id;
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
        final usesTv = shellScope.metrics.usesTvDensity;
        void dismissMenu() => Navigator.of(dialogContext).pop();

        Widget menu = Stack(
          children: [
            Positioned(
              left: offset.dx,
              top: offset.dy + box.size.height + ShellTokens.homeCategoriesMenuOffsetY,
              child: Material(
                color: ForjaShellColors.cinematic.menuSurface,
                elevation: 8,
                borderRadius: BorderRadius.circular(
                  ShellTokens.homeCategoriesMenuRadius,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      ShellTokens.homeCategoriesMenuRadius,
                    ),
                    border: Border.all(
                      color: ForjaShellColors.cinematic.borderSubtle,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      ShellTokens.homeCategoriesMenuRadius,
                    ),
                    child: IntrinsicWidth(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: usesTv
                              ? ShellTokens.homeCategoriesMenuMaxHeightTv
                              : ShellTokens.homeCategoriesMenuMaxHeight,
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

  Widget _buildMenuScroll({required Widget tabs}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: tabs,
    );
  }

  @override
  Widget build(BuildContext context) {
    // KeepAlive hubs all mount — only the active tab owns shared search.
    _syncSharedSearchFocus();

    final compactNav =
        MediaQuery.sizeOf(context).width < ShellTokens.shellNavCompactMaxWidth;
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;

    return ValueListenableBuilder<String?>(
      valueListenable: VerticalFiltersRegistry.selectedIdFor(
        widget.tabId,
      ),
      builder: (context, selectedFilterId, _) {
        final spec = VerticalFiltersRegistry.specFor(widget.tabId);
        final hasFilterLogo = spec?.showSelectedInTopBar == true &&
            selectedFilterId != null;
        final usesTv = ShellScope.metricsOf(context).usesTvDensity;
        final logoWidth = usesTv
            ? ShellTokens.shellProviderTopBarIconWidthTv
            : ShellTokens.shellProviderTopBarIconWidth;
        final logoHeight = usesTv
            ? ShellTokens.shellProviderTopBarIconHeightTv
            : ShellTokens.shellProviderTopBarIconHeight;
        final barContentHeight = catalogHomeTopBarHeight(context);

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
                              KitChromeTopBar.hideSlideDistance)
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
                padding: EdgeInsetsDirectional.fromSTEB(
                  // Compact: clear scaffold-owned ☰ lane (not a second button).
                  compactNav
                      ? ShellTokens.compactChromeLeadingInset(context)
                      : ShellTokens.bodyHorizontalPadding +
                            (usesTv
                                ? ShellTokens.homeTopBarMenuLeadingInsetTv
                                : ShellTokens.homeTopBarMenuLeadingInset),
                  // Must match homeTopBarHeight(Tv) budget — unscaled pad on TV
                  // steals ~2.4px and overflows the tab Column by ~1.9px.
                  usesTv
                      ? ShellTokens.shellHeaderTopPaddingTv
                      : ShellTokens.shellHeaderTopPadding,
                  ShellTokens.bodyHorizontalPadding,
                  0,
                ),
                child: ValueListenableBuilder<String?>(
                  valueListenable: widget.selectedMenuId,
                  builder: (context, menuId, _) {
                    return ValueListenableBuilder<String?>(
                      valueListenable: widget.selectedCategoryId,
                      builder: (context, categoryId, _) {
                        final categoriesLabel =
                            _categoryLabel(categoryId) ?? 'Categories';
                        final categoriesActive =
                            _categoriesOpen || categoryId != null;
                        final tabGap = usesTv
                            ? ShellTokens.kitTopBarTabGapTv
                            : MediaQuery.sizeOf(context).width <
                                    ShellTokens.kitTopBarTabGapCompactMaxWidth
                            ? ShellTokens.kitTopBarTabGapCompact
                            : ShellTokens.kitTopBarTabGapWide;
                        final menuRowHeight = usesTv
                            ? ShellTokens.homeMenuRowHeightTv
                            : ShellTokens.homeMenuRowHeight;
                        final tabTextHeight = shellScaled(
                          context,
                          menuRowHeight,
                        );
                        // Provider logo → Search? → pack menus[] → Categories?
                        final hasSearch = widget.onSearch != null;
                        final menus = widget.menus;
                        final showCategories = widget.categories.isNotEmpty;
                        final searchIndex = hasFilterLogo ? 1 : 0;
                        final menusStart =
                            searchIndex + (hasSearch ? 1 : 0);
                        final categoriesIndex = menusStart + menus.length;
                        final menuItemCount = showCategories
                            ? categoriesIndex + 1
                            : menus.isNotEmpty
                            ? menusStart + menus.length
                            : hasSearch
                            ? searchIndex + 1
                            : hasFilterLogo
                            ? 1
                            : 0;

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
                                    child: VerticalFilterTopBarLogo(
                                      tabId: widget.tabId,
                                      width: logoWidth,
                                      height: logoHeight,
                                      tvFocus: tvFocus,
                                      focusNode:
                                          tvFocus ? _providerLogoFocus : null,
                                      listIndex: tvFocus ? 0 : null,
                                      onDownEdge: tvFocus
                                          ? () => ShellTvFocusCoordinator
                                              .focusHero(tabId: widget.tabId)
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
                                            ShellTvFocusCoordinator.focusHero(tabId: widget.tabId)
                                      : null,
                                  onUpEdge: tvFocus
                                      ? () {
                                          ShellTvFocus.registerTopBarMiniDoor(
                                            _searchFocus,
                                          );
                                          ShellTvFocus.tryFocusMiniFromTopBar();
                                        }
                                      : null,
                                ),
                                SizedBox(width: tabGap),
                              ],
                              for (var i = 0; i < menus.length; i++) ...[
                                if (i > 0) SizedBox(width: tabGap),
                                _CategoryTab(
                                  label: menus[i].label,
                                  isActive: menuId == menus[i].id,
                                  onTap: () => _toggleMenu(menus[i].id),
                                  tvFocus: tvFocus,
                                  tabId: widget.tabId,
                                  listIndex: menusStart + i,
                                  focusNode: tvFocus && i == 0
                                      ? _menuFocus
                                      : null,
                                  onDownEdge: tvFocus
                                      ? () =>
                                            ShellTvFocusCoordinator.focusHero(tabId: widget.tabId)
                                      : null,
                                  onUpEdge: tvFocus
                                      ? () {
                                          ShellTvFocus.registerTopBarMiniDoor(
                                            i == 0 ? _menuFocus : null,
                                          );
                                          ShellTvFocus.tryFocusMiniFromTopBar();
                                        }
                                      : null,
                                ),
                              ],
                              if (menus.isNotEmpty && showCategories)
                                SizedBox(width: tabGap),
                              if (showCategories)
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
                                            ShellTvFocusCoordinator.focusHero(tabId: widget.tabId)
                                      : null,
                                  onUpEdge: tvFocus
                                      ? () {
                                          ShellTvFocus.registerTopBarMiniDoor(
                                            _categoriesTabFocus,
                                          );
                                          ShellTvFocus.tryFocusMiniFromTopBar();
                                        }
                                      : null,
                                ),
                            ],
                          ),
                        );

                        final menuRow = _buildMenuScroll(tabs: tabs);

                        return TvKitRow(
                          tabId: widget.tabId,
                          rowId: 'top-bar',
                          sortOrder: -2,
                          itemCount: tvFocus ? menuItemCount : 0,
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
    this.onUpEdge,
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
  final VoidCallback? onUpEdge;
  final FocusNode? focusNode;

  @override
  State<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<_CategoryTab> {
  static const _animDuration = ShellTokens.kitTopBarTabAnimation;
  static const _animCurve = Curves.easeInOutCubic;
  static const _hoverT = 0.62;
  static const _selectedT = 1.0;

  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _focused = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    if (_hoveredN.value == hovered) return;
    _hoveredN.value = hovered;
  }

  double _visualTargetFor(bool hovered) {
    if (widget.isActive) return _selectedT;
    final policy = ShellScope.inputPolicyOf(context);
    if (hovered || policy.focusStyled(context, focused: _focused)) {
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
    final hoverW = shellScaled(
      context,
      ShellTokens.kitTopBarUnderlineHoverWidth,
    );
    final selectedExtra = shellScaled(
      context,
      ShellTokens.kitTopBarUnderlineSelectedExtra,
    );
    if (t <= 0) return 0;
    if (t < _hoverT) return hoverW * (t / _hoverT);
    return hoverW + selectedExtra * ((t - _hoverT) / (_selectedT - _hoverT));
  }

  Widget _buildContent(bool hovered) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _visualTargetFor(hovered)),
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
        final usesTv = ShellScope.metricsOf(context).usesTvDensity;
        // Spatial + type: use TV tokens directly — never shellScaled on type
        // (poster layout scale would crush tab text to ~5px).
        final tabHeight = usesTv
            ? ShellTokens.homeMenuRowHeightTv
            : ShellTokens.homeMenuRowHeight;
        final tabFont = usesTv
            ? ShellTokens.kitTopBarTabFontSizeTv
            : ShellTokens.kitTopBarTabFontSize;
        final chevronSize = usesTv
            ? ShellTokens.kitTopBarChevronSizeTv
            : ShellTokens.kitTopBarChevronSize;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: tabHeight,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        size: chevronSize,
                        color: textColor,
                      ),
                      SizedBox(
                        width: shellScaled(
                          context,
                          ShellTokens.kitTopBarIconGap,
                        ),
                      ),
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
                      SizedBox(
                        width: shellScaled(
                          context,
                          ShellTokens.kitTopBarChevronGap,
                        ),
                      ),
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
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                height: shellScaled(
                  context,
                  ShellTokens.shellNavUnderlineHeight,
                ),
                width: underlineWidth,
                decoration: BoxDecoration(
                  color: underlineWidth > 0 ? textColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(
                    ShellTokens.shellNavUnderlineRadius,
                  ),
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
        borderRadius: ShellTokens.kitTopBarFocusRadius,
        scaleOnFocus: 1.0,
        listIndex: widget.listIndex,
        tvTabId: widget.tabId,
        tvRowId: 'top-bar',
        tvZone: ShellTvZone.topBar,
        tvItemIndex: widget.listIndex,
        onDownEdge: widget.onDownEdge,
        onUpEdge: widget.onUpEdge,
        focusNode: widget.focusNode,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onHoverChange: _setHovered,
        child: ListenableBuilder(
          listenable: _hoveredN,
          builder: (context, _) => _buildContent(_hoveredN.value),
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: ListenableBuilder(
          listenable: _hoveredN,
          builder: (context, _) => _buildContent(_hoveredN.value),
        ),
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
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _focused = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    if (_hoveredN.value == hovered) return;
    _hoveredN.value = hovered;
  }

  Widget _buildRow(bool hovered) {
    final cinematic = ForjaShellColors.cinematic;
    final policy = ShellScope.inputPolicyOf(context);
    final usesTv = ShellScope.metricsOf(context).usesTvDensity;
    final focusStyled = policy.focusStyled(context, focused: _focused);
    final highlight = widget.selected || hovered || focusStyled;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: usesTv
            ? ShellTokens.homeCategoriesMenuRowPadHTv
            : ShellTokens.homeCategoriesMenuRowPadH,
        vertical: usesTv
            ? ShellTokens.homeCategoriesMenuRowPadVTv
            : ShellTokens.homeCategoriesMenuRowPadV,
      ),
      child: Text(
        widget.label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: usesTv
              ? ShellTokens.homeCategoriesMenuFontSizeTv
              : ShellTokens.homeCategoriesMenuFontSize,
          fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
          color: highlight ? Colors.white : cinematic.textSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: ShellTokens.kitTopBarFocusRadius,
      listIndex: widget.listIndex,
      focusNode: widget.focusNode,
      onUpEdge: widget.onUpEdge,
      onLeftEdge: widget.onLeftEdge,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: _setHovered,
      tvTabId: widget.tvFocus ? widget.tabId : null,
      tvZone: widget.tvFocus ? ShellTvZone.topBar : null,
      tvItemIndex: widget.listIndex,
      child: ListenableBuilder(
        listenable: _hoveredN,
        builder: (context, _) => _buildRow(_hoveredN.value),
      ),
    );
  }
}

class _DismissCategoriesIntent extends Intent {
  const _DismissCategoriesIntent();
}
