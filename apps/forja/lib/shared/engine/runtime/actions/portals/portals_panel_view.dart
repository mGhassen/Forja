import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/cache/engine_cache.dart';
import 'package:forja/shared/engine/portals/guide/portal_channel_guide_open.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/portal_form_dialog.dart';
import 'package:forja/shared/engine/portals/portals_host.dart';
import 'package:forja/shared/engine/runtime/actions/category_bar/category_bar_action_host.dart';
import 'package:forja/shared/engine/runtime/actions/portals/portals_panel_tv.dart';
import 'package:forja/shared/engine/runtime/actions/portals/portals_providers.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja/shared/engine/runtime/kit/pack_load_paint.dart';
import 'package:forja/shared/sync/api/sync_service.dart';
import 'package:forja/shared/sync/models/account_features.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_browse_text_field.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/tokens/portal_list_tokens.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_row.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_view.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

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
  late final PortalsPanelTvFocus _tv;
  Set<String> _knownPortalKeys = {};
  int _headerActionCount = 0;
  int _filteredLength = 0;
  int _activeIndex = -1;
  String? _activeKey;
  bool _tvInventoryScheduled = false;

  @override
  void initState() {
    super.initState();
    _tv = PortalsPanelTvFocus(tabId: widget.tabId);
    _tv.didFocusOnOpen = true;
    _health = PortalHealthTracker(onChanged: () {
      if (mounted) setState(() {});
    });
    // Vault already painted by provider build; soft cloud prepare in background.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(portalsInventoryProvider(widget.tabId).notifier).prepare(),
      );
      _tv.focusPanelOnOpen(
        filteredLength: _filteredLength,
        activeIndex: _activeIndex,
        headerActionCount: _headerActionCount,
        mounted: mounted,
        searchOpen: false,
      );
    });
  }

  void _scheduleTvInventoryPass({
    required Set<String> currentKeys,
    required int activeIdx,
    required int itemCount,
  }) {
    if (_tvInventoryScheduled) return;
    _tvInventoryScheduled = true;
    final knownSnapshot = {..._knownPortalKeys};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tvInventoryScheduled = false;
      if (!mounted) return;
      _tv.onInventoryChanged(
        panelOpen: true,
        searchOpen: false,
        filteredLength: itemCount,
        activeKey: _activeKey,
        activeIndex: activeIdx,
        currentKeys: currentKeys,
        knownKeys: knownSnapshot,
        setKnownKeys: (next) => _knownPortalKeys = next,
        mounted: mounted,
      );
    });
  }

  @override
  void dispose() {
    _health.dispose();
    _tv.dispose();
    super.dispose();
  }

  Future<String?> _pluginId() async {
    final inv =
        ref.read(portalsInventoryProvider(widget.tabId)).asData?.value;
    return inv?.pluginId.isNotEmpty == true
        ? inv!.pluginId
        : PortalsHost.resolvePluginId(preferTabId: widget.tabId);
  }

  /// Mutate path (add/edit/delete/deal) — wipe in-memory feed, soft-bump.
  /// Pack disk catalog still OK (`forceNetwork: false`).
  void _reloadHubCatalog(String pluginId) {
    EngineCache.instance.wipePlugin(pluginId);
    PackLoadedPaint.clearMemosForPlugin(pluginId);
    PackChromeScope.maybeOf(context)?.onBumpRefresh(forceNetwork: false);
  }

  /// Soft switch — vault active first, clear grid, soft-bump feed.
  Future<void> _selectPortal(String portalKey) async {
    final pluginId = await _pluginId();
    if (pluginId == null || pluginId.isEmpty) {
      ForjaToast.error('No portals pack installed');
      return;
    }
    if (!mounted) return;

    await PortalsHost.setActiveKey(portalKey);
    if (!mounted) return;
    invalidatePortalsChrome(ref, widget.tabId);

    // Stamp portalStoreKey into feed params so EngineCache is per-portal.
    await CategoryBarActionHost.liveListFeedParams(preferTabId: widget.tabId);
    if (!mounted) return;

    // Soft switch: wipe EngineCache + paint memos (pack may still disk-hit).
    // Without wipe, an empty “Choose a portal” cover cached under this
    // portalStoreKey (pre-active fallback) paints forever after select.
    EngineCache.instance.wipePlugin(pluginId);
    PackLoadedPaint.clearMemosForPlugin(pluginId);
    final chrome = PackChromeScope.maybeOf(context);
    // Drop stale "Choose a portal" cover so loading paints while feed runs.
    chrome?.onClearCatalog();
    chrome?.onBumpRefresh(forceNetwork: false);

    unawaited((() async {
      try {
        final env = await PortalsHost.select(
          pluginId: pluginId,
          key: portalKey,
        );
        if (!mounted) return;
        if (!env.ok) {
          ForjaToast.error(env.error?.message ?? 'Could not select portal');
          PackChromeScope.maybeOf(context)?.onBumpRefresh(forceNetwork: false);
          return;
        }
        // Pack may rewrite active to canonical url|user — re-stamp + soft bump.
        await CategoryBarActionHost.liveListFeedParams(
          preferTabId: widget.tabId,
        );
        if (!mounted) return;
        PackLoadedPaint.clearMemosForPlugin(pluginId);
        PackChromeScope.maybeOf(context)?.onBumpRefresh(forceNetwork: false);
      } catch (e) {
        if (mounted) {
          ForjaToast.error(e.toString());
          PackChromeScope.maybeOf(context)?.onBumpRefresh(forceNetwork: false);
        }
      }
    })());
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

  Future<void> _afterPortalMutated({required String pluginId}) async {
    PortalChannelGuideOpen.invalidateLiveCatalog();
    invalidatePortalsChrome(ref, widget.tabId);
    _reloadHubCatalog(pluginId);
  }

  Future<void> _openPortalForm({VerifiedPortal? existing}) async {
    final pluginId = await _pluginId();
    if (pluginId == null || pluginId.isEmpty) {
      ForjaToast.error('No portals pack installed');
      return;
    }
    if (!mounted) return;
    if (existing == null &&
        !AccountFeatures.instance.canAddPortal(
          ref.read(portalsInventoryProvider(widget.tabId)).asData?.value.portals.length ??
              0,
        )) {
      ForjaToast.warning(AccountFeatures.instance.iptvPortalLimitReachedMessage());
      return;
    }
    final count = ref
            .read(portalsInventoryProvider(widget.tabId))
            .asData
            ?.value
            .portals
            .length ??
        0;
    final ok = await showPortalFormDialog(
      context,
      existing: existing,
      pluginId: pluginId,
      currentPortalCount: count,
    );
    if (ok == true && mounted) {
      await _afterPortalMutated(pluginId: pluginId);
    }
  }

  Future<void> _editPortal(String portalKey) async {
    VerifiedPortal? verified;
    for (final v in await PortalsHost.loadVaultVerifiedPortals()) {
      if (!PortalsHost.samePortalKey(v.key, portalKey)) continue;
      verified = v;
      break;
    }
    if (verified == null) {
      ForjaToast.error('Portal not found');
      return;
    }
    if (!mounted) return;
    await _openPortalForm(existing: verified);
  }

  Future<void> _dispatchPanelAction(PortalsPanelAction a) async {
    final verb = a.action.trim().toLowerCase();
    final id = a.id.trim().toLowerCase();
    if (verb == 'listportals' || verb == 'refresh') {
      _health.invalidate();
      unawaited(
        ref.read(portalsInventoryProvider(widget.tabId).notifier).prepare(),
      );
      return;
    }
    if (verb == 'dealportals' || id == 'deal') {
      await _dealPortals();
      return;
    }
    if (id == 'add' ||
        verb == 'addportal' ||
        id == 'import' ||
        verb == 'importportal') {
      await _openPortalForm();
      return;
    }
    await _runAction(
      (pid) => PortalsHost.run(pluginId: pid, action: a.action),
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
      final result = await PortalsHost.deal(profileId: profileId);
      if (!mounted) return;
      final ids = result.ids;
      if (ids.isEmpty) {
        ForjaToast.show('No portals dealt — pool may be empty');
      } else if (!result.synced) {
        ForjaToast.error(
          'Dealt ${ids.length} portal${ids.length == 1 ? '' : 's'} '
          'but the list could not refresh — reopen Portals',
        );
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
      final inv =
          ref.read(portalsInventoryProvider(widget.tabId)).asData?.value;
      final wasActive = inv != null &&
          inv.activeKey.isNotEmpty &&
          PortalsHost.samePortalKey(inv.activeKey, portalKey);
      if (wasActive && mounted) {
        PackChromeScope.maybeOf(context)?.onClearCatalog();
      }
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
              (activeKey.isNotEmpty &&
                  PortalsHost.samePortalKey(p.id, activeKey)),
        ),
    ];
    final canDeal = AccountFeatures.instance.isDealPortalEnabled &&
        SyncService.instance.isSignedIn;
    final canScrape = AccountFeatures.instance.isIptvScrapeEnabled;
    final credits = AccountFeatures.instance.iptvCredits;

    // Pack order L→R after Search: Scrape · Deal · Add (+ opens Add/Import dialog).
    // Import is folded into + — do not paint a separate Import header icon.
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
            hoverLabel: '$credits cr',
            hoverLabelMuted: credits < 1,
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
        : (asyncInv.isLoading && inv == null)
            ? 'Loading…'
            : '';

    final currentKeys = {for (final p in items) p.id};
    final activeIdx = activeKey.isEmpty
        ? -1
        : items.indexWhere((p) => PortalsHost.samePortalKey(p.id, activeKey));
    _filteredLength = items.length;
    _activeIndex = activeIdx;
    _activeKey = activeKey.isEmpty ? null : activeKey;
    _headerActionCount = headerActions.length;
    final rowExtent = PortalListTokens.resolveRowHeight(
      ShellScope.metricsOf(context).usesTvDensity,
      inv?.rowHeight ?? PortalListRow.rowHeight,
    );
    _tv.rowHeight = rowExtent;
    if (_knownPortalKeys.isEmpty && currentKeys.isNotEmpty) {
      _knownPortalKeys = {...currentKeys};
    }
    final useTv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    if (useTv) {
      _scheduleTvInventoryPass(
        currentKeys: currentKeys,
        activeIdx: activeIdx,
        itemCount: items.length,
      );
    }

    Widget panel = ShellPaintTvTabScope(
      tabId: widget.tabId,
      child: PortalListView(
      width: widget.width,
      title: (inv?.title.trim().isNotEmpty ?? false) ? inv!.title : 'Portals',
      items: items,
      headerActions: headerActions,
      searchPlaceholder: inv?.searchPlaceholder ?? '',
      emptyTitle: inv?.emptyTitle ?? '',
      emptyDescription: inv?.emptyDescription ?? '',
      statusText: statusText,
      busy: _busy,
      leanback: leanback,
      listScrollController: _tv.listScroll,
      titleFontSize: inv?.titleFontSize ?? 18,
      rowHeight: rowExtent,
      onClose: widget.onClose,
      onSelect: (item) => unawaited(_selectPortal(item.id)),
      onFavorite: (item) => unawaited(_toggleFavorite(item.id)),
      onEdit: (item) => unawaited(_editPortal(item.id)),
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
      onHeaderUp: useTv ? _tv.exitUpToChip : null,
      onHeaderDown: useTv
          ? () => _tv.focusPortalsFromHeader(
                filteredLength: items.length,
                activeIndex: activeIdx,
                mounted: mounted,
              )
          : null,
      onHeaderFocusAt: useTv ? _tv.focusHeaderAt : null,
      onPortalLeft: useTv ? _tv.onPortalLeft : null,
      onPortalMove: useTv
          ? (from, deltaSign) => _tv.onPortalMove(
                fromIndex: from,
                deltaSign: deltaSign,
                total: items.length,
                mounted: mounted,
              )
          : null,
      onPortalExitUp: useTv
          ? () => _tv.focusHeaderAdd(headerActionCount: headerActions.length)
          : null,
      onPortalExitDown: useTv ? _tv.exitDownToCatalog : null,
      onPortalTvFocus: useTv ? _tv.markPortalTvFocus : null,
      onListPointerBrowse: useTv ? _tv.onListPointerBrowse : null,
      // Desktop/TV: D-pad land highlights the field; OK opens the keyboard.
      searchFieldBuilder: !shellTvBrowseSearch(context)
          ? null
          : (ctx, {
              required controller,
              required focusNode,
              required onChanged,
              required onEscape,
              required decoration,
              required style,
              required placeholder,
            }) {
              return TvBrowseTextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                onEscape: onEscape,
                browsePlaceholder: placeholder,
                browseHintStyle: decoration.hintStyle,
                style: style,
                decoration: decoration,
              );
            },
      ),
    );

    if (useTv) {
      panel = ShellTvContainDpad(child: panel);
    }
    return panel;
  }
}
