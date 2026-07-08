import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forja/features/home/home_genre_categories.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/design/src/forja_buttons.dart';
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
  bool _categoriesOpen = false;

  void _toggleMediaFilter(ShellHomeCategory target) {
    final current = ShellBus.homeCategory.value;
    ShellBus.homeCategory.value = current == target ? null : target;
  }

  Future<void> _openCategoriesMenu() async {
    final box = _categoriesKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero, ancestor: overlay);
    final selectedId = ShellBus.homeSelectedGenreId.value;

    setState(() => _categoriesOpen = true);

    final picked = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
          offset.dx,
          offset.dy + box.size.height,
          box.size.width,
          0,
        ),
        Offset.zero & overlay.size,
      ),
      color: const Color(0xFF141414),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: ForjaShellColors.borderSubtle),
      ),
      constraints: const BoxConstraints(minWidth: 180, maxHeight: 360),
      items: [
        PopupMenuItem<String>(
          value: _allGenresSentinel,
          child: Text(
            'All',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: selectedId == null ? FontWeight.w600 : FontWeight.w500,
              color: selectedId == null
                  ? ForjaShellColors.textPrimary
                  : ForjaShellColors.textSecondary,
            ),
          ),
        ),
        for (final genre in homeGenreCategories)
          PopupMenuItem<String>(
            value: genre.id,
            child: Text(
              genre.label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: genre.id == selectedId
                    ? FontWeight.w600
                    : FontWeight.w500,
                color: genre.id == selectedId
                    ? ForjaShellColors.textPrimary
                    : ForjaShellColors.textSecondary,
              ),
            ),
          ),
      ],
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
            padding: const EdgeInsets.fromLTRB(
              ShellTokens.bodyHorizontalPadding,
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

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CategoryTab(
                          label: 'Films',
                          isActive: mediaFilter == ShellHomeCategory.films,
                          onTap: () =>
                              _toggleMediaFilter(ShellHomeCategory.films),
                        ),
                        const SizedBox(width: 36),
                        _CategoryTab(
                          label: 'TV Shows',
                          isActive: mediaFilter == ShellHomeCategory.tvShows,
                          onTap: () =>
                              _toggleMediaFilter(ShellHomeCategory.tvShows),
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
    final color = isActive
        ? ForjaShellColors.textPrimary
        : ForjaShellColors.textSecondary;

    return ForjaInteractive(
      onTap: onTap,
      hoverScale: 1,
      pressScale: 1,
      builder: (_, _) => Column(
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
              color: isActive ? ForjaShellColors.navUnderline : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
