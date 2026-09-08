import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/portal_sports/iptv_portal_sports_config.dart';
import 'package:forja/features/iptv/providers/iptv_controller_provider.dart';
import 'package:forja/features/iptv/screens/iptv_catalog_workspace.dart';
import 'package:forja/features/iptv/screens/iptv_portals_top_bar_button.dart';
import 'package:forja/shared/foundation/components/panel/kit_side_panel_overlay.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/foundation/services/registry/kit_top_bar_host_hooks.dart';
import 'package:forja/shared/foundation/services/schedule/kit_live_boot.dart';

/// Registers Portals chip + panel on kit tabs that use [KitLiveBoot.listSourceId].
///
/// Design: [KitPortalsChip] / [KitSidePanelOverlay] via adapters. Data: IPTV
/// controller + [IptvPortalSportsConfig] (RFC-095).
abstract final class IptvPortalsChromeHooks {
  IptvPortalsChromeHooks._();

  static void ensureRegistered() {
    KitTopBarHostHooks.buildTrailing = _buildTrailing;
    KitTopBarHostHooks.wrapListBody = _wrapListBody;
  }

  static Widget? _buildTrailing(
    BuildContext context,
    WidgetRef ref, {
    required String tabId,
    required String rowId,
    required int itemIndex,
    VoidCallback? onLeftEdge,
    VoidCallback? onDownEdge,
  }) {
    final enabled = ref.watch(_forjaSportsEnabledProvider).asData?.value;
    if (enabled == false) return null;
    final ctrl = ref.watch(iptvControllerProvider);
    return IptvPortalsTopBarButton(
      ctrl: ctrl,
      onTogglePanel: ctrl.togglePortalPanel,
      tvTabId: tabId,
      tvRowId: rowId,
      tvItemIndex: itemIndex,
      onLeftEdge: onLeftEdge,
      onRightEdge: () {},
      onDownEdge: onDownEdge,
    );
  }

  static Widget _wrapListBody(
    BuildContext context, {
    required Widget child,
    required String tabId,
    required String sourceId,
    required bool shellTabVisible,
  }) {
    if (sourceId != KitLiveBoot.listSourceId) return child;
    return _IptvPortalsPanelHost(
      shellTabVisible: shellTabVisible,
      child: child,
    );
  }
}

final _forjaSportsEnabledProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final config = await IptvPortalSportsConfig.load();
  return config.enabled;
});

class _IptvPortalsPanelHost extends ConsumerStatefulWidget {
  const _IptvPortalsPanelHost({
    required this.child,
    required this.shellTabVisible,
  });

  final Widget child;
  final bool shellTabVisible;

  @override
  ConsumerState<_IptvPortalsPanelHost> createState() =>
      _IptvPortalsPanelHostState();
}

class _IptvPortalsPanelHostState
    extends ConsumerState<_IptvPortalsPanelHost> {
  static const _panelWidth = 380.0;

  String? _lastSyncedPortalKey;
  bool _prepared = false;

  @override
  void didUpdateWidget(covariant _IptvPortalsPanelHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shellTabVisible && !widget.shellTabVisible) {
      ref.read(iptvControllerProvider).closePortalPanel();
    }
  }

  Future<void> _syncPortal(IptvController ctrl, {required bool reload}) async {
    final p = ctrl.activePortal;
    if (p == null) return;
    if (!p.portal.platform.supportsForjaSports) {
      final alreadyWarned = _lastSyncedPortalKey == p.key;
      _lastSyncedPortalKey = p.key;
      if (!alreadyWarned && mounted) {
        ForjaToast.info('Forja Sports needs an Xtream or Stalker portal');
      }
      return;
    }
    final before = await IptvPortalSportsConfig.load();
    final next = await IptvPortalSportsConfig.ensureArmed(portalKey: p.key);
    _lastSyncedPortalKey = p.key;
    final changed = before.portalKey != next.portalKey ||
        (before.leagues.isEmpty && next.leagues.isNotEmpty);
    if (!mounted) return;
    if (reload || changed) {
      ref.invalidate(_forjaSportsEnabledProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(_forjaSportsEnabledProvider).asData?.value;
    if (enabled == false) return widget.child;

    final ctrl = ref.watch(iptvControllerProvider);

    if (widget.shellTabVisible && !_prepared) {
      _prepared = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.shellTabVisible) return;
        unawaited(() async {
          await ctrl.preparePortalPanel();
          if (!mounted) return;
          await _syncPortal(ctrl, reload: false);
        }());
      });
    }
    if (!widget.shellTabVisible) {
      _prepared = false;
    }

    ref.listen(iptvControllerProvider, (prev, next) {
      if (!mounted || !widget.shellTabVisible) return;
      final key = next.activePortal?.key;
      if (key == null) return;
      if (key == _lastSyncedPortalKey &&
          (prev == null || prev.portalPanelOpen == next.portalPanelOpen)) {
        return;
      }
      unawaited(_syncPortal(next, reload: true));
    });

    return KitSidePanelOverlay(
      open: ctrl.portalPanelOpen,
      panelWidth: _panelWidth,
      onDismiss: ctrl.closePortalPanel,
      panel: IptvPortalPanel(
        ctrl: ctrl,
        width: KitSidePanelOverlay.defaultUseSideRail(context)
            ? _panelWidth
            : MediaQuery.sizeOf(context).width * 0.92,
        onClose: ctrl.closePortalPanel,
      ),
      child: widget.child,
    );
  }
}
