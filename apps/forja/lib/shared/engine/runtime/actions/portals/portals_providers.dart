import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/portals/portals_host.dart';
import 'package:forja/shared/engine/portals/store/storage.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';

/// Per-hub open state — each tab has its own bool.
final portalsPanelOpenProvider =
    StateProvider.family<bool, String>((ref, tabId) => false);

/// Vault-backed chip label — safe to watch on hub open (no pack / flutter_js).
final portalsChipSummaryProvider = FutureProvider.autoDispose
    .family<PortalsChipSummary, String>((ref, tabId) async {
  ref.keepAlive();
  return PortalsHost.chipSummary();
});

/// Panel inventory — vault-first; [PortalsInventoryNotifier.prepare] soft-syncs
/// cloud without wiping painted rows (legacy preparePortalPanel contract).
final portalsInventoryProvider = AsyncNotifierProvider.autoDispose
    .family<PortalsInventoryNotifier, PortalsInventory, String>(
  PortalsInventoryNotifier.new,
);

class PortalsInventoryNotifier
    extends AutoDisposeFamilyAsyncNotifier<PortalsInventory, String> {
  @override
  Future<PortalsInventory> build(String tabId) async {
    ref.keepAlive();
    // Soft-pull / admin assign / Deal write PortalStore → notify; refresh vault paint.
    void onStoreRev() {
      unawaited(softReload());
      ref.invalidate(portalsChipSummaryProvider(tabId));
    }

    PortalStore.listRevision.addListener(onStoreRev);
    ref.onDispose(() => PortalStore.listRevision.removeListener(onStoreRev));
    return PortalsHost.listFromVault(preferTabId: tabId);
  }

  /// Soft vault reload — keeps prior [AsyncData] (no Loading flash).
  Future<void> softReload() async {
    final next = await PortalsHost.listFromVault(preferTabId: arg);
    final prev = state.asData?.value;
    if (prev != null &&
        PortalsHost.inventoryFingerprint(prev) ==
            PortalsHost.inventoryFingerprint(next) &&
        prev.actions.length == next.actions.length) {
      return;
    }
    state = AsyncData(next);
  }

  /// Instant selected row — vault [setActiveKey] + softReload catch up after.
  void applyActiveOptimistic(String portalKey) {
    final inv = state.asData?.value;
    if (inv == null) return;
    final key = portalKey.trim();
    if (key.isEmpty) return;
    final portals = <PortalListItem>[
      for (final p in inv.portals)
        PortalListItem(
          id: p.id,
          label: p.label,
          subtitle: p.subtitle,
          selected: PortalsHost.samePortalKey(p.id, key),
          healthy: p.healthy,
          checking: p.checking,
          platformLabel: p.platformLabel,
          expiry: p.expiry,
          activeConnections: p.activeConnections,
          maxConnections: p.maxConnections,
          favorite: p.favorite,
          isNew: p.isNew,
          deleting: p.deleting,
          probeDetail: p.probeDetail,
        ),
    ];
    state = AsyncData(
      PortalsInventory(
        portals: portals,
        activeKey: key,
        pluginId: inv.pluginId,
        title: inv.title,
        actions: inv.actions,
        editForm: inv.editForm,
        formValues: inv.formValues,
        emptyTitle: inv.emptyTitle,
        emptyDescription: inv.emptyDescription,
        searchPlaceholder: inv.searchPlaceholder,
        width: inv.width,
        rowHeight: inv.rowHeight,
        titleFontSize: inv.titleFontSize,
      ),
    );
  }

  /// Instant star flip — vault persist + [softReload] catch up after.
  void applyFavoriteOptimistic(String portalKey, bool favorite) {
    final inv = state.asData?.value;
    if (inv == null) return;
    var changed = false;
    final portals = <PortalListItem>[];
    for (final p in inv.portals) {
      if (!PortalsHost.samePortalKey(p.id, portalKey)) {
        portals.add(p);
        continue;
      }
      changed = true;
      portals.add(
        PortalListItem(
          id: p.id,
          label: p.label,
          subtitle: p.subtitle,
          selected: p.selected,
          healthy: p.healthy,
          checking: p.checking,
          platformLabel: p.platformLabel,
          expiry: p.expiry,
          activeConnections: p.activeConnections,
          maxConnections: p.maxConnections,
          favorite: favorite,
          isNew: p.isNew,
          deleting: p.deleting,
          probeDetail: p.probeDetail,
        ),
      );
    }
    if (!changed) return;
    state = AsyncData(
      PortalsInventory(
        portals: portals,
        activeKey: inv.activeKey,
        pluginId: inv.pluginId,
        title: inv.title,
        actions: inv.actions,
        editForm: inv.editForm,
        formValues: inv.formValues,
        emptyTitle: inv.emptyTitle,
        emptyDescription: inv.emptyDescription,
        searchPlaceholder: inv.searchPlaceholder,
        width: inv.width,
        rowHeight: inv.rowHeight,
        titleFontSize: inv.titleFontSize,
      ),
    );
  }

  /// Panel open: paint vault (already in [build]), pull cloud, soft merge.
  /// Optionally enrich pack chrome once in the background.
  Future<void> prepare() async {
    final before = state.asData?.value;
    if (before == null) {
      state = AsyncData(
        await PortalsHost.listFromVault(preferTabId: arg),
      );
    }
    await PortalsHost.preparePortalPanel();
    await softReload();
    final painted = state.asData?.value;
    if (painted == null || painted.actions.isEmpty) {
      unawaited(_enrichChromeFromPack());
    }
  }

  Future<void> _enrichChromeFromPack() async {
    try {
      final packed = await PortalsHost.list(preferTabId: arg);
      state = AsyncData(packed);
    } catch (_) {}
  }
}

/// Soft refresh after mutations — chip vault reload + inventory soft merge.
/// Does **not** blank the open panel.
void invalidatePortalsChrome(WidgetRef ref, String tabId) {
  final key = tabId.trim();
  ref.invalidate(portalsChipSummaryProvider(key));
  unawaited(ref.read(portalsInventoryProvider(key).notifier).softReload());
}

void preparePortalsPanel(ProviderContainer container, String tabId) {
  final key = tabId.trim();
  if (key.isEmpty) return;
  unawaited(container.read(portalsInventoryProvider(key).notifier).prepare());
}
