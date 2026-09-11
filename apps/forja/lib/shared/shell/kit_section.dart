import 'dart:async';

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
import 'package:visibility_detector/visibility_detector.dart';

import 'package:forja/shared/engine/hub/kit_row_prefetch.dart';

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
  List<T>? _last;
  List<T> _loaded = const [];
  int _page = 0;
  bool _visibleActivated = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _loadGen = 0;
  int? _resolvedPageSize;

  @override
  void initState() {
    super.initState();
    _registerPrefetch();
    final fetchPage = widget.fetchPage;
    if (fetchPage != null && !widget.lazy) {
      unawaited(_loadPage(1));
    }
  }

  @override
  void didUpdateWidget(covariant KitSection<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.prefetchSlot != null) {
      _registerPrefetch();
    }
    if (oldWidget.reloadToken != widget.reloadToken ||
        oldWidget.lazy != widget.lazy ||
        oldWidget.pageSizeHint != widget.pageSizeHint ||
        oldWidget.holdEmptyStructure != widget.holdEmptyStructure) {
      _softReload(keepVisible: widget.lazy && _visibleActivated);
    }
  }

  void _registerPrefetch() {
    final slot = widget.prefetchSlot;
    if (slot == null) return;
    slot.lane.register(slot.index, _warmFromPrefetch);
  }

  void _warmFromPrefetch() {
    _activateFromLazyGate(prefetch: true);
  }

  void _activateFromLazyGate({required bool prefetch}) {
    if (widget.fetchPage == null || !widget.lazy) return;
    if (_visibleActivated) {
      if (!prefetch) widget.prefetchSlot?.notifyVisible();
      return;
    }
    setState(() => _visibleActivated = true);
    unawaited(_loadPage(1));
    widget.prefetchSlot?.notifyVisible();
  }

  /// Refetch while keeping the last painted row (chrome filter / Films / Series).
  void _softReload({required bool keepVisible}) {
    _loadGen++;
    _loadingMore = false;
    _hasMore = true;
    if (!keepVisible) _visibleActivated = false;
    final fetchPage = widget.fetchPage;
    if (fetchPage != null && (!widget.lazy || _visibleActivated)) {
      unawaited(_loadPage(1));
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (widget.fetchPage == null || !widget.lazy || _visibleActivated) return;
    if (info.visibleFraction <= 0) return;
    _activateFromLazyGate(prefetch: false);
  }

  List<T> _mergeItems(List<T> current, List<T> batch) {
    final keyFn = widget.itemKey;
    if (keyFn == null) return [...current, ...batch];
    final seen = {for (final i in current) keyFn(i)};
    final out = [...current];
    for (final i in batch) {
      if (seen.add(keyFn(i))) out.add(i);
    }
    return out;
  }

  int get _effectivePageSize =>
      _resolvedPageSize ?? widget.pageSizeHint;

  Future<void> _loadPage(int page, {bool append = false}) async {
    final fetchPage = widget.fetchPage;
    if (fetchPage == null) return;
    if (append) {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() => _loading = true);
    }

    final gen = _loadGen;
    try {
      final result = await fetchPage(page);
      final batch = result.items;
      if (result.pageSize != null && result.pageSize! > 0) {
        _resolvedPageSize = result.pageSize;
      }
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _loaded = append ? _mergeItems(_loaded, batch) : batch;
        _page = page;
        _loading = false;
        _loadingMore = false;
        _hasMore = result.hasMore ??
            (batch.length >= _effectivePageSize);
        _last = _loaded;
      });
      if (!append) widget.onFirstPageLoaded?.call(_loaded.length);
    } catch (_) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (!append) _hasMore = false;
      });
      if (!append) widget.onFirstPageLoaded?.call(0);
    }
  }

  void _onApproachingEnd() {
    if (widget.fetchPage == null || !_hasMore || _loading || _loadingMore) {
      return;
    }
    unawaited(_loadPage(_page + 1, append: true));
  }

  double _sectionTitleTop(BuildContext context) {
    if (widget.embedded) return 0;
    if (!widget.compactTop) return shellHomeSectionTitleTop(context);
    return shellSectionTitleTopCompact(context);
  }

  Widget _rowSkeleton(BuildContext context) {
    return homeLoadingShimmer(
      homeMovieRowSkeleton(
        context,
        compactTop: widget.compactTop,
        titleWidth: widget.title.length > 12
            ? 180
            : widget.title.length * 11.0,
        cardWidth: KitPosterCard.cardWidth(context, aspect: widget.cardAspect),
        cardHeight: KitPosterCard.cardHeight(context, aspect: widget.cardAspect),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return SizedBox(
      height: KitSection.sectionHeight(
        context,
        compactTop: widget.compactTop,
        embedded: widget.embedded,
        cardAspect: widget.cardAspect,
      ),
    );
  }

  Widget _buildRow(BuildContext context, List<T> list) {
    if (list.isEmpty) return const SizedBox.shrink();

    final sectionTop = _sectionTitleTop(context);
    final horizontalPad = widget.embedded
        ? 0.0
        : shellHomeSectionHorizontalPadding(context);
    final paginate = widget.fetchPage != null && _hasMore;

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.title.isNotEmpty)
          ShellSectionTitle(
            title: widget.title,
            padding: EdgeInsetsDirectional.only(
              start: horizontalPad,
              top: sectionTop,
              end: horizontalPad,
              bottom: widget.embedded
                  ? DetailsTokens.sectionTitleGap
                  : shellHomeSectionBottomGap(context),
            ),
          ),
        FocusTraversalGroup(
          child: HorizontalScroller(
            height: KitPosterCard.cardHeight(context, aspect: widget.cardAspect),
            padding: EdgeInsets.symmetric(horizontal: horizontalPad),
            itemCount: list.length,
            onApproachingEnd: paginate ? _onApproachingEnd : null,
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

    return TvKitRow(
      tabId: tabId,
      rowId: rowId,
      sortOrder: widget.tvRowOrder,
      itemCount: list.length,
      onFocusUp: widget.tvFocusUp,
      child: column,
    );
  }

  Widget _wrapLazyGate(BuildContext context, Widget child) {
    if (widget.fetchPage == null || !widget.lazy) return child;
    return VisibilityDetector(
      key: ValueKey('hub-lazy:${widget.tvRowId ?? widget.title}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: child,
    );
  }

  Widget _buildPaged(BuildContext context) {
    if (widget.lazy && !_visibleActivated) {
      return _wrapLazyGate(context, _placeholder(context));
    }

    final list = _loaded;
    if (list.isNotEmpty) {
      return _wrapLazyGate(context, _buildRow(context, list));
    }
    if (_loading || widget.holdEmptyStructure) {
      return _wrapLazyGate(context, _rowSkeleton(context));
    }
    return _wrapLazyGate(context, const SizedBox.shrink());
  }

  @override
  Widget build(BuildContext context) {
    final staticItems = widget.items;
    if (staticItems != null) {
      return _buildRow(context, staticItems);
    }

    final fetchPage = widget.fetchPage;
    if (fetchPage != null) {
      return _buildPaged(context);
    }

    return FutureBuilder<List<T>>(
      future: widget.future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _last = snapshot.data;
        }
        final list = snapshot.data ?? _last ?? <T>[];
        final loading = snapshot.connectionState == ConnectionState.waiting;

        if (list.isNotEmpty) return _buildRow(context, list);

        if (loading || !snapshot.hasData || widget.holdEmptyStructure) {
          return _rowSkeleton(context);
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
