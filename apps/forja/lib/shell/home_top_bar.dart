import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forja/features/home/home_genre_categories.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
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
  final GlobalKey _menuKey = GlobalKey();
  bool _categoriesOpen = false;

  void _toggleMediaFilter(ShellHomeCategory target) {
    final current = ShellBus.homeCategory.value;
    ShellBus.homeCategory.value = current == target ? null : target;
  }

  Future<void> _openCompactMenu() async {
    final box = _menuKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final offset = box.localToGlobal(Offset.zero);
    final mediaFilter = ShellBus.homeCategory.value;
    final genreId = ShellBus.homeSelectedGenreId.value;
    final categoriesLabel = homeGenreLabel(genreId) ?? 'Categories';
    final categoriesActive = _categoriesOpen || genreId != null;

    final picked = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss home menu',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 150),
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
                      color: ForjaShellColors.cinematic.borderSubtle,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: IntrinsicWidth(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _FlatMenuRow(
                            label: 'Films',
                            selected: mediaFilter == ShellHomeCategory.films,
                            onTap: () =>
                                Navigator.of(context).pop('films'),
                          ),
                          _FlatMenuRow(
                            label: 'TV Shows',
                            selected: mediaFilter == ShellHomeCategory.tvShows,
                            onTap: () =>
                                Navigator.of(context).pop('tv'),
                          ),
                          _FlatMenuRow(
                            label: categoriesLabel,
                            selected: categoriesActive,
                            onTap: () {
                              Navigator.of(context).pop();
                              _openCategoriesMenu(anchorKey: _menuKey);
                            },
                          ),
                        ],
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

    if (!mounted || picked == null) return;
    if (picked == 'films') {
      _toggleMediaFilter(ShellHomeCategory.films);
    } else if (picked == 'tv') {
      _toggleMediaFilter(ShellHomeCategory.tvShows);
    }
  }

  Future<void> _openCategoriesMenu({GlobalKey? anchorKey}) async {
    final box =
        (anchorKey ?? _categoriesKey).currentContext?.findRenderObject()
            as RenderBox?;
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

  @override
  Widget build(BuildContext context) {
    final bodyWidth = MediaQuery.sizeOf(context).width;
    final compact = bodyWidth < ShellTokens.homeTopBarCompactBodyWidth;
    final menuHeight = ShellTokens.homeTopBarHeightForBodyWidth(bodyWidth);

    return ValueListenableBuilder<double>(
      valueListenable: ShellBus.homeScrollOffset,
      builder: (context, scrollOffset, child) {
        return ValueListenableBuilder<double>(
          valueListenable: ShellBus.homeHeroHeight,
          builder: (context, heroHeight, menu) {
            final topInset = MediaQuery.paddingOf(context).top;
            final barHeight = topInset + menuHeight;
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
          height: menuHeight,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              ShellTokens.bodyHorizontalPadding +
                  (compact ? 0 : ShellTokens.homeTopBarMenuLeadingInset),
              ShellTokens.shellHeaderTopPadding,
              ShellTokens.bodyHorizontalPadding,
              0,
            ),
            child: compact
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: _CompactMenuButton(
                      key: _menuKey,
                      onTap: _openCompactMenu,
                    ),
                  )
                : ValueListenableBuilder<ShellHomeCategory?>(
                    valueListenable: ShellBus.homeCategory,
                    builder: (context, mediaFilter, _) {
                      return ValueListenableBuilder<String?>(
                        valueListenable: ShellBus.homeSelectedGenreId,
                        builder: (context, genreId, _) {
                          final categoriesLabel =
                              homeGenreLabel(genreId) ?? 'Categories';
                          final categoriesActive =
                              _categoriesOpen || genreId != null;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _CategoryTab(
                                label: 'Films',
                                isActive:
                                    mediaFilter == ShellHomeCategory.films,
                                onTap: () => _toggleMediaFilter(
                                  ShellHomeCategory.films,
                                ),
                              ),
                              const SizedBox(width: 36),
                              _CategoryTab(
                                label: 'TV Shows',
                                isActive:
                                    mediaFilter == ShellHomeCategory.tvShows,
                                onTap: () => _toggleMediaFilter(
                                  ShellHomeCategory.tvShows,
                                ),
                              ),
                              const SizedBox(width: 36),
                              _CategoryTab(
                                key: _categoriesKey,
                                label: categoriesLabel,
                                isActive: categoriesActive,
                                showChevron: true,
                                onTap: _openCategoriesMenu,
                              ),
                            ],
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

class _CompactMenuButton extends StatelessWidget {
  const _CompactMenuButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: ShellTokens.shellButtonHeight,
          height: ShellTokens.shellButtonHeight,
          child: Icon(
            Icons.menu_rounded,
            color: cinematic.textPrimary,
            size: 24,
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
