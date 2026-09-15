import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/runtime/meta/plugin_actions.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shared/engine/runtime/open/live_surface_open.dart';
import 'package:forja/shared/sync/api/sync_service.dart';
import 'package:forja/shared/sync/models/account_features.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';
import 'package:forja_foundation/widgets/chrome/portals_chip.dart';
import 'package:forja_foundation/widgets/chrome/side_panel_overlay.dart';

/// Generic portals inventory — pack owns when/how to paint the chip.
///
/// Host runs pack actions + paints foundation [PortalsChip]. No pack-id allowlist.
abstract final class PortalsActionHost {
  PortalsActionHost._();

  /// Opaque source ids that hoist the inventory overlay.
  static final Set<String> _hoistSources = {};

  /// Register an opaque list source that should hoist the inventory panel.
  static void registerHoistSource(String sourceId) {
    final id = sourceId.trim();
    if (id.isEmpty) return;
    _hoistSources.add(id);
  }

  static void ensureRegistered() {
    registerHoistSource(LiveSurfaceOpen.listSourceId);
  }

  /// Paint portals chip when a pack paint node asks the host (opaque action).
  static Widget buildPortalsChip(
    BuildContext context,
    WidgetRef ref, {
    required String tabId,
    required String rowId,
    required int itemIndex,
    Map<String, dynamic>? action,
    VoidCallback? onDownEdge,
    VoidCallback? onLeftEdge,
    VoidCallback? onRightEdge,
  }) {
    final hoist = (action?['hoistSource'] ?? action?['source'] ?? '')
        .toString()
        .trim();
    if (hoist.isNotEmpty) registerHoistSource(hoist);

    final key = tabId.trim();
    final open = ref.watch(portalsPanelOpenProvider(key));
    // Label only — do not force-refresh inventory on every chip rebuild.
    final inv = ref.watch(portalsInventoryProvider(key));
    final active = inv.asData?.value.activeLabel ?? 'Portals';

    final policy = ShellScope.inputPolicyOf(context);
    return PortalsChip(
      label: active,
      hasPortal: (inv.asData?.value.portals.isNotEmpty ?? false),
      selected: open,
      tvFocus: policy.useFocusableMoodChips,
      onTap: () {
        ref.read(portalsPanelOpenProvider(key).notifier).state = !open;
        if (!open) {
          ref.invalidate(portalsInventoryProvider(key));
        }
      },
      interactiveBuilder: ({
        required child,
        required onTap,
        onFocusChange,
        onHoverChange,
      }) =>
          shellFocusableTap(
            context: context,
            onTap: onTap,
            borderRadius: 8,
            scaleOnFocus: 1.0,
            tvZone: ShellTvZone.topBar,
            tvTabId: tabId,
            tvRowId: rowId,
            tvItemIndex: itemIndex,
            onLeftEdge: onLeftEdge,
            onRightEdge: onRightEdge,
            onDownEdge: onDownEdge,
            onFocusChange: onFocusChange,
            onHoverChange: onHoverChange,
            child: child,
          ),
    );
  }

  static Widget wrapListBody(
    BuildContext context, {
    required Widget child,
    required String tabId,
    required String sourceId,
    required bool shellTabVisible,
  }) {
    // Pack declared this hoist — always host the panel (do not wait for chip).
    registerHoistSource(sourceId);
    return _PortalsPanelHost(
      tabId: tabId,
      shellTabVisible: shellTabVisible,
      child: child,
    );
  }
}

/// Per-hub open state — IPTV and Live Sports must not share one bool.
final portalsPanelOpenProvider =
    StateProvider.family<bool, String>((ref, tabId) => false);

class PortalsInventory {
  const PortalsInventory({
    required this.portals,
    required this.activeKey,
    required this.pluginId,
  });

  final List<PortalListItem> portals;
  final String activeKey;
  final String pluginId;

  String get activeLabel {
    for (final p in portals) {
      if (p.id == activeKey) return p.label;
    }
    return portals.isEmpty ? 'Portals' : portals.first.label;
  }
}

