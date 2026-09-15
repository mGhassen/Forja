import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/portals/portals_host.dart';
import 'package:forja/shared/engine/runtime/open/live_surface_open.dart';
import 'package:forja/shared/sync/api/sync_service.dart';
import 'package:forja/shared/sync/models/account_features.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/components/form_fields_dialog.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_row.dart';
import 'package:forja_foundation/widgets/chrome/portals_chip.dart';
import 'package:forja_foundation/widgets/chrome/side_panel_overlay.dart';
import 'package:google_fonts/google_fonts.dart';

export 'package:forja/shared/engine/portals/portals_host.dart'
    show
        PortalsHost,
        PortalsChipSummary,
        PortalsInventory,
        PortalHealthTracker,
        PortalsPanelAction;

/// Chrome wire — pack hoist + foundation paint. Services live in [PortalsHost].
abstract final class PortalsActionHost {
  PortalsActionHost._();

  static final Set<String> _hoistSources = {};

  static void registerHoistSource(String sourceId) {
    final id = sourceId.trim();
    if (id.isEmpty) return;
    _hoistSources.add(id);
  }

  static void ensureRegistered() {
    registerHoistSource(LiveSurfaceOpen.listSourceId);
  }

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
    // Vault only while closed — never kick pack listPortals (flutter_js mutex
    // contended with catalog feed). Prefer live inventory once the panel is open.
    final summary = ref.watch(portalsChipSummaryProvider(key));
    var label = summary.asData?.value.label ?? 'Portals';
    var hasPortal = summary.asData?.value.hasPortal ?? false;
    if (open) {
      final inv = ref.watch(portalsInventoryProvider(key));
      final data = inv.asData?.value;
      if (data != null) {
        label = data.activeLabel;
        hasPortal = data.portals.isNotEmpty;
      }
    }

