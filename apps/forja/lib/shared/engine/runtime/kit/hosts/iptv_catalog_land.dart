import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/store/storage.dart';
import 'package:forja/shared/engine/runtime/shell/shell_bus.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';

/// IPTV Live catalog land / restore (v1.5.36 ISO).
///
/// Pack layout owns paint; this host owns last category/channel SoT + post-player
/// focus/scroll. Layout row ids: chrome · cats · items.
abstract final class IptvCatalogLand {
  IptvCatalogLand._();

  /// Layout list widget id / TV row for the Live channel grid.
  static const itemsRowId = 'items';

  /// Layout category rail id / TV row.
  static const catsRowId = 'cats';

  /// Last-played / restored channel highlight (id only — no autoplay).
  static final ValueNotifier<String?> highlightedStreamId =
      ValueNotifier<String?>(null);

  /// Pending restore after player when catalog was ExcludeFocus / remounting.
  static final ValueNotifier<IptvCatalogRestoreRequest?> pendingRestore =
      ValueNotifier<IptvCatalogRestoreRequest?>(null);

  /// Epoch bumped when land should scroll/focus (grid listens).
  static final ValueNotifier<int> landEpoch = ValueNotifier<int>(0);

  /// Stream ids currently painted in the Live channel grid (after kind filter).
  static Set<String> _visibleStreamIds = const {};

  /// Same ids in paint order — index lookup for category →.
  static List<String> _visibleStreamIdsOrdered = const [];

  /// Last channel the user focused / armed in the current grid (D-pad or land).
  static String? _lastFocusedStreamId;

  /// When true, land scrolls + arms D-pad memory but leaves focus on cats.
  /// False after player / Fav hold-jump (focus the channel tile).
  static bool preferCategoryFocusOnLand = true;

  static String? _activePortalKey;

  static void setVisibleStreamIds(Iterable<String> ids) {
    _visibleStreamIdsOrdered = [
      for (final raw in ids)
        if (raw.trim().isNotEmpty) raw.trim(),
    ];
    _visibleStreamIds = _visibleStreamIdsOrdered.toSet();
  }

  static bool streamVisibleInFilter(String streamId) {
    final id = streamId.trim();
    if (id.isEmpty) return false;
    return _visibleStreamIds.contains(id);
  }

  static int? indexOfVisibleStream(String streamId) {
    final id = streamId.trim();
    if (id.isEmpty) return null;
    final i = _visibleStreamIdsOrdered.indexOf(id);
    return i >= 0 ? i : null;
  }

  /// Remember which stream the items row last focused / armed (by paint index).
  static void noteFocusedStreamAt(int index) {
    if (index < 0 || index >= _visibleStreamIdsOrdered.length) return;
    _lastFocusedStreamId = _visibleStreamIdsOrdered[index];
  }

  static void noteFocusedStreamId(String streamId) {
    final id = streamId.trim();
    if (id.isEmpty) return;
    _lastFocusedStreamId = id;
  }

  static void bindPortalKey(String? portalStoreKey) {
    final k = (portalStoreKey ?? '').trim();
    _activePortalKey = k.isEmpty ? null : k;
  }

  static String? get activePortalKey => _activePortalKey;

  static Future<void> rememberCategory(String categoryId) async {
    final key = _activePortalKey;
    final id = categoryId.trim();
    if (key == null || id.isEmpty || PortalLiveCatalog.isSyntheticId(id)) {
      return;
    }
    await PortalLiveChannelListsStore.saveLastCategory(key, id);
  }

  static Future<void> rememberChannel(String streamId) async {
    final key = _activePortalKey;
    final id = streamId.trim();
    if (key == null || id.isEmpty) return;
    _lastFocusedStreamId = id;
    if (highlightedStreamId.value != id) {
      highlightedStreamId.value = id;
    }
    await PortalLiveChannelListsStore.saveLastChannel(key, id);
  }

  static Future<String?> loadLastCategory() async {
    final key = _activePortalKey;
    if (key == null) return null;
    return PortalLiveChannelListsStore.loadLastCategory(key);
  }

  static Future<String?> loadLastChannel() async {
    final key = _activePortalKey;
    if (key == null) return null;
    return PortalLiveChannelListsStore.loadLastChannel(key);
  }

  /// After feed / portal ready: highlight + scroll last channel; leave focus on
  /// cats (nav enter lands the selected category). Player restore still focuses.
  static Future<void> hydrateHighlightFromStore() async {
    final ch = await loadLastChannel();
    if (ch == null || ch.isEmpty) return;
    preferCategoryFocusOnLand = true;
    _lastFocusedStreamId = ch;
    highlightedStreamId.value = ch;
    landEpoch.value++;
  }

  /// Arm restore before/while player is up; consume on catalog land.
  static void armPostPlayerRestore({
    required String streamId,
    String? categoryId,
  }) {
    final sid = streamId.trim();
    if (sid.isEmpty) return;
    highlightedStreamId.value = sid;
    pendingRestore.value = IptvCatalogRestoreRequest(
      streamId: sid,
      categoryId: (categoryId ?? '').trim(),
    );
  }