/// Resolve a hub pack that declares `listPortals` (opaque — no pack-id allowlist).
Future<String?> resolvePortalsPluginId({String? preferTabId}) async {
  final tab = (preferTabId ?? '').trim();
  if (tab.isNotEmpty) {
    final fromTab = PluginNavRegistry.pluginIdForTabSync(tab);
    if (fromTab != null && fromTab.isNotEmpty) {
      final packs = await EngineService.instance.listPacks();
      for (final pack in packs) {
        for (final p in pack.plugins) {
          if (p.id == fromTab && p.hasCapability('listPortals')) {
            return p.id;
          }
        }
      }
    }
  }
  final packs = await EngineService.instance.listPacks();
  for (final pack in packs) {
    if (!pack.enabled) continue;
    for (final p in pack.plugins) {
      if (!p.enabled) continue;
      if (p.hasCapability('listPortals')) return p.id;
    }
  }
  return null;
}

/// Inventory keyed by shell tab — Live Sports still resolves IPTV `listPortals`
/// when the live hub itself has no portals capability.
final portalsInventoryProvider = FutureProvider.autoDispose
    .family<PortalsInventory, String>((ref, tabId) async {
  ref.keepAlive();
  final pluginId = await resolvePortalsPluginId(preferTabId: tabId);
  if (pluginId == null || pluginId.isEmpty) {
    return const PortalsInventory(
      portals: [],
      activeKey: '',
      pluginId: '',
    );
  }
  final env = await MetaRuntime.instance.run(
    pluginId: pluginId,
    action: 'listPortals',
    params: const {},
    forceRefresh: false,
  );
  if (!env.ok) {
    return PortalsInventory(
      portals: const [],
      activeKey: '',
      pluginId: pluginId,
    );
  }
  final active = (env.data?['active'] ?? '').toString();
  final raw = env.data?['portals'];
  final items = <PortalListItem>[];
  if (raw is List) {
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final key = (m['key'] ?? '').toString().trim();
      if (key.isEmpty) continue;
      final label = (m['label'] ?? m['username'] ?? key).toString().trim();
      final url = (m['url'] ?? '').toString().trim();
      final platform = (m['platform'] ?? '').toString().trim();
      items.add(
        PortalListItem(
          id: key,
          label: label.isEmpty ? key : label,
          subtitle: url.isEmpty ? null : url,
          selected: key == active,
          platformLabel: platform.isEmpty ? null : platform,
        ),
      );
    }
  }
  return PortalsInventory(
    portals: items,
    activeKey: active,
    pluginId: pluginId,
  );
});

class _PortalsPanelHost extends ConsumerWidget {
  const _PortalsPanelHost({
    required this.child,
    required this.tabId,
    required this.shellTabVisible,
  });

  final Widget child;
  final String tabId;
  final bool shellTabVisible;

  static const _panelWidth = 380.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!shellTabVisible) return child;
    final key = tabId.trim();
    final open = ref.watch(portalsPanelOpenProvider(key));
    return SidePanelOverlay(
      open: open,
      panelWidth: _panelWidth,
      onDismiss: () {
        ref.read(portalsPanelOpenProvider(key).notifier).state = false;
      },
      panel: open
          ? _PackPortalsPanel(
              tabId: key,
              width: _panelWidth,
              onClose: () {
                ref.read(portalsPanelOpenProvider(key).notifier).state = false;
              },
            )
          : const SizedBox.shrink(),
      child: child,
    );
  }
}

class _PackPortalsPanel extends ConsumerStatefulWidget {
  const _PackPortalsPanel({
    required this.tabId,
    required this.width,
    required this.onClose,
  });

  final String tabId;
  final double width;
  final VoidCallback onClose;

  @override
  ConsumerState<_PackPortalsPanel> createState() => _PackPortalsPanelState();
}

