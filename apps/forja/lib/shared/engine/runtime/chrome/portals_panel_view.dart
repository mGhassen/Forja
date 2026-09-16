import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/cache/engine_cache.dart';
import 'package:forja/shared/engine/portals/guide/portal_channel_guide_open.dart';
import 'package:forja/shared/engine/portals/portals_host.dart';
import 'package:forja/shared/engine/runtime/chrome/portals_providers.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja/shared/sync/api/sync_service.dart';
import 'package:forja/shared/sync/models/account_features.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/components/form_fields_dialog.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_view.dart';

/// Thin host wire — pack inventory → [PortalListView] props + [PortalsHost].
class PortalsPanelView extends ConsumerStatefulWidget {
  const PortalsPanelView({
    super.key,
    required this.tabId,
    required this.width,
    required this.onClose,
  });

  final String tabId;
  final double width;
  final VoidCallback onClose;

  @override
  ConsumerState<PortalsPanelView> createState() => _PortalsPanelViewState();
}

class _PortalsPanelViewState extends ConsumerState<PortalsPanelView> {
  bool _busy = false;
  final Set<String> _deletingKeys = {};
  late final PortalHealthTracker _health;
  String _probedSelectedKey = '';

  @override
  void initState() {
    super.initState();
    _health = PortalHealthTracker(onChanged: () {
      if (mounted) setState(() {});
    });
  }

  void _probeSelectedIfNeeded(List<PortalListItem> items, {required bool leanback}) {
    String selectedId = '';
    for (final p in items) {
      if (!p.selected) continue;
      selectedId = p.id;
      break;
    }
    if (selectedId.isEmpty) {
      _probedSelectedKey = '';
      return;
    }
    if (selectedId == _probedSelectedKey) return;
    _probedSelectedKey = selectedId;
    // Post-frame — schedule/_run notifies listeners (setState).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _probedSelectedKey != selectedId) return;
      _health.schedule(
        selectedId,
        leanback: leanback,
        immediate: true,
      );
    });
  }

  @override
  void dispose() {
    _health.dispose();
    super.dispose();
  }

  Future<String?> _pluginId() async {
    final inv =
        ref.read(portalsInventoryProvider(widget.tabId)).asData?.value;
    return inv?.pluginId.isNotEmpty == true
        ? inv!.pluginId
        : PortalsHost.resolvePluginId(preferTabId: widget.tabId);
  }

  /// Feed EngineCache is portal-blind — wipe it, then soft-bump rails so the
  /// new active portal loads. Do not stamp pack `force` (that skips disk cache).
  void _reloadHubCatalog(String pluginId) {
    EngineCache.instance.wipePlugin(pluginId);
    PackChromeScope.maybeOf(context)?.onBumpRefresh(forceNetwork: false);
  }

  Future<bool> _runAction(
    Future<MetaEnvelope> Function(String pluginId) action, {
    String? toastOk,
    bool refresh = true,
    bool reloadCatalog = false,
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
      if (refresh) {
        PortalChannelGuideOpen.invalidateLiveCatalog();
        invalidatePortalsChrome(ref, widget.tabId);
      }
      if (reloadCatalog) _reloadHubCatalog(pluginId);
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
      reloadCatalog: true,
    );
  }

  Future<void> _dispatchPanelAction(PortalsPanelAction a) async {
    final verb = a.action.trim().toLowerCase();
    if (verb == 'listportals' || verb == 'refresh') {
      _probedSelectedKey = '';
      _health.invalidate();
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
        final pluginId = await _pluginId();
        if (pluginId != null && pluginId.isNotEmpty && mounted) {
          PortalChannelGuideOpen.invalidateLiveCatalog();
          _reloadHubCatalog(pluginId);
        }
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
        reloadCatalog: true,
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
    final inv = asyncInv.asData?.value;
    final activeKey = (inv?.activeKey ?? '').trim();
    final leanback = ShellScope.inputPolicyOf(context).leanbackOnly;
    final items = [
      for (final p in inv?.portals ?? const <PortalListItem>[])
        _health.paint(
          p,
          deleting: _deletingKeys.contains(p.id),
          selected: p.selected ||
              (activeKey.isNotEmpty && p.id == activeKey),
        ),
    ];
    _probeSelectedIfNeeded(items, leanback: leanback);
    final canDeal = AccountFeatures.instance.isDealPortalEnabled &&
        SyncService.instance.isSignedIn;
    final canScrape = AccountFeatures.instance.isIptvScrapeEnabled;
    final credits = AccountFeatures.instance.iptvCredits;

    // Pack order L→R after Search: Scrape · Deal · Add (= R→L Add · Deal · Scrape · Search).
    final headerActions = <PortalListHeaderAction>[];
    for (final a in inv?.actions ?? const <PortalsPanelAction>[]) {
      final id = a.id.trim().toLowerCase();
      final verb = a.action.trim().toLowerCase();
      if (id == 'import' ||
          id == 'refresh' ||
          verb == 'importportal' ||
          verb == 'listportals' ||
          verb == 'refresh') {
        continue;
      }
      if ((id == 'deal' || verb == 'dealportals') && !canDeal) continue;
      if ((id == 'scrape' || verb == 'scrape') && !canScrape) continue;
      if (id == 'deal' || verb == 'dealportals') {
        headerActions.add(
          PortalListHeaderAction(
            id: a.id,
            label: a.label,
            icon: a.icon,
            enabled: !_busy && credits >= 1,
            tooltip: credits > 0
                ? '${a.label} ($credits credits)'
                : '${a.label} (no credits)',
            onPressed: () => unawaited(_dispatchPanelAction(a)),
          ),
        );
        continue;
      }
      headerActions.add(
        PortalListHeaderAction(
          id: a.id,
          label: a.label,
          icon: a.icon,
          enabled: !_busy,
          onPressed: () => unawaited(_dispatchPanelAction(a)),
        ),
      );
    }

    final statusText = _busy
        ? 'Working…'
        : asyncInv.isLoading
            ? 'Loading…'
            : '';

    return PortalListView(
      width: widget.width,
      title: (inv?.title.trim().isNotEmpty ?? false) ? inv!.title : 'Portals',
      items: items,
      badgeLabel: canDeal ? '$credits cr' : null,
      badgeMuted: canDeal && credits < 1,
      headerActions: headerActions,
      searchPlaceholder: inv?.searchPlaceholder ?? '',
      emptyTitle: inv?.emptyTitle ?? '',
      emptyDescription: inv?.emptyDescription ?? '',
      statusText: statusText,
      busy: _busy,
      leanback: leanback,
      onClose: widget.onClose,
      onSelect: (item) => unawaited(
            _runAction(
              (id) => PortalsHost.select(pluginId: id, key: item.id),
              reloadCatalog: true,
            ),
          ),
      onFavorite: (item) => unawaited(_toggleFavorite(item.id)),
      onEdit: inv?.editForm == null
          ? null
          : (item) => unawaited(
                _runPackForm(
                  inv!.editForm!,
                  values: inv.formValues[item.id],
                  portalKey: item.id,
                ),
              ),
      onDelete: (item) => unawaited(_deletePortal(item.id)),
      onCopyShareCode: (item) => _shareCodeFor(item.id),
      onHoverEnter: (item) => _health.schedule(
            item.id,
            leanback: leanback,
            // Soft refresh like the chip — recheck even when TTL is fresh.
            force: true,
          ),
      onHoverExit: (item) {
        _health.cancel(item.id);
        if (mounted) setState(() {});
      },
    );
  }
}
