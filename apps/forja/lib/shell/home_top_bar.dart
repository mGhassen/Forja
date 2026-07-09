import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forja/features/home/home_genre_categories.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_nav_rail.dart';
import 'package:forja/shared/design/design.dart';
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
      pageBuilder: (context, _, _) {
        return Stack(
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
                                onTap: () => Navigator.of(context)
                                    .pop(_allGenresSentinel),
                              ),
                              for (final genre in homeGenreCategories)
                                _FlatMenuRow(
                                  label: genre.label,
                                  selected: genre.id == selectedId,
                                  onTap: () =>
                                      Navigator.of(context).pop(genre.id),
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
    ShellBus.requestTab.value = 'search';
  }

  Widget _buildSearchAction() {
    return SizedBox(
      height: 34,
      child: Center(
        child: ForjaPlainIcon(
          icon: Icons.search_rounded,
          color: Colors.white,
          size: 30,
          hitSize: 44,
          onTap: _openSearch,
        ),
      ),
    );
  }

  Widget _wrapMenuRow(Widget menu) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: menu),
        _buildSearchAction(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final compactNav =
        MediaQuery.sizeOf(context).width < ShellTokens.shellNavCompactMaxWidth;

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
        child: SizedBox(
          height: ShellTokens.homeTopBarHeight,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              ShellTokens.bodyHorizontalPadding +
                  (compactNav ? 0 : ShellTokens.homeTopBarMenuLeadingInset),
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
                        ),
                        SizedBox(width: tabGap),
                        _CategoryTab(
                          label: 'TV Shows',
                          isActive: mediaFilter == ShellHomeCategory.tvShows,
                          onTap: () =>
                              _toggleMediaFilter(ShellHomeCategory.tvShows),
                        ),
                        SizedBox(width: tabGap),
                        _CategoryTab(
                          key: _categoriesKey,
                          label: categoriesLabel,
                          isActive: categoriesActive,
                          showChevron: true,
                          onTap: _openCategoriesMenu,
                        ),
                      ],
                    );

                    if (!compactNav) {
                      return _wrapMenuRow(
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: tabs,
                        ),
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
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    final color =
        isActive ? cinematic.textPrimary : cinematic.textSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
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
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: color,
                        letterSpacing: 0.1,
                      ),
                    ),
                    if (showChevron) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.expand_more_rounded,
                        size: 18,
                        color: color,
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
              width: isActive ? 28 : 0,
              decoration: BoxDecoration(
                color: isActive ? cinematic.navUnderline : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
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
        ),
      ),
    );
  }
}