class _PackPortalsPanelState extends ConsumerState<_PackPortalsPanel> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _busy = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(
    String action, {
    Map<String, dynamic> params = const {},
    String? toastOk,
  }) async {
    final key = widget.tabId;
    final inv = ref.read(portalsInventoryProvider(key)).asData?.value;
    final pluginId =
        inv?.pluginId ?? await resolvePortalsPluginId(preferTabId: key);
    if (pluginId == null || pluginId.isEmpty) {
      ForjaToast.error('No portals pack installed');
      return;
    }
    setState(() => _busy = true);
    try {
      final env = await MetaRuntime.instance.run(
        pluginId: pluginId,
        action: action,
        params: params,
        forceRefresh: true,
      );
      if (!mounted) return;
      if (!env.ok) {
        ForjaToast.error(
          env.error?.message ?? '$action failed',
        );
        return;
      }
      if (toastOk != null) ForjaToast.success(toastOk);
      ref.invalidate(portalsInventoryProvider(key));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addPortalDialog() async {
    final urlCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add portal'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(labelText: 'URL'),
              ),
              TextField(
                controller: userCtrl,
                decoration: const InputDecoration(labelText: 'Username / MAC'),
              ),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(labelText: 'Label'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      'addPortal',
      params: {
        'url': urlCtrl.text.trim(),
        'username': userCtrl.text.trim(),
        'password': passCtrl.text,
        'label': labelCtrl.text.trim(),
      },
      toastOk: 'Portal added',
    );
  }

  Future<void> _dealPortals() async {
    if (!AccountFeatures.instance.isDealPortalEnabled) {
      ForjaToast.error('Deal is not enabled on this account');
      return;
    }
    setState(() => _busy = true);
    try {
      final profile = await SyncService.instance.activeProfile();
      final profileId = profile?.id.trim() ?? '';
      if (profileId.isEmpty) {
        ForjaToast.error('Sign in and pick a profile to Deal');
        return;
      }
      final ids = await SyncService.instance.dealPortals(profileId: profileId);
      if (!mounted) return;
      if (ids.isEmpty) {
        ForjaToast.show('No portals dealt — pool may be empty');
      } else {
        ForjaToast.success(
          'Dealt ${ids.length} portal${ids.length == 1 ? '' : 's'}',
        );
      }
      ref.invalidate(portalsInventoryProvider(widget.tabId));
    } catch (e) {
      ForjaToast.error(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.tabId;
    final asyncInv = ref.watch(portalsInventoryProvider(key));
    final q = _query.trim().toLowerCase();
    final items = asyncInv.asData?.value.portals ?? const <PortalListItem>[];
    final filtered = q.isEmpty
        ? items
        : [
            for (final p in items)
              if (p.label.toLowerCase().contains(q) ||
                  (p.subtitle?.toLowerCase().contains(q) ?? false))
                p,
          ];

    return PortalListPanel(
      width: widget.width,
      header: Row(
        children: [
          const Expanded(
            child: Text(
              'Portals',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Add',
            onPressed: _busy ? null : _addPortalDialog,
            icon: const Icon(Icons.add, color: Colors.white70),
          ),
          if (AccountFeatures.instance.isDealPortalEnabled)
            IconButton(
              tooltip: 'Deal',
              onPressed: _busy ? null : () => unawaited(_dealPortals()),
              icon: const Icon(Icons.casino_outlined, color: Colors.white70),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy
                ? null
                : () => ref.invalidate(portalsInventoryProvider(key)),
            icon: const Icon(Icons.refresh, color: Colors.white70),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
      searchOpen: true,
      search: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Search portals…',
          hintStyle: TextStyle(color: Colors.white38),
          border: InputBorder.none,
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
      statusText: _busy
          ? 'Working…'
          : asyncInv.isLoading
              ? 'Loading…'
              : '${filtered.length} portal${filtered.length == 1 ? '' : 's'}',
      items: filtered,
      itemBuilder: (context, item, index) {
        return ListTile(
          selected: item.selected,
          title: Text(
            item.label,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: item.subtitle == null
              ? null
              : Text(
                  item.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white54),
            onPressed: _busy
                ? null
                : () => unawaited(
                      _run(
                        'removePortal',
                        params: {'key': item.id},
                        toastOk: 'Removed',
                      ),
                    ),
          ),
          onTap: _busy
              ? null
              : () => unawaited(
                    _run(
                      'selectPortal',
                      params: {'key': item.id},
                      toastOk: 'Selected',
                    ),
                  ),
        );
      },
    );
  }
}
