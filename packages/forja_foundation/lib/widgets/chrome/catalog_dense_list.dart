import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forja_foundation/components/skeleton.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/guide/guide_chrome_style.dart';

/// Dense list chrome — host supplies row [itemBuilder] + optional focus wrap.
class CatalogDenseList extends StatelessWidget {
  const CatalogDenseList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.leading,
    this.topPadding = 4,
    this.trailing,
    this.bottomPadding = 0,
    this.separatorColor,
    this.wrapScroll,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ScrollController? controller;
  final double? leading;
  final double topPadding;
  final double? trailing;
  final double bottomPadding;
  final Color? separatorColor;
  final Widget Function(Widget child)? wrapScroll;

  @override
  Widget build(BuildContext context) {
    final external = controller;
    if (external != null) {
      return _buildScrollable(
        context,
        scroll: external,
        itemCount: itemCount,
        itemBuilder: itemBuilder,
        leading: leading,
        topPadding: topPadding,
        trailing: trailing,
        bottomPadding: bottomPadding,
        separatorColor: separatorColor,
        wrapScroll: wrapScroll,
      );
    }
    return _CatalogDenseListOwnedScroll(
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      leading: leading,
      topPadding: topPadding,
      trailing: trailing,
      bottomPadding: bottomPadding,
      separatorColor: separatorColor,
      wrapScroll: wrapScroll,
    );
  }

  static Widget _buildScrollable(
    BuildContext context, {
    required ScrollController scroll,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    double? leading,
    double topPadding = 4,
    double? trailing,
    double bottomPadding = 0,
    Color? separatorColor,
    Widget Function(Widget child)? wrapScroll,
  }) {
    final list = ListView.separated(
      controller: scroll,
      padding: EdgeInsets.fromLTRB(
        leading ?? ShellTokens.compactChromeLeadingInset(context),
        topPadding,
        trailing ?? ShellTokens.bodyHorizontalPadding,
        bottomPadding,
      ),
      itemCount: itemCount,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: (separatorColor ?? ForjaShellColors.borderSubtle)
            .withValues(alpha: 0.6),
      ),
      itemBuilder: itemBuilder,
    );
    final wrap = wrapScroll;
    final child = wrap == null ? list : wrap(list);
    return LiveTvScrollbar(controller: scroll, child: child);
  }
}

/// Owns a [ScrollController] when the host did not pass one (kit paint mounts).
class _CatalogDenseListOwnedScroll extends StatefulWidget {
  const _CatalogDenseListOwnedScroll({
    required this.itemCount,
    required this.itemBuilder,
    required this.leading,
    required this.topPadding,
    required this.trailing,
    required this.bottomPadding,
    required this.separatorColor,
    required this.wrapScroll,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double? leading;
  final double topPadding;
  final double? trailing;
  final double bottomPadding;
  final Color? separatorColor;
  final Widget Function(Widget child)? wrapScroll;

  @override
  State<_CatalogDenseListOwnedScroll> createState() =>
      _CatalogDenseListOwnedScrollState();
}

class _CatalogDenseListOwnedScrollState
    extends State<_CatalogDenseListOwnedScroll> {
  late final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CatalogDenseList._buildScrollable(
      context,
      scroll: _scroll,
      itemCount: widget.itemCount,
      itemBuilder: widget.itemBuilder,
      leading: widget.leading,
      topPadding: widget.topPadding,
      trailing: widget.trailing,
      bottomPadding: widget.bottomPadding,
      separatorColor: widget.separatorColor,
      wrapScroll: widget.wrapScroll,
    );
  }
}

/// Dense schedule row skeleton while catalogs scrape.
class CatalogDenseRowSkeleton extends StatelessWidget {
  const CatalogDenseRowSkeleton({super.key, this.index = 0});

  final int index;

  static const _titleFactors = [0.52, 0.68, 0.44, 0.61, 0.55, 0.74, 0.40, 0.63];
  static const _metaFactors = [0.28, 0.36, 0.22, 0.42, 0.31, 0.25, 0.38, 0.33];

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final titleF = _titleFactors[index % _titleFactors.length];
    final metaF = _metaFactors[index % _metaFactors.length];
    final padH = ShellTokens.chromeScale(12, tv: tv);
    final padV = ShellTokens.chromeScale(10, tv: tv);
    final dot = ShellTokens.chromeScale(8, tv: tv);
    final gap = ShellTokens.chromeScale(10, tv: tv);
    final titleH = ShellTokens.chromeScale(12, tv: tv);
    final metaH = ShellTokens.chromeScale(10, tv: tv);
    final metaGap = ShellTokens.chromeScale(6, tv: tv);
    final trailW = ShellTokens.chromeScale(28, tv: tv);
    final icon = ShellTokens.chromeScale(16, tv: tv);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      child: Row(
        children: [
          Skeleton(
            width: dot,
            height: dot,
            borderRadius: BorderRadius.all(Radius.circular(dot / 2)),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: titleF,
                  alignment: Alignment.centerLeft,
                  child: Skeleton(height: titleH),
                ),
                SizedBox(height: metaGap),
                FractionallySizedBox(
                  widthFactor: metaF,
                  alignment: Alignment.centerLeft,
                  child: Skeleton(height: metaH),
                ),
              ],
            ),
          ),
          SizedBox(width: ShellTokens.chromeScale(8, tv: tv)),
          Skeleton(width: trailW, height: metaH),
          SizedBox(width: ShellTokens.chromeScale(8, tv: tv)),
          Skeleton(
            width: icon,
            height: icon,
            borderRadius: BorderRadius.all(
              Radius.circular(ShellTokens.chromeScale(4, tv: tv)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live schedule dense-list loading skeleton.
class CatalogScheduleDenseSkeleton extends StatelessWidget {
  const CatalogScheduleDenseSkeleton({
    super.key,
    this.leading,
    this.topPadding = 4,
    this.trailing,
    this.bottomPadding = 0,
    this.shimmer,
  });

  final double? leading;
  final double topPadding;
  final double? trailing;
  final double bottomPadding;
  final Widget Function(Widget child)? shimmer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tv = ShellPaintScope.usesTvDensityOf(context);
        final rowExtent = tv
            ? ShellTokens.denseListRowExtentTv
            : ShellTokens.denseListRowExtent;
        final avail = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height * 0.55;
        final count = math.max(4, (avail / rowExtent).floor()).clamp(4, 16);
        final list = ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            leading ?? ShellTokens.compactChromeLeadingInset(context),
            topPadding,
            trailing ?? ShellTokens.bodyHorizontalPadding,
            bottomPadding,
          ),
          itemCount: count,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            color: ForjaShellColors.borderSubtle.withValues(alpha: 0.6),
          ),
          itemBuilder: (context, i) => CatalogDenseRowSkeleton(index: i),
        );
        final wrap = shimmer;
        return wrap == null ? list : wrap(list);
      },
    );
  }
}

/// Empty list / schedule chrome.
class CatalogListEmpty extends StatelessWidget {
  const CatalogListEmpty({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.topPadding = 0,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final iconSize = ShellTokens.chromeScale(40, tv: tv);
    final titleSize = tv
        ? ShellTokens.tvTitleFontSize
        : 16.0;
    final detailSize = tv
        ? ShellTokens.tvBodyFontSize
        : 13.0;
    final gap = ShellTokens.chromeScale(14, tv: tv);
    final detailGap = ShellTokens.chromeScale(6, tv: tv);
    final padH = ShellTokens.chromeScale(32, tv: tv);
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: ForjaShellColors.textSecondary.withValues(alpha: 0.45),
              ),
              SizedBox(height: gap),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: detailGap),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: detailSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
