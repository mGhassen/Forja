import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/row_prefetch.dart';
import 'package:forja_foundation/protocol/protocol.dart';

/// Host chrome state for one pack layout tab (search query, refresh, view, dynamic bars).
///
/// Selections for menus/tabs stay on [LayoutScope]; this holds feed-affecting extras
/// and dynamic category bar items derived from the last feed.
class PackChromeScope extends InheritedWidget {
  const PackChromeScope({
    super.key,
    required this.eventQuery,
    required this.refreshEpoch,
    this.refreshForceNetwork = true,
    this.refreshKeepPainted = false,
    this.catalogHoldEpoch = 0,
    required this.viewStyle,
    required this.dynamicBarItems,
    required this.selectedListItem,
    required this.shellTabVisible,
    required this.eagerLoadKeys,
    required this.pageFeedRailIds,
    required this.pageFeedFuture,
    this.pageFeedRails,
    this.pageFeedError,
    required this.rowPrefetch,
    required this.searchHitKindIds,
    required this.onEventQuery,
    required this.onBumpRefresh,
    required this.onClearCatalog,
    required this.onViewStyle,
    required this.onDynamicBarItems,
    required this.onSelectListItem,
    required super.child,
  });

  final String eventQuery;
  final int refreshEpoch;

  /// Last [onBumpRefresh] asked to skip pack disk cache (`force` / network).
  /// Portal switch sets false so IPTV can hit `iptv.catalog` disk cache.
  final bool refreshForceNetwork;

  /// Soft list refresh (My List pin) — rebind feed but keep last painted grid.
  final bool refreshKeepPainted;

  /// Bumped by [onClearCatalog] — drop painted grid / kinds and hold fetch
  /// until the next [refreshEpoch] bump (portal select while selectPortal runs).
  final int catalogHoldEpoch;
  final String viewStyle;
  final Map<String, List<Map<String, dynamic>>> dynamicBarItems;

  /// List/panel selection — [ValueNotifier] so taps do not InheritedWidget-notify
  /// the whole hub (grids, rails, PackLoadedPaint).
  final ValueNotifier<Map<String, dynamic>?> selectedListItem;

  /// Kind ids with hits for the active [eventQuery] (legacy IPTV sidebar filter).
  final ValueNotifier<Set<String>> searchHitKindIds;

  /// Whether this hub tab is the selected shell tab (KeepAlive may stay mounted).
  final bool shellTabVisible;

  /// Section ids / rail ids that should load immediately (above Continue + bleed).
  final Set<String> eagerLoadKeys;

  /// Rail ids claimed by page `feed` — [PackLoadedPaint] shares [pageFeedFuture].
  final Set<String> pageFeedRailIds;

  /// One page-level `feed` future → `rails` map. Null when page is not feed-batched.
  final Future<Map<String, List<dynamic>>>? pageFeedFuture;

  /// Sync snapshot of the last completed page `feed` rails (EngineCache peek or
  /// settled future). PackLoadedPaint paints from this without waiting on a
  /// microtask — `Future.value` alone still flashes section skeletons.
  final Map<String, List<dynamic>>? pageFeedRails;

  /// Last page `feed` failure. When set, feed-claimed rails paint this error
  /// instead of treating an empty rails map as success.
  final MetaError? pageFeedError;

  /// Vertical row warm lane — visible row activates [ahead] rows below.
  final KitRowPrefetchLane rowPrefetch;

  final void Function(String query) onEventQuery;

  /// [forceNetwork] true = Refresh / shelf reload (skip pack disk cache).
  /// false = portal switch (EngineCache wipe only; pack may disk-hit).
  /// Does not clear [selectedListItem] — docked resolve panels stay open.
  final void Function({bool forceNetwork}) onBumpRefresh;

  /// Immediate empty + loading — no fetch until [onBumpRefresh].
  /// Clears [selectedListItem] (portal wipe).
  final VoidCallback onClearCatalog;
  final void Function(String style) onViewStyle;
  final void Function(String barId, List<Map<String, dynamic>> items)
      onDynamicBarItems;
  final void Function(Map<String, dynamic>? item) onSelectListItem;

  static PackChromeScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PackChromeScope>();
  }

  static PackChromeScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'PackChromeScope not found');
    return scope!;
  }

  List<Map<String, dynamic>>? barItems(String barId) {
    final id = barId.trim();
    if (id.isEmpty) return null;
    return dynamicBarItems[id];
  }

  bool isEagerLoad(String? id, {String? rail}) {
    final a = (id ?? '').trim();
    final b = (rail ?? '').trim();
    if (a.isNotEmpty && eagerLoadKeys.contains(a)) return true;
    if (b.isNotEmpty && eagerLoadKeys.contains(b)) return true;
    return false;
  }

  bool isPageFeedRail(String? rail) {
    final id = (rail ?? '').trim();
    return id.isNotEmpty && pageFeedRailIds.contains(id);
  }

  @override
  bool updateShouldNotify(PackChromeScope oldWidget) {
    // Do not compare selectedListItem.value — list taps update the notifier only.
    return eventQuery != oldWidget.eventQuery ||
        refreshEpoch != oldWidget.refreshEpoch ||
        refreshForceNetwork != oldWidget.refreshForceNetwork ||
        refreshKeepPainted != oldWidget.refreshKeepPainted ||
        catalogHoldEpoch != oldWidget.catalogHoldEpoch ||
        viewStyle != oldWidget.viewStyle ||
        !identical(selectedListItem, oldWidget.selectedListItem) ||
        !identical(searchHitKindIds, oldWidget.searchHitKindIds) ||
        // Hide must notify — PackLoadedPaint / LazyViewportGate gate on this.
        // Hide path cancels binds (no skeleton); show path does not auto-_bind
        // unless refreshEpoch / filters also change.
        shellTabVisible != oldWidget.shellTabVisible ||
        !setEquals(eagerLoadKeys, oldWidget.eagerLoadKeys) ||
        !setEquals(pageFeedRailIds, oldWidget.pageFeedRailIds) ||
        !identical(pageFeedFuture, oldWidget.pageFeedFuture) ||
        !identical(pageFeedRails, oldWidget.pageFeedRails) ||
        pageFeedError != oldWidget.pageFeedError ||
        !identical(rowPrefetch, oldWidget.rowPrefetch) ||
        !mapEquals(dynamicBarItems, oldWidget.dynamicBarItems);
  }
}
