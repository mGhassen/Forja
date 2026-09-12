import 'package:flutter/material.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/shell/horizontal_scroller.dart';
import 'package:forja/shared/shell/forja_shell_layout.dart';
import 'package:forja/shared/shell/forja_shell_section_title.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';
import 'package:forja/shared/shell/home_loading_skeleton.dart';
import 'package:forja/shared/shell/kit_poster_card.dart';
import 'package:forja/shared/shell/tv/shell_tv_focus.dart';
import 'package:forja_foundation/widgets/chrome/catalog_section.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:forja/shared/engine/hub/kit_row_prefetch.dart';

export 'package:forja_foundation/widgets/chrome/catalog_section.dart'
    show CatalogSection;

/// Fallback when the hub pack omits [pageSize] / [limit] / [perPage] everywhere.
const int kMetaRailPageSizeHint = kMetaRailPageSizeFallback;

class KitSection<T> extends StatefulWidget {
  const KitSection({
    super.key,
    required this.title,
    required this.cardBuilder,
    this.future,
    this.fetchPage,
    this.items,
    this.lazy = false,
    this.pageSizeHint = kMetaRailPageSizeFallback,
    this.itemKey,
    this.compactTop = false,
    this.embedded = false,
    this.showRank = false,
    this.tvTabId,
    this.tvRowId,
    this.tvRowOrder = 0,
    this.tvFocusUp,
    this.cardAspect = KitPosterAspect.portrait,
    this.prefetchSlot,
    this.onFirstPageLoaded,
    this.reloadToken,
    this.holdEmptyStructure = false,
  }) : assert(
         future != null || items != null || fetchPage != null,
         'Provide future, items, or fetchPage',
       );

  final String title;
  final Future<List<T>>? future;
  final Future<MetaRailPage<T>> Function(int page)? fetchPage;
  final List<T>? items;
  final bool lazy;
  final int pageSizeHint;
  final String Function(T item)? itemKey;
  final bool compactTop;
  final bool embedded;
  final bool showRank;
  final String? tvTabId;
  final String? tvRowId;
  final int tvRowOrder;
  final VoidCallback? tvFocusUp;
  final KitPosterAspect cardAspect;
  final KitRowPrefetchSlot? prefetchSlot;
  final void Function(int itemCount)? onFirstPageLoaded;
  /// When this changes, refetch [fetchPage] but keep the last painted row.
  final String? reloadToken;
  /// Keep section chrome/skeleton when the page loaded empty (upstream down).
  final bool holdEmptyStructure;
  final KitPosterCard Function(BuildContext context, T item, int index)
  cardBuilder;

  static double sectionHeight(
    BuildContext context, {
    bool compactTop = false,
    bool embedded = false,
    KitPosterAspect cardAspect = KitPosterAspect.portrait,
  }) {
    final titleTop = embedded
        ? 0.0
        : shellHomeSectionTitleTop(context, compact: compactTop);
    return titleTop +
        shellHomeSectionHeaderHeight(context) +
        shellHomeSectionBottomGap(context) +
        KitPosterCard.cardHeight(context, aspect: cardAspect);
  }

  @override
  State<KitSection<T>> createState() => _KitSectionState<T>();
}

class _KitSectionState<T> extends State<KitSection<T>> {
  final GlobalKey<CatalogSectionState<T>> _sectionKey =
      GlobalKey<CatalogSectionState<T>>();

  @override
  void initState() {
    super.initState();
    _registerPrefetch();
  }