    final policy = ShellScope.inputPolicyOf(context);
    return PortalsChip(
      label: label,
      hasPortal: hasPortal,
      selected: open,
      tvFocus: policy.useFocusableMoodChips,
      onTap: () {
        ref.read(portalsPanelOpenProvider(key).notifier).state = !open;
        if (!open) {
          ref.invalidate(portalsInventoryProvider(key));
        } else {
          ref.invalidate(portalsChipSummaryProvider(key));
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

/// Vault-backed chip label — safe to watch on hub open (no pack / flutter_js).
final portalsChipSummaryProvider = FutureProvider.autoDispose
    .family<PortalsChipSummary, String>((ref, tabId) async {
  ref.keepAlive();
  return PortalsHost.chipSummary();
});

/// Inventory keyed by shell tab (Live Sports may resolve IPTV `listPortals`).
/// Watch only when the Portals panel is open — not from the closed chip.
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

/// Back-compat alias — prefer [PortalsHost.resolvePluginId].
Future<String?> resolvePortalsPluginId({String? preferTabId}) =>
    PortalsHost.resolvePluginId(preferTabId: preferTabId);

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
  late final PortalHealthTracker _health;

  @override
  void initState() {
    super.initState();
    _health = PortalHealthTracker(onChanged: () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _health.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<String?> _pluginId() async {
    final inv =
        ref.read(portalsInventoryProvider(widget.tabId)).asData?.value;
    return inv?.pluginId.isNotEmpty == true
        ? inv!.pluginId
        : PortalsHost.resolvePluginId(preferTabId: widget.tabId);
  }

  Future<bool> _runAction(
    Future<MetaEnvelope> Function(String pluginId) action, {
    String? toastOk,
    bool refresh = true,
  }) async {
    final pluginId = await _pluginId();
    if (pluginId == null || pluginId.isEmpty) {
      ForjaToast.error('No portals pack installed');
      return false;
    }
    setState(() => _busy = true);
    try {
      final env = await action(pluginId);
      if (!mounted) return false;
      if (!env.ok) {
        ForjaToast.error(env.error?.message ?? 'Action failed');
        return false;
      }
      if (toastOk != null) ForjaToast.success(toastOk);
      if (refresh) invalidatePortalsChrome(ref, widget.tabId);
      return true;
    } catch (e) {
      ForjaToast.error(e.toString());
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runPackForm(
    FormFieldsSpec form, {
    Map<String, String>? values,
    String? portalKey,
  }) async {
    final filled = values == null ? form : form.withValues(values);
    final result = await showFormFieldsDialog(
      context: context,
      spec: filled,
    );
    if (result == null || !mounted) return;
    final action = filled.action.trim();
    if (action.isEmpty) {
      ForjaToast.error('Form has no action');
      return;
    }
    final params = <String, dynamic>{
      for (final e in result.entries) e.key: e.value,
    };
    if (portalKey != null && portalKey.isNotEmpty) {
      params['key'] = portalKey;
    }
    for (final f in filled.fields) {
      final t = f.type.toLowerCase();
      if ((t == 'password' || t == 'secret') &&
          (params[f.id] ?? '').toString().isEmpty) {
        params.remove(f.id);
      }
    }
    final toast = filled.toastOk.trim();
    await _runAction(
      (id) => PortalsHost.run(
        pluginId: id,
        action: action,
        params: params,
      ),
      toastOk: toast.isEmpty ? null : toast,
    );
  }

  Future<void> _dispatchPanelAction(PortalsPanelAction a) async {
    final verb = a.action.trim().toLowerCase();
    if (verb == 'listportals' || verb == 'refresh') {
      invalidatePortalsChrome(ref, widget.tabId);
      return;
    }
    if (verb == 'dealportals' || a.id == 'deal') {
      await _dealPortals();
      return;
    }
    final form = a.form;
    if (form != null) {
      await _runPackForm(form);
      return;
    }
    await _runAction(
      (id) => PortalsHost.run(pluginId: id, action: a.action),
      toastOk: a.label,
    );
  }

  IconData _actionIcon(PortalsPanelAction a) {
    final raw = a.icon.trim().isNotEmpty ? a.icon : a.id;
    final id = raw.trim().toLowerCase();
    return switch (id) {
      'add' => Icons.add_rounded,
      'import' || 'content_paste' || 'paste' => Icons.content_paste_rounded,
      'casino' || 'deal' => Icons.casino_rounded,
      'refresh' => Icons.refresh_rounded,
      _ => Icons.circle_outlined,
    };
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
      final ids = await PortalsHost.deal(profileId: profileId);
      if (!mounted) return;
      if (ids.isEmpty) {
        ForjaToast.show('No portals dealt — pool may be empty');
      } else {
        ForjaToast.success(
          'Dealt ${ids.length} portal${ids.length == 1 ? '' : 's'}',
        );
      }
      invalidatePortalsChrome(ref, widget.tabId);
    } catch (e) {
      ForjaToast.error(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFavorite(String portalKey) async {
    await PortalsHost.toggleFavorite(portalKey);
    if (!mounted) return;
    invalidatePortalsChrome(ref, widget.tabId);
  }

  Future<String?> _shareCodeFor(String portalKey) async {
    final code = await PortalsHost.createShareCode(portalKey);
    if (code == null) {
      ForjaToast.error('Could not create share code');
      return null;
    }
    ForjaToast.success(
      'Share code copied',
      duration: const Duration(seconds: 2),
    );
    return code;
  }

  Future<void> _deletePortal(String portalKey) async {
    setState(() => _deletingKeys.add(portalKey));
    try {
      await _runAction(
        (id) => PortalsHost.remove(pluginId: id, key: portalKey),
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
    final inv = asyncInv.asData?.value;
    final panelTitle =
        (inv?.title.trim().isNotEmpty ?? false) ? inv!.title : 'Portals';
    final canDeal = AccountFeatures.instance.isDealPortalEnabled &&
        SyncService.instance.isSignedIn;
    final credits = AccountFeatures.instance.iptvCredits;
    final leanback = ShellScope.inputPolicyOf(context).leanbackOnly;

    final painted = [
      for (final p in filtered)
        _health.paint(p, deleting: _deletingKeys.contains(p.id)),
    ];

    final visibleActions = <PortalsPanelAction>[
      for (final a in inv?.actions ?? const <PortalsPanelAction>[])
        if (a.id != 'deal' && a.action.toLowerCase() != 'dealportals')
          a
        else if (canDeal)
          a,
    ];

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
              panelTitle,
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
            for (final a in visibleActions)
              IconButton(
                tooltip: a.id == 'deal' ||
                        a.action.toLowerCase() == 'dealportals'
                    ? (credits > 0
                        ? '${a.label} ($credits credits)'
                        : '${a.label} (no credits)')
                    : a.label,
                onPressed: _busy ||
                        ((a.id == 'deal' ||
                                a.action.toLowerCase() == 'dealportals') &&
                            credits < 1)
                    ? null
                    : () => unawaited(_dispatchPanelAction(a)),
                icon: Icon(
                  _actionIcon(a),
                  color: (a.id == 'deal' ||
                              a.action.toLowerCase() == 'dealportals') &&
                          credits < 1
                      ? Colors.white38
                      : Colors.white70,
                ),
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
                      'Add or import a portal to browse channels.',
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
                            _runAction(
                              (id) => PortalsHost.select(
                                pluginId: id,
                                key: item.id,
                              ),
                              toastOk: 'Selected',
                            ),
                          ),
                  onFavorite: _busy
                      ? null
                      : () => unawaited(_toggleFavorite(item.id)),
                  onEdit: _busy || inv?.editForm == null
                      ? null
                      : () => unawaited(
                            _runPackForm(
                              inv!.editForm!,
                              values: inv.formValues[item.id],
                              portalKey: item.id,
                            ),
                          ),
                  onDelete: _busy
                      ? null
                      : () => unawaited(_deletePortal(item.id)),
                  onCopyShareCode: _busy
                      ? null
                      : () => _shareCodeFor(item.id),
                  onHoverEnter: () =>
                      _health.schedule(item.id, leanback: leanback),
                  onHoverExit: () {
                    _health.cancel(item.id);
                    if (mounted) setState(() {});
                  },
                );
              },
            ),
    );
  }
}
