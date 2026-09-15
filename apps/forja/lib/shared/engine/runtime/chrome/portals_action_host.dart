import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/network/portal_network.dart';
import 'package:forja/shared/engine/portals/share/portal_share.dart';
import 'package:forja/shared/engine/portals/store/portal_vault_inventory.dart';
import 'package:forja/shared/engine/runtime/meta/plugin_actions.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shared/engine/runtime/open/live_surface_open.dart';
import 'package:forja/shared/sync/api/sync_service.dart';
import 'package:forja/shared/sync/models/account_features.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_row.dart';
import 'package:forja_foundation/widgets/chrome/portals_chip.dart';
import 'package:forja_foundation/widgets/chrome/side_panel_overlay.dart';
import 'package:google_fonts/google_fonts.dart';

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
    this.usernames = const {},
  });

  final List<PortalListItem> portals;
  final String activeKey;
  final String pluginId;

  /// Opaque username by portal key — edit dialog only (not painted).
  final Map<String, String> usernames;

  String get activeLabel {
    for (final p in portals) {
      if (p.id == activeKey) return p.label;
    }
    return portals.isEmpty ? 'Portals' : portals.first.label;
  }
}

Future<Set<String>> _loadPortalFavoriteKeys() async {
  try {
    final raw = await EngineVault.get(PortalVaultKeys.favorites);
    if (raw == null || raw.trim().isEmpty) return {};
    final parsed = jsonDecode(raw);
    if (parsed is! List) return {};
    return {
      for (final e in parsed)
        if (e != null && e.toString().trim().isNotEmpty) e.toString().trim(),
    };
  } catch (_) {
    return {};
  }
}

Future<void> _savePortalFavoriteKeys(Set<String> keys) async {
  await EngineVault.set(
    PortalVaultKeys.favorites,
    jsonEncode(keys.toList()),
  );
}

