import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forja_foundation/components/skeleton.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
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
    final titleF = _titleFactors[index % _titleFactors.length];
    final metaF = _metaFactors[index % _metaFactors.length];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Skeleton(
            width: 8,
            height: 8,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: titleF,
                  alignment: Alignment.centerLeft,
                  child: const Skeleton(height: 12),
                ),
                const SizedBox(height: 6),
                FractionallySizedBox(
                  widthFactor: metaF,
                  alignment: Alignment.centerLeft,
                  child: const Skeleton(height: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Skeleton(width: 28, height: 10),
          const SizedBox(width: 8),
          const Skeleton(
            width: 16,
            height: 16,
            borderRadius: BorderRadius.all(Radius.circular(4)),
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
        const rowExtent = ShellTokens.denseListRowExtent;
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
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 40,
                color: ForjaShellColors.textSecondary.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
