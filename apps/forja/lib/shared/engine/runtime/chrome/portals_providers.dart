import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/portals/portals_host.dart';

/// Per-hub open state — each tab has its own bool.
final portalsPanelOpenProvider =
    StateProvider.family<bool, String>((ref, tabId) => false);

/// Vault-backed chip label — safe to watch on hub open (no pack / flutter_js).
final portalsChipSummaryProvider = FutureProvider.autoDispose
    .family<PortalsChipSummary, String>((ref, tabId) async {
  ref.keepAlive();
  return PortalsHost.chipSummary();
});

/// Inventory for the open panel — watch only when the panel is open.
final portalsInventoryProvider = FutureProvider.autoDispose
    .family<PortalsInventory, String>((ref, tabId) async {
  ref.keepAlive();
  return PortalsHost.list(preferTabId: tabId);
});

void invalidatePortalsChrome(WidgetRef ref, String tabId) {
  final key = tabId.trim();
  ref.invalidate(portalsChipSummaryProvider(key));
  ref.invalidate(portalsInventoryProvider(key));
}