String? _platformLabel(String raw) {
  final p = raw.trim().toLowerCase();
  if (p.isEmpty) return null;
  return switch (p) {
    'xtream' => 'Xtream',
    'm3u' || 'm3u8' => 'M3U',
    'stalker' || 'mag' => 'Stalker',
    _ => raw.trim(),
  };
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
  // Always bypass MetaRuntime cache — an early empty vault read must not
  // stick for EngineCache maxAge (~5m). Refresh only invalidates Riverpod.
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
  final favs = await _loadPortalFavoriteKeys();
  final items = <PortalListItem>[];
  final usernames = <String, String>{};
  if (raw is List) {
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final key = (m['key'] ?? '').toString().trim();
      if (key.isEmpty) continue;
      final label = (m['label'] ?? m['username'] ?? key).toString().trim();
      final url = (m['url'] ?? '').toString().trim();
      final platform = (m['platform'] ?? '').toString().trim();
      final user = (m['username'] ?? '').toString().trim();
      if (user.isNotEmpty) usernames[key] = user;
      final activeConn = m['activeConnections']?.toString();
      final maxConn = m['maxConnections']?.toString();
      final expiry = m['expiry']?.toString();
      items.add(
        PortalListItem(
          id: key,
          label: label.isEmpty ? key : label,
          subtitle: url.isEmpty ? null : url,
          selected: key == active,
          platformLabel: _platformLabel(platform),
          expiry: (expiry ?? '').trim().isEmpty ? null : expiry!.trim(),
          activeConnections: activeConn,
          maxConnections: maxConn,
          favorite: favs.contains(key),
        ),
      );
    }
  }
  // Favorites first (same order as old panel).
  items.sort((a, b) {
    if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
    return 0;
  });
  return PortalsInventory(
    portals: items,
    activeKey: active,
    pluginId: pluginId,
    usernames: usernames,
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
  bool _searchOpen = false;
  final Set<String> _deletingKeys = {};

  /// Hover/focus probe cache — green/red + optional account fields from probe.
  final Map<String, bool?> _health = {};
  final Map<String, String> _probeExpiry = {};
  final Map<String, String> _probeActive = {};
  final Map<String, String> _probeMax = {};
  final Set<String> _healthInFlight = {};
  final Map<String, Timer> _healthDebounce = {};
  static const _healthHoverDelay = Duration(milliseconds: 350);
  static const _healthTvDelay = Duration(seconds: 2);

  @override
  void dispose() {
    for (final t in _healthDebounce.values) {
      t.cancel();
    }
    _healthDebounce.clear();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isHealthChecking(String portalKey) =>
      _healthInFlight.contains(portalKey) ||
      _healthDebounce.containsKey(portalKey);

  void _cancelHealthCheck(String portalKey) {
    _healthDebounce[portalKey]?.cancel();
    _healthDebounce.remove(portalKey);
  }

  void _scheduleHealthCheck(String portalKey, {required bool leanback}) {
    if (portalKey.isEmpty) return;
    if (_healthInFlight.contains(portalKey)) return;
    _cancelHealthCheck(portalKey);
    // Spinner while dwell timer armed (old panel behavior).
    setState(() {});
    _healthDebounce[portalKey] = Timer(
      leanback ? _healthTvDelay : _healthHoverDelay,
      () {
        _healthDebounce.remove(portalKey);
        unawaited(_runHealthCheck(portalKey));
      },
    );
  }

  String _vaultPortalKey(Map<String, dynamic> m) {
    final explicit = (m['key'] ?? '').toString().trim();
    if (explicit.isNotEmpty) return explicit;
    final url = (m['url'] ?? '').toString().trim().toLowerCase();
    final user = (m['username'] ?? '').toString().trim().toLowerCase();
    return '$url|$user';
  }

  Future<Portal?> _loadVaultPortal(String portalKey) async {
    try {
      final raw = await EngineVault.get(PortalVaultKeys.portals);
      if (raw == null || raw.trim().isEmpty) return null;
      final parsed = jsonDecode(raw);
      if (parsed is! List) return null;
      for (final e in parsed) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        if (_vaultPortalKey(m) != portalKey) continue;
        return Portal.fromJson(m);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _runHealthCheck(String portalKey) async {
    if (!_healthInFlight.add(portalKey)) return;
    if (mounted) setState(() {});
    try {
      final portal = await _loadVaultPortal(portalKey);
      if (portal == null) {
        _health[portalKey] = false;
        return;
      }
      final probe = await PortalClient.probePortal(
        portal,
        timeout: portal.platform == PortalPlatform.m3u
            ? const Duration(seconds: 90)
            : const Duration(seconds: 15),
      );
      _health[portalKey] = probe.alive;
      if (probe.expiry.trim().isNotEmpty &&
          probe.expiry.toLowerCase() != 'unknown') {
        _probeExpiry[portalKey] = probe.expiry;
      }
      if (probe.activeConnections.trim().isNotEmpty) {
        _probeActive[portalKey] = probe.activeConnections;
      }
      if (probe.maxConnections.trim().isNotEmpty) {
        _probeMax[portalKey] = probe.maxConnections;
      }
    } catch (_) {
      _health[portalKey] = false;
    } finally {
      _healthInFlight.remove(portalKey);
      if (mounted) setState(() {});
    }
  }

  PortalListItem _paintItem(PortalListItem p) {
    final checking = _isHealthChecking(p.id);
    final healthy = _health.containsKey(p.id) ? _health[p.id] : p.healthy;
    return PortalListItem(
      id: p.id,
      label: p.label,
      subtitle: p.subtitle,
      selected: p.selected,
      healthy: healthy,
      checking: checking,
      platformLabel: p.platformLabel,
      expiry: _probeExpiry[p.id] ?? p.expiry,
      activeConnections: _probeActive[p.id] ?? p.activeConnections,
      maxConnections: _probeMax[p.id] ?? p.maxConnections,
      favorite: p.favorite,
      isNew: p.isNew,
      deleting: _deletingKeys.contains(p.id),
    );
  }

  Future<MetaEnvelope?> _run(
    String action, {
    Map<String, dynamic> params = const {},
    String? toastOk,
    bool refresh = true,
  }) async {
    final key = widget.tabId;
    final inv = ref.read(portalsInventoryProvider(key)).asData?.value;
    final pluginId =
        inv?.pluginId ?? await resolvePortalsPluginId(preferTabId: key);
    if (pluginId == null || pluginId.isEmpty) {
      ForjaToast.error('No portals pack installed');
      return null;
    }
    setState(() => _busy = true);
    try {
      final env = await MetaRuntime.instance.run(
        pluginId: pluginId,
        action: action,
        params: params,
        forceRefresh: true,
      );
      if (!mounted) return env;
      if (!env.ok) {
        ForjaToast.error(
          env.error?.message ?? '$action failed',
        );
        return env;
      }
      if (toastOk != null) ForjaToast.success(toastOk);
      if (refresh) ref.invalidate(portalsInventoryProvider(key));
      return env;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _portalFormDialog({PortalListItem? existing}) async {
    final inv = ref.read(portalsInventoryProvider(widget.tabId)).asData?.value;
    final urlCtrl = TextEditingController(text: existing?.subtitle ?? '');
    final userCtrl = TextEditingController(
      text: existing == null ? '' : (inv?.usernames[existing.id] ?? ''),
    );
    final passCtrl = TextEditingController();
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final editing = existing != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(editing ? 'Edit portal' : 'Add portal'),
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
                decoration: InputDecoration(
                  labelText: editing ? 'Password (blank = keep)' : 'Password',
                ),
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
            child: Text(editing ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final params = <String, dynamic>{
      'url': urlCtrl.text.trim(),
      'username': userCtrl.text.trim(),
      'label': labelCtrl.text.trim(),
    };
    if (editing) {
      params['key'] = existing.id;
      final pass = passCtrl.text;
      if (pass.isNotEmpty) params['password'] = pass;
      await _run('editPortal', params: params, toastOk: 'Portal updated');
    } else {
      params['password'] = passCtrl.text;
      await _run('addPortal', params: params, toastOk: 'Portal added');
    }
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

  Future<void> _toggleFavorite(String portalKey) async {
    final favs = await _loadPortalFavoriteKeys();
    if (favs.contains(portalKey)) {
      favs.remove(portalKey);
    } else {
      favs.add(portalKey);
    }
    await _savePortalFavoriteKeys(favs);
    if (!mounted) return;
    ref.invalidate(portalsInventoryProvider(widget.tabId));
  }

  Future<String?> _shareCodeFor(String portalKey) async {
    try {
      final portal = await _loadVaultPortal(portalKey);
      if (portal == null) {
        ForjaToast.error('Could not create share code');
        return null;
      }
      final code = await PortalShare.createShare(portal);
      final formatted = PortalShare.formatCode(code);
      ForjaToast.success(
        'Share code copied',
        duration: const Duration(seconds: 2),
      );
      return formatted;
    } catch (e) {
      debugPrint('[Portals] share code failed: $e');
      ForjaToast.error('Could not create share code');
      return null;
    }
  }

  Future<void> _deletePortal(String portalKey) async {
    setState(() => _deletingKeys.add(portalKey));
    try {
      await _run(
        'removePortal',
        params: {'key': portalKey},
        toastOk: 'Removed',
      );
    } finally {
      if (mounted) {
        setState(() => _deletingKeys.remove(portalKey));
      }
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
                  (p.subtitle?.toLowerCase().contains(q) ?? false) ||
                  (p.platformLabel?.toLowerCase().contains(q) ?? false))
                p,
          ];
    final leanback = ShellScope.inputPolicyOf(context).leanbackOnly;
    final canDeal = AccountFeatures.instance.isDealPortalEnabled &&
        SyncService.instance.isSignedIn;
    final credits = AccountFeatures.instance.iptvCredits;

    final painted = [for (final p in filtered) _paintItem(p)];

    return PortalListPanel(
      width: widget.width,
      surfaceColor: ForjaShellColors.cinematic.menuSurface,
      header: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: Row(
          children: [
            Text(
              'Portals',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (canDeal) ...[
              const SizedBox(width: 8),
              Text(
                '$credits cr',
                style: TextStyle(
                  color: credits > 0
                      ? ForjaShellColors.brandGreen
                      : Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const Spacer(),
            IconButton(
              tooltip: _searchOpen ? 'Close search' : 'Search portals',
              onPressed: () {
                setState(() {
                  _searchOpen = !_searchOpen;
                  if (!_searchOpen) {
                    _searchCtrl.clear();
                    _query = '';
                  }
                });
              },
              icon: Icon(
                _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                color: _searchOpen
                    ? ForjaShellColors.brandGreen
                    : Colors.white70,
              ),
            ),
            if (canDeal)
              IconButton(
                tooltip: credits > 0
                    ? 'Deal portals from pool ($credits credits)'
                    : 'Deal portals (no credits)',
                onPressed: _busy || credits < 1
                    ? null
                    : () => unawaited(_dealPortals()),
                icon: Icon(
                  Icons.casino_rounded,
                  color: credits < 1 ? Colors.white38 : Colors.white70,
                ),
              ),
            IconButton(
              tooltip: 'Add portal',
              onPressed: _busy ? null : () => unawaited(_portalFormDialog()),
              icon: const Icon(Icons.add_rounded, color: Colors.white70),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _busy
                  ? null
                  : () => ref.invalidate(portalsInventoryProvider(key)),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
            ),
          ],
        ),
      ),
      searchOpen: _searchOpen,
      search: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: TextField(
          controller: _searchCtrl,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            hintText: 'Search portals…',
            hintStyle: GoogleFonts.plusJakartaSans(
              color: Colors.white38,
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Colors.white54,
              size: 20,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      statusText: _busy
          ? 'Working…'
          : asyncInv.isLoading
              ? 'Loading…'
              : '${filtered.length} portal${filtered.length == 1 ? '' : 's'}',
      body: painted.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.satellite_alt_rounded,
                      size: 48,
                      color: ForjaShellColors.brandGreen,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No portals yet',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add a portal to browse channels.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              itemExtent: PortalListRow.rowHeight,
              itemCount: painted.length,
              itemBuilder: (context, index) {
                final item = painted[index];
                return PortalListRow(
                  item: item,
                  leanback: leanback,
                  onSelect: _busy
                      ? null
                      : () => unawaited(
                            _run(
                              'selectPortal',
                              params: {'key': item.id},
                              toastOk: 'Selected',
                            ),
                          ),
                  onFavorite: _busy
                      ? null
                      : () => unawaited(_toggleFavorite(item.id)),
                  onEdit: _busy
                      ? null
                      : () => unawaited(_portalFormDialog(existing: item)),
                  onDelete: _busy
                      ? null
                      : () => unawaited(_deletePortal(item.id)),
                  onCopyShareCode: _busy
                      ? null
                      : () => _shareCodeFor(item.id),
                  onHoverEnter: () =>
                      _scheduleHealthCheck(item.id, leanback: leanback),
                  onHoverExit: () {
                    _cancelHealthCheck(item.id);
                    if (mounted) setState(() {});
                  },
                );
              },
            ),
    );
  }
}
