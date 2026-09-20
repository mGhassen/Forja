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

  /// When true, land scrolls + arms D-pad memory but leaves focus on cats.
  /// False after player / Fav hold-jump (focus the channel tile).
  static bool preferCategoryFocusOnLand = true;

  static String? _activePortalKey;

  static void setVisibleStreamIds(Iterable<String> ids) {
    _visibleStreamIds = {
      for (final raw in ids)
        if (raw.trim().isNotEmpty) raw.trim(),
    };
  }

  static bool streamVisibleInFilter(String streamId) {
    final id = streamId.trim();
    if (id.isEmpty) return false;
    return _visibleStreamIds.contains(id);
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

  /// After feed / portal ready: highlight last channel and focus it.
  static Future<void> hydrateHighlightFromStore() async {
    final ch = await loadLastChannel();
    if (ch == null || ch.isEmpty) return;
    preferCategoryFocusOnLand = false;
    highlightedStreamId.value = ch;
    landEpoch.value++;
    _armResetPreferCategoryFocus();
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
    ShellTvFocusCoordinator.setRowLastFocusedIndex(tab, itemsRowId, index);
    return true;
  }

  /// TV: focus channel tile at exact index (retry until lazy grid mounts).
  static bool focusItemsAt(int index) {
    if (index < 0) return false;
    final tab = ShellTvFocus.currentNavTabId ?? 'iptv';
    ShellTvFocusCoordinator.setRowLastFocusedIndex(tab, itemsRowId, index);
    return ShellTvFocusCoordinator.focusRowItemExact(tab, itemsRowId, index);
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
      // Grid scrolls via landEpoch; focus is exact once index is known there.
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