  static IptvCatalogRestoreRequest? takePendingRestore() {
    final p = pendingRestore.value;
    pendingRestore.value = null;
    return p;
  }

  /// After [PtPlayerScreen] pops: select category if needed, scroll + focus.
  static void restoreAfterPlayback({
    required String streamId,
    String? categoryId,
    required void Function(String categoryId) selectCategory,
    required bool Function(String streamId) streamVisibleInFilter,
    required String? selectedCategoryId,
  }) {
    final sid = streamId.trim();
    if (sid.isEmpty) return;
    highlightedStreamId.value = sid;
    unawaited(rememberChannel(sid));

    final cat = (categoryId ?? '').trim();
    final visible = streamVisibleInFilter(sid);
    if (!visible && cat.isNotEmpty && !PortalLiveCatalog.isSyntheticId(cat)) {
      if (selectedCategoryId != cat) {
        selectCategory(cat);
      }
    }

    preferCategoryFocusOnLand = false;
    landEpoch.value++;
    _scheduleFocusChannel(sid);
  }

  static void requestLandScroll() {
    preferCategoryFocusOnLand = false;
    landEpoch.value++;
    _armResetPreferCategoryFocus();
  }

  /// TV: arm D-pad memory on [itemsRowId] without stealing category focus.
  static bool armItemsFocusMemory(int index) {
    if (index < 0) return false;
    final tab = ShellTvFocus.currentNavTabId ?? 'iptv';
    final handle = ShellTvFocusCoordinator.rowHandle(tab, itemsRowId);
    if (handle == null || handle.itemCount <= index) return false;
    noteFocusedStreamAt(index);
    ShellTvFocusCoordinator.setRowLastFocusedIndex(tab, itemsRowId, index);
    return true;
  }

  /// TV: focus channel tile at exact index (retry until lazy grid mounts).
  static bool focusItemsAt(int index) {
    if (index < 0) return false;
    final tab = ShellTvFocus.currentNavTabId ?? 'iptv';
    noteFocusedStreamAt(index);
    ShellTvFocusCoordinator.setRowLastFocusedIndex(tab, itemsRowId, index);
    return ShellTvFocusCoordinator.focusRowItemExact(tab, itemsRowId, index);
  }

  /// Category → : last selected channel if still in this list, else first.
  ///
  /// Prefers last D-pad/land focus, then [highlightedStreamId] (last played).
  /// Never uses spatial "in front of category" geometry.
  static bool focusItemsFromCategory({String? tabId}) {
    final tab = (tabId ?? '').trim().isNotEmpty
        ? tabId!.trim()
        : (ShellTvFocus.currentNavTabId ?? 'iptv');
    final candidates = <String>[
      if ((_lastFocusedStreamId ?? '').trim().isNotEmpty)
        _lastFocusedStreamId!.trim(),
      if ((highlightedStreamId.value ?? '').trim().isNotEmpty)
        highlightedStreamId.value!.trim(),
    ];
    for (final sid in candidates) {
      final idx = indexOfVisibleStream(sid);
      if (idx == null) continue;
      if (focusItemsAt(idx)) return true;
      // Lazy grid may not have the node yet — arm memory + soft focus.
      ShellTvFocusCoordinator.setRowLastFocusedIndex(tab, itemsRowId, idx);
      if (ShellTvFocusCoordinator.focusRowItem(tab, itemsRowId, idx)) {
        return true;
      }
    }
    if (_visibleStreamIdsOrdered.isEmpty) return false;
    noteFocusedStreamAt(0);
    ShellTvFocusCoordinator.setRowLastFocusedIndex(tab, itemsRowId, 0);
    return ShellTvFocusCoordinator.focusRowItem(tab, itemsRowId, 0) ||
        ShellTvFocusCoordinator.focusRowItemExact(tab, itemsRowId, 0);
  }

  static void _scheduleFocusChannel(String streamId) {
    var tries = 0;
    void attempt() {
      if (ShellBus.shellOverlayHasPage.value ||
          ShellBus.playerSurfaceActive.value) {
        if (tries++ < 24) {
          WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        }
        return;
      }
      // Grid scrolls + focuses via landEpoch; preferCategoryFocusNow reads live.
      preferCategoryFocusOnLand = false;
      landEpoch.value++;
      _armResetPreferCategoryFocus();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  static int? _preferCategoryResetEpoch;

  static void _armResetPreferCategoryFocus() {
    // Tie reset to this land epoch so a slow focus attempt cannot lose to an
    // early flip back to preferCategoryFocusOnLand=true.
    final epoch = landEpoch.value;
    _preferCategoryResetEpoch = epoch;
    var frames = 0;
    void tick() {
      if (_preferCategoryResetEpoch != epoch) return;
      if (frames++ < 24) {
        WidgetsBinding.instance.addPostFrameCallback((_) => tick());
        return;
      }
      if (_preferCategoryResetEpoch != epoch) return;
      preferCategoryFocusOnLand = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => tick());
  }
}

class IptvCatalogRestoreRequest {
  const IptvCatalogRestoreRequest({
    required this.streamId,
    required this.categoryId,
  });

  final String streamId;
  final String categoryId;
}
