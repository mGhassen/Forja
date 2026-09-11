import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/widgets/chrome/section_title.dart';

/// Catalog rail section — pagination + lazy gate (Zone A).
///
/// Host injects card / skeleton / scroller / TV row via builders.
/// Lazy activation: call [CatalogSectionState.activateLazy] from a host
/// visibility detector, or set [lazy] false.
class CatalogSection<T> extends StatefulWidget {
  const CatalogSection({
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
    this.onFirstPageLoaded,
    this.reloadToken,
    this.holdEmptyStructure = false,
    this.skeletonBuilder,
    this.titleBuilder,
    this.scrollerBuilder,
    this.wrapRow,
    this.placeholderHeight,
    this.onVisible,
    this.lazyPlaceholder,
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
  final void Function(int itemCount)? onFirstPageLoaded;
  final String? reloadToken;
  final bool holdEmptyStructure;

  final Widget Function(BuildContext context, T item, int index) cardBuilder;
  final Widget Function(BuildContext context)? skeletonBuilder;
  final Widget Function(BuildContext context, String title)? titleBuilder;
  final Widget Function({
    required BuildContext context,
    required List<Widget> children,
    required VoidCallback onApproachingEnd,
  })? scrollerBuilder;
  final Widget Function(Widget child, {required int itemCount})? wrapRow;
  final double? placeholderHeight;
  final VoidCallback? onVisible;

  /// Host visibility gate — when set with [lazy], shown until activated.
  final Widget Function(
    BuildContext context,
    VoidCallback activate,
  )? lazyPlaceholder;

  @override
  State<CatalogSection<T>> createState() => CatalogSectionState<T>();
}

class CatalogSectionState<T> extends State<CatalogSection<T>> {
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
    final fetchPage = widget.fetchPage;
    if (fetchPage != null && !widget.lazy) {
      unawaited(_loadPage(1));
    }
  }

  @override
  void didUpdateWidget(covariant CatalogSection<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken ||
        oldWidget.lazy != widget.lazy ||
        oldWidget.pageSizeHint != widget.pageSizeHint ||
        oldWidget.holdEmptyStructure != widget.holdEmptyStructure) {
      _softReload(keepVisible: widget.lazy && _visibleActivated);
    }
  }

  /// Host visibility detector calls this to start the first page fetch.
  void activateLazy() => _activateFromLazyGate();

  void _activateFromLazyGate() {
    if (widget.fetchPage == null || !widget.lazy) return;
    if (_visibleActivated) {
      widget.onVisible?.call();
      return;
    }
    setState(() => _visibleActivated = true);
    unawaited(_loadPage(1));
    widget.onVisible?.call();
  }

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

  int get _effectivePageSize => _resolvedPageSize ?? widget.pageSizeHint;

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
        _hasMore = result.hasMore ?? (batch.length >= _effectivePageSize);
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

  List<T> get _effectiveItems {
    if (widget.items != null) return widget.items!;
    if (_loaded.isNotEmpty) return _loaded;
    return _last ?? const [];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.future != null) {
      return FutureBuilder<List<T>>(
        future: widget.future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return widget.skeletonBuilder?.call(context) ??
                const SizedBox(height: 160);
          }
          return _buildLoaded(context, snap.data!);
        },
      );
    }

    if (widget.fetchPage != null && widget.lazy && !_visibleActivated) {
      return widget.lazyPlaceholder?.call(context, activateLazy) ??
          SizedBox(
            height: widget.placeholderHeight ?? 200,
            child: widget.skeletonBuilder?.call(context),
          );
    }

    if (widget.fetchPage != null &&
        _loading &&
        _effectiveItems.isEmpty &&
        !widget.holdEmptyStructure) {
      return widget.skeletonBuilder?.call(context) ??
          const SizedBox(height: 160);
    }

    final items = _effectiveItems;
    if (items.isEmpty && widget.holdEmptyStructure) {
      return widget.skeletonBuilder?.call(context) ??
          const SizedBox(height: 160);
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return _buildLoaded(context, items);
  }

  Widget _buildLoaded(BuildContext context, List<T> items) {
    final title = widget.titleBuilder?.call(context, widget.title) ??
        SectionTitle(widget.title);
    final cards = <Widget>[
      for (var i = 0; i < items.length; i++)
        widget.cardBuilder(context, items[i], i),
    ];
    final scroller = widget.scrollerBuilder?.call(
          context: context,
          children: cards,
          onApproachingEnd: _onApproachingEnd,
        ) ??
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: cards),
        );

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) title,
        scroller,
      ],
    );

    final wrap = widget.wrapRow;
    return wrap == null
        ? column
        : wrap(column, itemCount: items.length);
  }
}