  @override
  void didUpdateWidget(covariant KitSection<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.prefetchSlot != null) {
      _registerPrefetch();
    }
  }

  void _registerPrefetch() {
    final slot = widget.prefetchSlot;
    if (slot == null) return;
    slot.lane.register(slot.index, _warmFromPrefetch);
  }

  void _warmFromPrefetch() {
    _sectionKey.currentState?.activateLazy();
    widget.prefetchSlot?.notifyVisible();
  }

  double _sectionTitleTop(BuildContext context) {
    if (widget.embedded) return 0;
    if (!widget.compactTop) return shellHomeSectionTitleTop(context);
    return shellSectionTitleTopCompact(context);
  }

  Widget _rowSkeleton(BuildContext context) {
    return homeLoadingShimmer(
      homePosterRowSkeleton(
        context,
        compactTop: widget.compactTop,
        titleWidth: widget.title.length > 12
            ? 180
            : widget.title.length * 11.0,
        cardWidth: KitPosterCard.cardWidth(context, aspect: widget.cardAspect),
        cardHeight:
            KitPosterCard.cardHeight(context, aspect: widget.cardAspect),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPad = widget.embedded
        ? 0.0
        : shellHomeSectionHorizontalPadding(context);
    final sectionTop = _sectionTitleTop(context);

    return CatalogSection<T>(
      key: _sectionKey,
      title: widget.title,
      future: widget.future,
      fetchPage: widget.fetchPage,
      items: widget.items,
      lazy: widget.lazy,
      pageSizeHint: widget.pageSizeHint,
      itemKey: widget.itemKey,
      compactTop: widget.compactTop,
      embedded: widget.embedded,
      onFirstPageLoaded: widget.onFirstPageLoaded,
      reloadToken: widget.reloadToken,
      holdEmptyStructure: widget.holdEmptyStructure,
      placeholderHeight: KitSection.sectionHeight(
        context,
        compactTop: widget.compactTop,
        embedded: widget.embedded,
        cardAspect: widget.cardAspect,
      ),
      onVisible: () => widget.prefetchSlot?.notifyVisible(),
      cardBuilder: (context, item, index) =>
          widget.cardBuilder(context, item, index),
      skeletonBuilder: _rowSkeleton,
      titleBuilder: (context, title) {
        if (title.isEmpty) return const SizedBox.shrink();
        return ShellSectionTitle(
          title: title,
          padding: EdgeInsetsDirectional.only(
            start: horizontalPad,
            top: sectionTop,
            end: horizontalPad,
            bottom: widget.embedded
                ? DetailsTokens.sectionTitleGap
                : shellHomeSectionBottomGap(context),
          ),
        );
      },
      scrollerBuilder: ({
        required context,
        required children,
        required onApproachingEnd,
      }) {
        return FocusTraversalGroup(
          child: HorizontalScroller(
            height: KitPosterCard.cardHeight(
              context,
              aspect: widget.cardAspect,
            ),
            padding: EdgeInsets.symmetric(horizontal: horizontalPad),
            itemCount: children.length,
            onApproachingEnd: widget.fetchPage != null ? onApproachingEnd : null,
            separatorBuilder: (_, _) => SizedBox(
              width: widget.showRank
                  ? shellScaled(context, 6).clamp(3.0, 6.0)
                  : shellPosterCardRowGap(context),
            ),
            itemBuilder: (context, index) => children[index],
          ),
        );
      },
      wrapRow: (child, {required itemCount}) {
        final tabId = widget.tvTabId ?? ShellTvFocus.currentNavTabId;
        final rowId = widget.tvRowId;
        if (tabId == null || rowId == null) return child;
        return TvKitRow(
          tabId: tabId,
          rowId: rowId,
          sortOrder: widget.tvRowOrder,
          itemCount: itemCount,
          onFocusUp: widget.tvFocusUp,
          child: child,
        );
      },
      lazyPlaceholder: (context, activate) {
        return VisibilityDetector(
          key: ValueKey('hub-lazy:${widget.tvRowId ?? widget.title}'),
          onVisibilityChanged: (info) {
            if (info.visibleFraction <= 0) return;
            activate();
          },
          child: SizedBox(
            height: KitSection.sectionHeight(
              context,
              compactTop: widget.compactTop,
              embedded: widget.embedded,
              cardAspect: widget.cardAspect,
            ),
          ),
        );
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

/// Defers [onVisible] until the widget enters the scroll viewport.
class KitLazyViewportGate extends StatefulWidget {
  const KitLazyViewportGate({
    super.key,
    required this.detectorKey,
    required this.placeholderHeight,
    required this.onVisible,
    required this.builder,
    this.prefetchSlot,
  });

  final Key detectorKey;
  final double placeholderHeight;
  final VoidCallback onVisible;
  final Widget Function(bool activated) builder;
  final KitRowPrefetchSlot? prefetchSlot;

  @override
  State<KitLazyViewportGate> createState() => _KitLazyViewportGateState();
}

class _KitLazyViewportGateState extends State<KitLazyViewportGate> {
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    _registerPrefetch();
  }

  @override
  void didUpdateWidget(covariant KitLazyViewportGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.prefetchSlot != null) {
      _registerPrefetch();
    }
  }

  void _registerPrefetch() {
    final slot = widget.prefetchSlot;
    if (slot == null) return;
    slot.lane.register(slot.index, _warmFromPrefetch);
  }

  void _warmFromPrefetch() {
    _activate(prefetch: true);
  }

  void _activate({required bool prefetch}) {
    if (_activated) {
      if (!prefetch) widget.prefetchSlot?.notifyVisible();
      return;
    }
    setState(() => _activated = true);
    widget.onVisible();
    widget.prefetchSlot?.notifyVisible();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_activated || info.visibleFraction <= 0) return;
    _activate(prefetch: false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_activated) {
      return VisibilityDetector(
        key: widget.detectorKey,
        onVisibilityChanged: _onVisibilityChanged,
        child: SizedBox(height: widget.placeholderHeight),
      );
    }
    return widget.builder(true);
  }
}
