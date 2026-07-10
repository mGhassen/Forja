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
        return ShellScope(
          profile: shellScope.profile,
          config: shellScope.config,
          child: Stack(
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
                          color: ForjaShellColors.cinematic.borderSubtle),
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _FlatMenuRow(
                                  label: 'All',
                                  selected: selectedId == null,
                                  onTap: () => Navigator.of(dialogContext)
                                      .pop(_allGenresSentinel),
                                ),
                                for (final genre in homeGenreCategories)
                                  _FlatMenuRow(
                                    label: genre.label,
                                    selected: genre.id == selectedId,
                                    onTap: () =>
                                        Navigator.of(dialogContext).pop(genre.id),
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
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    setState(() => _categoriesOpen = false);
    if (picked == null) return;

    final next = picked == _allGenresSentinel ? null : picked;
    if (next != ShellBus.homeSelectedGenreId.value) {
      ShellBus.homeSelectedGenreId.value = next;
    }
  }

  void _openSearch() {
    pushShellRoute(
      context,
      AppRouter.slideRoute((_) => const SearchScreen(overlay: true)),
    );
  }

  Widget _buildSearchAction({required bool tvFocus}) {
    if (tvFocus) {
      return shellFocusableTap(
        context: context,
        onTap: _openSearch,
        borderRadius: 22,
        scaleOnFocus: ShellTokens.focusActiveScale,
        tvTabId: 'home',
        tvZone: ShellTvZone.topBar,
        focusNode: _searchFocus,
        onUpEdge: ShellTvFocus.focusHomeMenu,
        onDownEdge: () => ShellTvFocus.focusHomeHeroPlay(),
        child: const SizedBox(
          height: 34,
          width: 44,
          child: Center(
            child: Icon(Icons.search_rounded, color: Colors.white, size: 30),
          ),
        ),
      );
    }

    final icon = ForjaPlainIcon(
      icon: Icons.search_rounded,
      color: Colors.white,
      size: 30,
      hitSize: 44,
      hoverScale: ShellTokens.focusActiveScale,
      focusNode: tvFocus ? _searchFocus : null,
      onTap: _openSearch,
      onKeyEvent: null,
    );

    return SizedBox(height: 34, child: Center(child: icon));
  }

  Widget _wrapMenuRow(Widget menu, {required bool tvFocus}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: menu),
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
        top: !tvFocus,
        child: SizedBox(
          height: ShellTokens.homeTopBarHeight,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              ShellTokens.bodyHorizontalPadding +
                  (compactNav ? 0 : ShellTokens.homeTopBarMenuLeadingInset),
              tvFocus ? 0 : ShellTokens.shellHeaderTopPadding,
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
                    final categoriesActive =
                        _categoriesOpen || genreId != null;
                    final tabGap = MediaQuery.sizeOf(context).width < 560
                        ? 20.0
                        : 36.0;

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
                              ? ShellTvFocus.focusHomeSearch
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
                              ? () => ShellTvFocus.focusHomeHeroPlay()
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
                          onDownEdge: tvFocus
                              ? () => ShellTvFocus.focusHomeHeroPlay()
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
  bool _hovered = false;
  bool _focused = false;

  Widget _buildContent() {
    final selected = widget.isActive;
    final highlighted = _hovered || _focused;
    final showUnderline = selected || highlighted;
    final textColor = selected
        ? Colors.white
        : highlighted
            ? Colors.white.withValues(alpha: 0.92)
            : ForjaShellColors.cinematic.textSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 34,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: selected
                        ? FontWeight.w700
                        : highlighted
                            ? FontWeight.w600
                            : FontWeight.w500,
                    color: textColor,
                    letterSpacing: 0.1,
                  ),
                ),
                if (widget.showChevron) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: textColor,
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: ShellTokens.shellCategoryUnderlineGap),
        AnimatedContainer(
          duration: ShellTokens.navSelectionAnimation,
          curve: Curves.easeOutCubic,
          height: ShellTokens.shellNavUnderlineHeight,
          width: showUnderline ? (selected ? 32 : 28) : 0,
          decoration: BoxDecoration(
            color: showUnderline
                ? (selected ? Colors.white : Colors.white.withValues(alpha: 0.92))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

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
          color: selected
              ? cinematic.textPrimary
              : cinematic.textSecondary,
        ),
      ),
    );

    return shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: 4,
      child: row,
    );
  }
}
