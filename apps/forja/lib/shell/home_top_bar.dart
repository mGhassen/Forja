import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/features/home/home_genre_categories.dart';
import 'package:forja/features/search/search_screen.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_nav_rail.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sentinel for the "All" entry in the categories popup menu.
const _allGenresSentinel = '__all__';

/// Films / TV Shows / Categories menu overlaid on the Home hero.
class HomeTopBar extends StatefulWidget {
  const HomeTopBar({super.key});

  static const _hideSlideDistance = 56.0;

  @override
  State<HomeTopBar> createState() => _HomeTopBarState();
}

class _HomeTopBarState extends State<HomeTopBar> {
  final GlobalKey _categoriesKey = GlobalKey();
  bool _categoriesOpen = false;
  final FocusNode _menuFocus = FocusNode(debugLabel: 'home-menu');
  final FocusNode _searchFocus = FocusNode(debugLabel: 'home-search');
  final FocusNode _categoriesTabFocus = FocusNode(
    debugLabel: 'home-categories-tab',
  );
  final FocusNode _categoriesMenuFocus = FocusNode(
    debugLabel: 'home-categories-menu',
  );

  @override
  void initState() {
    super.initState();
    ShellTvFocus.homeMenu = _menuFocus;
    ShellTvFocus.homeSearch = _searchFocus;
  }

  @override
  void dispose() {
    if (ShellTvFocus.homeMenu == _menuFocus) ShellTvFocus.homeMenu = null;
    if (ShellTvFocus.homeSearch == _searchFocus) ShellTvFocus.homeSearch = null;
    _menuFocus.dispose();
    _searchFocus.dispose();
    _categoriesTabFocus.dispose();
    _categoriesMenuFocus.dispose();
    super.dispose();
  }

  void _toggleMediaFilter(ShellHomeCategory target) {
    final current = ShellBus.homeCategory.value;
    ShellBus.homeCategory.value = current == target ? null : target;
  }

  Future<void> _openCategoriesMenu() async {
    final box = _categoriesKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final offset = box.localToGlobal(Offset.zero);
    final selectedId = ShellBus.homeSelectedGenreId.value;

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
                            policy: OrderedTraversalPolicy(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _FlatMenuRow(
                                  label: 'All',
                                  selected: selectedId == null,
                                  listIndex: 0,
                                  tvFocus: tvFocus,
                                  focusNode: tvFocus
                                      ? _categoriesMenuFocus
                                      : null,
                                  onUpEdge: tvFocus ? dismissMenu : null,
                                  onLeftEdge: tvFocus ? dismissMenu : null,
                                  onTap: () => Navigator.of(
                                    dialogContext,
                                  ).pop(_allGenresSentinel),
                                ),
                                for (
                                  var i = 0;
                                  i < homeGenreCategories.length;
                                  i++
                                )
                                  _FlatMenuRow(
                                    label: homeGenreCategories[i].label,
                                    selected:
                                        homeGenreCategories[i].id == selectedId,
                                    listIndex: i + 1,
                                    tvFocus: tvFocus,
                                    onLeftEdge: tvFocus ? dismissMenu : null,
                                    onTap: () => Navigator.of(
                                      dialogContext,
                                    ).pop(homeGenreCategories[i].id),
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
    if (picked == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _categoriesTabFocus.canRequestFocus) {
          _categoriesTabFocus.requestFocus();
        }
      });
      return;
    }

