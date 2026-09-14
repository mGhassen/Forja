import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/runtime/meta/plugin_actions.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja_foundation/layout/chrome/kit_portals_chip.dart';
import 'package:forja/shared/engine/runtime/open/live_surface_open.dart';
import 'package:forja_foundation/layout/top_bar_host_hooks.dart';
import 'package:forja/shared/shell/core/forja_shell_scope.dart';
import 'package:forja/shared/shell/feedback/forja_toast.dart';
import 'package:forja/shared/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';
import 'package:forja_foundation/widgets/chrome/side_panel_overlay.dart';

/// Generic `kit.topBar` `action: portals` — inventory via pack `listPortals`.
///
/// Capability-only. Host runs pack actions + paints foundation [PortalsChip].
abstract final class PortalsActionHost {
  PortalsActionHost._();

  /// Opaque `kit.list` source ids that hoist the portals overlay.
  ///
  /// Packs / surfaces register here — no product id allowlist (`iptv`, …).
  /// Foundation also hoists when layout topBar declares `action: portals`.
  static final Set<String> _hoistSources = {};

  /// Register an opaque list source that should hoist the portals panel.
  static void registerHoistSource(String sourceId) {
    final id = sourceId.trim();
    if (id.isEmpty) return;
    _hoistSources.add(id);
  }

  static bool _hoistSource(String sourceId) {
    final id = sourceId.trim();
    if (id.isEmpty) return false;
    return _hoistSources.contains(id);
  }

  static void ensureRegistered() {
    registerHoistSource(LiveSurfaceOpen.listSourceId);
    KitTopBarHostHooks.packActionBuilders['portals'] = _buildPortalsAction;
    KitTopBarHostHooks.wrapListBody = _wrapListBody;
    KitTopBarHostHooks.shouldHoistListBody = _hoistSource;
  }

  static Widget? _buildPortalsAction(
    BuildContext context,
    WidgetRef ref, {
    required Map<String, dynamic> action,
    required String tabId,
    required String rowId,
    required int itemIndex,
    VoidCallback? onDownEdge,
    VoidCallback? onLeftEdge,
    VoidCallback? onRightEdge,
  }) {
    final open = ref.watch(portalsPanelOpenProvider);
    final inv = ref.watch(portalsInventoryProvider);
    final active = inv.asData?.value.activeLabel ?? 'Portals';

    final policy = ShellScope.inputPolicyOf(context);
    return KitPortalsChip(
      label: active,
      hasPortal: (inv.asData?.value.portals.isNotEmpty ?? false),
      selected: open,
      tvFocus: policy.useFocusableMoodChips,
      onTap: () {
        ref.read(portalsPanelOpenProvider.notifier).state = !open;
        if (!open) {
          ref.invalidate(portalsInventoryProvider);
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

  static Widget _wrapListBody(
    BuildContext context, {
    required Widget child,
    required String tabId,
    required String sourceId,
    required bool shellTabVisible,
  }) {
    if (!_hoistSource(sourceId)) return child;
    return _PortalsPanelHost(
      shellTabVisible: shellTabVisible,
      child: child,
    );
  }
}

final portalsPanelOpenProvider = StateProvider<bool>((ref) => false);

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

final portalsInventoryProvider =
    FutureProvider.autoDispose<PortalsInventory>((ref) async {
  final pluginId = await resolvePortalsPluginId();
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
    forceRefresh: true,
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
    required this.shellTabVisible,
  });

  final Widget child;
  final bool shellTabVisible;

  static const _panelWidth = 380.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!shellTabVisible) return child;
    final open = ref.watch(portalsPanelOpenProvider);
    return SidePanelOverlay(
      open: open,
      panelWidth: _panelWidth,
      onDismiss: () {
        ref.read(portalsPanelOpenProvider.notifier).state = false;
      },
      panel: open
          ? _PackPortalsPanel(
              width: _panelWidth,
              onClose: () {
                ref.read(portalsPanelOpenProvider.notifier).state = false;
              },
            )
          : const SizedBox.shrink(),
      child: child,
    );
  }
}

class _PackPortalsPanel extends ConsumerStatefulWidget {
  const _PackPortalsPanel({
    required this.width,
    required this.onClose,
  });

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
    final inv = ref.read(portalsInventoryProvider).asData?.value;
    final pluginId = inv?.pluginId ?? await resolvePortalsPluginId();
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
      ref.invalidate(portalsInventoryProvider);
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

  @override
  Widget build(BuildContext context) {
    final asyncInv = ref.watch(portalsInventoryProvider);
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
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy
                ? null
                : () => ref.invalidate(portalsInventoryProvider),
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
