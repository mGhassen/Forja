import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Computed poster / event-card grid metrics for catalog list chrome.
class CatalogPosterGridLayout {
  const CatalogPosterGridLayout({
    required this.columns,
    required this.cardW,
    required this.cardH,
    required this.gap,
    required this.leading,
    required this.rightPad,
    required this.topPad,
  });

  final int columns;
  final double cardW;
  final double cardH;
  final double gap;
  final double leading;
  final double rightPad;
  final double topPad;

  /// Portrait poster grid (My List / plantowatch).
  factory CatalogPosterGridLayout.poster({
    required double maxWidth,
    required double cardW,
    required double cardH,
    required double gap,
    required double leading,
    required double trailing,
    double chromeTop = 0,
  }) {
    final inner = math.max(0.0, maxWidth - leading - trailing);
    final columns = math.max(1, ((inner + gap) / (cardW + gap)).floor());
    final gridW = columns * cardW + (columns - 1) * gap;
    final rightPad = math.max(trailing, maxWidth - leading - gridW);
    final topPad =
        chromeTop +
            cardH * (ForjaMotionTheme.defaults.cardLift.focusScale - 1) / 2 +
            4;
    return CatalogPosterGridLayout(
      columns: columns,
      cardW: cardW,
      cardH: cardH,
      gap: gap,
      leading: leading,
      rightPad: rightPad,
      topPad: topPad,
    );
  }

  /// Match / event cards — scale height with column width.
  factory CatalogPosterGridLayout.eventCards({
    required double maxWidth,
    required double minW,
    required double minH,
    required double gap,
    required double pad,
    double chromeTop = 0,
  }) {
    final inner = math.max(0.0, maxWidth - pad * 2);
    final columns =
        math.max(1, ((inner + gap) / (minW + gap)).floor()).clamp(1, 8);
    final cardW = columns <= 1 ? inner : (inner - (columns - 1) * gap) / columns;
    final cardH = minW > 0 ? minH * (cardW / minW) : minH;
    return CatalogPosterGridLayout(
      columns: columns,
      cardW: cardW,
      cardH: cardH,
      gap: gap,
      leading: pad,
      rightPad: pad,
      topPad: chromeTop + 4,
    );
  }

  /// IPTV live channel tiles — denser column count, cells fill the row.
  ///
  /// Matches pre-wipe `maxWidth ~/ minW` packing (not fixed card width with
  /// leftover right slack).
  factory CatalogPosterGridLayout.channelCards({
    required double maxWidth,
    required double minW,
    required double minH,
    required double gap,
    required double leading,
    required double trailing,
    int minColumns = 2,
    int maxColumns = 9,
    double chromeTop = 0,
  }) {
    final inner = math.max(0.0, maxWidth - leading - trailing);
    final columns = (maxWidth ~/ minW).clamp(minColumns, maxColumns);
    final cardW =
        columns <= 1 ? inner : (inner - (columns - 1) * gap) / columns;
    final cardH = minW > 0 ? minH * (cardW / minW) : minH;
    return CatalogPosterGridLayout(
      columns: columns,
      cardW: cardW,
      cardH: cardH,
      gap: gap,
      leading: leading,
      rightPad: trailing,
      topPad: chromeTop +
          cardH * (ForjaMotionTheme.defaults.cardLift.focusScale - 1) / 2 +
          4,
    );
  }
}

/// Poster / card grid chrome — host supplies [itemBuilder] + optional focus wrap.
class CatalogPosterGrid extends StatelessWidget {
  const CatalogPosterGrid({
    super.key,
    required this.layout,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.bottomPadding = 0,
    this.useAspectRatio = true,
    this.physics = const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    ),
    this.wrapScroll,
  });

  final CatalogPosterGridLayout layout;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ScrollController? controller;
  final double bottomPadding;
  final bool useAspectRatio;
  final ScrollPhysics physics;
  final Widget Function(Widget child)? wrapScroll;

  @override
  Widget build(BuildContext context) {
    final grid = CustomScrollView(
      scrollCacheExtent: ScrollCacheExtent.pixels(720), controller: controller,
      physics: physics,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            layout.leading,
            layout.topPad,
            layout.rightPad,
            bottomPadding,
          ),
          sliver: SliverGrid(
            gridDelegate: useAspectRatio
                ? SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: layout.columns,
                    mainAxisSpacing: layout.gap,
                    crossAxisSpacing: layout.gap,
                    childAspectRatio: layout.cardW / layout.cardH,
                  )
                : SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: layout.columns,
                    mainAxisSpacing: layout.gap,
                    crossAxisSpacing: layout.gap,
                    mainAxisExtent: layout.cardH,
                  ),
            delegate: SliverChildBuilderDelegate(
              itemBuilder,
              childCount: itemCount,
            ),
          ),
        ),
      ],
    );
    final wrap = wrapScroll;
    return wrap == null ? grid : wrap(grid);
  }
}

/// Loading poster grid placeholders.
class CatalogPosterLoadingGrid extends StatelessWidget {
  const CatalogPosterLoadingGrid({
    super.key,
    required this.layout,
    required this.placeholder,
    this.rowCount = 2,
    this.bottomPadding,
    this.shimmer,
  });

  final CatalogPosterGridLayout layout;
  final Widget placeholder;
  final int rowCount;
  final double? bottomPadding;
  final Widget Function(Widget child)? shimmer;

  @override
  Widget build(BuildContext context) {
    final pad = bottomPadding ?? ShellTokens.bodyHorizontalPadding;
    final grid = GridView.builder(
      padding: EdgeInsets.fromLTRB(
        layout.leading,
        layout.topPad,
        layout.rightPad,
        pad,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: layout.columns,
        mainAxisSpacing: layout.gap,
        crossAxisSpacing: layout.gap,
        childAspectRatio: layout.cardW / layout.cardH,
      ),
      itemCount: layout.columns * rowCount,
      itemBuilder: (context, _) => placeholder,
    );
    final wrap = shimmer;
    return wrap == null ? grid : wrap(grid);
  }
}
