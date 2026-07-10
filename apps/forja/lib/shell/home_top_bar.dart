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
    final icon = ForjaPlainIcon(
      icon: Icons.search_rounded,
      color: Colors.white,
      size: 30,
      hitSize: 44,
      hoverScale: ShellTokens.focusActiveScale,
      focusNode: tvFocus ? _searchFocus : null,
      onTap: _openSearch,
      onKeyEvent: tvFocus
          ? (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                if (ShellTvFocus.focusHomeMenu()) return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                if (ShellTvFocus.focusHomeHeroPlay()) {
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            }
          : null,
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

                    final tabs = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CategoryTab(
                          label: 'Films',
                          isActive: mediaFilter == ShellHomeCategory.films,
                          onTap: () =>
                              _toggleMediaFilter(ShellHomeCategory.films),
                          tvFocus: tvFocus,
                          focusNode: tvFocus ? _menuFocus : null,
                          onKeyEvent: tvFocus
                              ? (node, event) {
                                  if (event is! KeyDownEvent) {
                                    return KeyEventResult.ignored;
                                  }
                                  if (event.logicalKey ==
                                      LogicalKeyboardKey.arrowDown) {
                                    if (ShellTvFocus.focusHomeSearch()) {
                                      return KeyEventResult.handled;
                                    }
                                  }
                                  return KeyEventResult.ignored;
                                }
                              : null,
                        ),
                        SizedBox(width: tabGap),
                        _CategoryTab(
                          label: 'TV Shows',
                          isActive: mediaFilter == ShellHomeCategory.tvShows,
                          onTap: () =>
                              _toggleMediaFilter(ShellHomeCategory.tvShows),
                          tvFocus: tvFocus,
                        ),
                        SizedBox(width: tabGap),
                        _CategoryTab(
                          key: _categoriesKey,
                          label: categoriesLabel,
                          isActive: categoriesActive,
                          showChevron: true,
                          onTap: _openCategoriesMenu,
                          tvFocus: tvFocus,
                        ),
                      ],
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
                            ...tabs.children,
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

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.showChevron = false,
    this.tvFocus = false,
    this.focusNode,
    this.onKeyEvent,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool showChevron;
  final bool tvFocus;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;

    Widget buildContent(bool focused) {
      final active = isActive || focused;
      final tabColor =
          active ? cinematic.textPrimary : cinematic.textSecondary;
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
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: tabColor,
                      letterSpacing: 0.1,
                    ),
                  ),
                  if (showChevron) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: tabColor,
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: ShellTokens.shellCategoryUnderlineGap),
          AnimatedContainer(
            duration: ShellTokens.navSelectionAnimation,
            height: ShellTokens.shellNavUnderlineHeight,
            width: active ? 28 : 0,
            decoration: BoxDecoration(
              color: active ? cinematic.navUnderline : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      );
    }

    if (tvFocus) {
      return ForjaInteractive(
        focusNode: focusNode,
        onTap: onTap,
        onKeyEvent: onKeyEvent,
        hoverScale: ShellTokens.focusActiveScale,
        builder: (focused, _) => buildContent(focused),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: buildContent(false),
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