    final next = picked == _allGenresSentinel ? null : picked;
    if (next != ShellBus.homeSelectedGenreId.value) {
      ShellBus.homeSelectedGenreId.value = next;
    }
  }

  void _openSearch() {
    pushShellRoute(
      context,
      AppRouter.slideShellRoute((_) => const SearchScreen(overlay: true)),
    );
  }

  Widget _buildSearchAction({required bool tvFocus}) {
    final searchH = shellScaled(context, 34).clamp(24.0, 34.0);
    final searchW = shellScaled(context, 44).clamp(32.0, 44.0);
    final iconSize = shellScaled(context, 30).clamp(20.0, 30.0);
    if (tvFocus) {
      return shellFocusableTap(
        context: context,
        onTap: _openSearch,
        borderRadius: shellScaled(context, 22).clamp(14.0, 22.0),
        scaleOnFocus: ShellTokens.focusActiveScale,
        listIndex: 3,
        tvTabId: 'home',
        tvRowId: 'top-bar',
        tvZone: ShellTvZone.topBar,
        tvItemIndex: 3,
        focusNode: _searchFocus,
        onDownEdge: () => ShellTvFocus.focusHomeHeroGallery(),
        child: SizedBox(
          height: searchH,
          width: searchW,
          child: Center(
            child: Icon(
              Icons.search_rounded,
              color: Colors.white,
              size: iconSize,
            ),
          ),
        ),
      );
    }

    final icon = ForjaTopBarIcon(
      icon: Icons.search_rounded,
      size: iconSize,
      hitSize: searchW,
      onTap: _openSearch,
    );

    return SizedBox(height: 34, child: Center(child: icon));
  }

  Widget _wrapMenuRow(
    Widget menu, {
    required bool tvFocus,
    required double tabGap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: menu),
        SizedBox(width: tabGap),
        _buildSearchAction(tvFocus: tvFocus),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final compactNav =
        MediaQuery.sizeOf(context).width < ShellTokens.shellNavCompactMaxWidth;
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;

    return ValueListenableBuilder<double>(
      valueListenable: ShellBus.homeScrollOffset,
      builder: (context, scrollOffset, child) {
        return ValueListenableBuilder<double>(
          valueListenable: ShellBus.homeHeroHeight,
          builder: (context, heroHeight, menu) {
            final topInset = MediaQuery.paddingOf(context).top;
            final barHeight = topInset + ShellTokens.homeTopBarHeight;
            final hideStart = math.max(0.0, heroHeight - barHeight);
            final hideProgress = heroHeight <= 0
                ? 0.0
                : ((scrollOffset - hideStart) / HomeTopBar._hideSlideDistance)
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
          height: ShellTokens.homeTopBarHeight,
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
              valueListenable: ShellBus.homeCategory,
              builder: (context, mediaFilter, _) {
                return ValueListenableBuilder<String?>(
                  valueListenable: ShellBus.homeSelectedGenreId,
                  builder: (context, genreId, _) {
                    final categoriesLabel =
                        homeGenreLabel(genreId) ?? 'Categories';
                    final categoriesActive = _categoriesOpen || genreId != null;
                    final usesTv = ShellScope.metricsOf(context).usesTvDensity;
                    final tabGap = usesTv
                        ? 28.0
                        : MediaQuery.sizeOf(context).width < 560
                        ? 20.0
                        : 36.0;

                    if (tvFocus) {
                      shellTvRegisterRow(
                        tabId: 'home',
                        rowId: 'top-bar',
                        sortOrder: -2,
                        itemCount: 4,
                      );
                    }

                    final tabs = FocusTraversalGroup(
                      policy: OrderedTraversalPolicy(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CategoryTab(
                            label: 'Films',
                            isActive: mediaFilter == ShellHomeCategory.films,
                            onTap: () =>
                                _toggleMediaFilter(ShellHomeCategory.films),
                            tvFocus: tvFocus,
                            listIndex: 0,
                            focusNode: tvFocus ? _menuFocus : null,
                            onDownEdge: tvFocus
                                ? () => ShellTvFocus.focusHomeHeroGallery()
                                : null,
                          ),
                          SizedBox(width: tabGap),
                          _CategoryTab(
                            label: 'TV Shows',
                            isActive: mediaFilter == ShellHomeCategory.tvShows,
                            onTap: () =>
                                _toggleMediaFilter(ShellHomeCategory.tvShows),
                            tvFocus: tvFocus,
                            listIndex: 1,
                            onDownEdge: tvFocus
                                ? () => ShellTvFocus.focusHomeHeroGallery()
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
                            listIndex: 2,
                            focusNode: tvFocus ? _categoriesTabFocus : null,
                            onDownEdge: tvFocus
                                ? () => ShellTvFocus.focusHomeHeroGallery()
                                : null,
                          ),
                        ],
                      ),
                    );

                    if (!compactNav || tvFocus) {
                      return _wrapMenuRow(
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: tabs,
                        ),
                        tvFocus: tvFocus,
                        tabGap: tabGap,
                      );
                    }

                    return _wrapMenuRow(
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 34,
                              child: Center(
                                child: ShellNavMenuButton(
                                  onPressed: () =>
                                      Scaffold.of(context).openDrawer(),
                                ),
                              ),
                            ),
                            SizedBox(width: tabGap),
                            tabs,
                          ],
                        ),
                      ),
                      tvFocus: tvFocus,
                      tabGap: tabGap,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryTab extends StatefulWidget {
  const _CategoryTab({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.showChevron = false,
    this.tvFocus = false,
    this.listIndex,
    this.onDownEdge,
    this.focusNode,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
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
    if (_hovered || _focused) return _hoverT;
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
                    Text(
                      widget.label,
                      style: GoogleFonts.inter(
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
        tvTabId: 'home',
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

class _FlatMenuRow extends StatelessWidget {
  const _FlatMenuRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.listIndex,
    this.tvFocus = false,
    this.focusNode,
    this.onUpEdge,
    this.onLeftEdge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? listIndex;
  final bool tvFocus;
  final FocusNode? focusNode;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? cinematic.textPrimary : cinematic.textSecondary,
        ),
      ),
    );

    return shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: 4,
      listIndex: listIndex,
      focusNode: focusNode,
      onUpEdge: onUpEdge,
      onLeftEdge: onLeftEdge,
      tvTabId: tvFocus ? 'home' : null,
      tvZone: tvFocus ? ShellTvZone.topBar : null,
      tvItemIndex: listIndex,
      child: row,
    );
  }
}

class _DismissCategoriesIntent extends Intent {
  const _DismissCategoriesIntent();
}
