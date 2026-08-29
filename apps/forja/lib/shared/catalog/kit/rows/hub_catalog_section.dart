import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/shared/widgets/hub/hub_poster_card.dart';
import 'package:forja/shared/widgets/horizontal_scroller.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';

class HubCatalogSection<T> extends StatefulWidget {
  const HubCatalogSection({
    super.key,
    required this.title,
    required this.cardBuilder,
    this.future,
    this.items,
    this.compactTop = false,
    this.embedded = false,
    this.showRank = false,
    this.tvTabId,
    this.tvRowId,
    this.tvRowOrder = 0,
    this.tvFocusUp,
    this.cardAspect = HubPosterAspect.portrait,
  }) : assert(future != null || items != null);

  final String title;
  final Future<List<T>>? future;
  final List<T>? items;
  final bool compactTop;

  /// Zero title-top pad - parent owns row gap (media details sections).
  final bool embedded;
  final bool showRank;
  final String? tvTabId;
  final String? tvRowId;
  final int tvRowOrder;
  final VoidCallback? tvFocusUp;
  final HubPosterAspect cardAspect;
  final HubPosterCard Function(BuildContext context, T item, int index)
  cardBuilder;

  static double sectionHeight(
    BuildContext context, {
    bool compactTop = false,
    bool embedded = false,
    HubPosterAspect cardAspect = HubPosterAspect.portrait,
  }) {
    final titleTop = embedded
        ? 0.0
        : shellHomeSectionTitleTop(context, compact: compactTop);
    return titleTop +
        shellHomeSectionHeaderHeight(context) +
        shellHomeSectionBottomGap(context) +
        HubPosterCard.cardHeight(context, aspect: cardAspect);
  }

  @override
  State<HubCatalogSection<T>> createState() => _HubCatalogSectionState<T>();
}

class _HubCatalogSectionState<T> extends State<HubCatalogSection<T>> {
  List<T>? _last;

  double _sectionTitleTop(BuildContext context) {
    if (widget.embedded) return 0;
    if (!widget.compactTop) return shellHomeSectionTitleTop(context);
    return shellSectionTitleTopCompact(context);
  }

  Widget _buildRow(BuildContext context, List<T> list) {
    if (list.isEmpty) return const SizedBox.shrink();

    final sectionTop = _sectionTitleTop(context);
    final horizontalPad = widget.embedded
        ? 0.0
        : shellHomeSectionHorizontalPadding(context);

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShellSectionTitle(
          title: widget.title,
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            sectionTop,
            horizontalPad,
            widget.embedded
                ? DetailsTokens.sectionTitleGap
                : shellHomeSectionBottomGap(context),
          ),
        ),
        FocusTraversalGroup(
          child: HorizontalScroller(
            height: HubPosterCard.cardHeight(context, aspect: widget.cardAspect),
            padding: EdgeInsets.symmetric(horizontal: horizontalPad),
            itemCount: list.length,
            separatorBuilder: (_, _) => SizedBox(
              width: widget.showRank
                  ? shellScaled(context, 6).clamp(3.0, 6.0)
                  : shellMovieCardRowGap(context),
            ),
            itemBuilder: (context, index) =>
                widget.cardBuilder(context, list[index], index),
          ),
        ),
      ],
    );

    final tabId = widget.tvTabId ?? ShellTvFocus.currentNavTabId;
    final rowId = widget.tvRowId;
    if (tabId == null || rowId == null) return column;

    return TvCatalogRow(
      tabId: tabId,
      rowId: rowId,
      sortOrder: widget.tvRowOrder,
      itemCount: list.length,
      onFocusUp: widget.tvFocusUp,
      child: column,
    );
  }

  @override
  Widget build(BuildContext context) {
    final staticItems = widget.items;
    if (staticItems != null) {
      return _buildRow(context, staticItems);
    }

    return FutureBuilder<List<T>>(
      future: widget.future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _last = snapshot.data;
        }
        final list = snapshot.data ?? _last ?? <T>[];
        final loading = snapshot.connectionState == ConnectionState.waiting;

        // Keep last painted row while a new future resolves — no shimmer flash.
        if (list.isNotEmpty) return _buildRow(context, list);

        if (loading || !snapshot.hasData) {
          return homeLoadingShimmer(
            homeMovieRowSkeleton(
              context,
              compactTop: widget.compactTop,
              titleWidth: widget.title.length > 12
                  ? 180
                  : widget.title.length * 11.0,
              cardWidth:
                  HubPosterCard.cardWidth(context, aspect: widget.cardAspect),
              cardHeight:
                  HubPosterCard.cardHeight(context, aspect: widget.cardAspect),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

SliverToBoxAdapter hubRowSliver(
  BuildContext context,
  Widget section, {
  required bool isFirstAfterHero,
}) {
  return SliverToBoxAdapter(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isFirstAfterHero) SizedBox(height: shellHomeRowSpacing(context)),
        RepaintBoundary(child: section),
      ],
    ),
  );
}
