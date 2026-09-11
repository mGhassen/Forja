import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/iptv/channel_search/iptv_forja_sports_gate.dart';
import 'package:forja/features/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/iptv_tv_focus.dart';
import 'package:forja/features/iptv/providers/iptv_controller_provider.dart';
import 'package:forja/features/iptv/screens/iptv_catalog_workspace.dart';
import 'package:forja/features/iptv/screens/iptv_portals_top_bar_button.dart';
import 'package:forja_foundation/widgets/chrome/side_panel_overlay.dart';

import 'package:forja/shared/engine/hub/kit_top_bar_host_hooks.dart';
import 'package:forja/shared/engine/hub/kit_live_boot.dart';
import 'package:forja/shared/shell/forja_toast.dart';

/// IPTV data for pack-declared `kit.topBar` `action: portals` (+ list overlay).
///
/// Packs must list the Portals action themselves — this never invents chrome.
abstract final class IptvPortalsChromeHooks {
  IptvPortalsChromeHooks._();

  static void ensureRegistered() {
    KitTopBarHostHooks.packActionBuilders['portals'] = _buildPortalsAction;
    KitTopBarHostHooks.wrapListBody = _wrapListBody;
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
    final enabled = ref.watch(_forjaSportsEnabledProvider).asData?.value;
    if (enabled == false) return null;

    final ctrl = ref.watch(iptvControllerProvider);
    final panelOpen = ctrl.portalPanelOpen;
    return IptvPortalsTopBarButton(
      ctrl: ctrl,
      onTogglePanel: () {
        final opening = !ctrl.portalPanelOpen;
        ctrl.togglePortalPanel();
        if (opening) iptvClaimPortalListFocus(ctrl);
      },
      tvTabId: tabId,
      tvRowId: rowId,
      tvItemIndex: itemIndex,
      onLeftEdge: onLeftEdge,
      onRightEdge: panelOpen
          ? () => iptvClaimPortalListFocus(ctrl)
          : (onRightEdge ?? () {}),
      onDownEdge: panelOpen
          ? () => iptvClaimPortalListFocus(ctrl)
          : onDownEdge,
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
  return IptvForjaSportsGate.isForjaSportsEnabled();
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

  Future<void> _warnIfUnsupported(IptvController ctrl) async {
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
    _lastSyncedPortalKey = p.key;
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
          await _warnIfUnsupported(ctrl);
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
      unawaited(_warnIfUnsupported(next));
    });

    return SidePanelOverlay(
      open: ctrl.portalPanelOpen,
      panelWidth: _panelWidth,
      onDismiss: ctrl.closePortalPanel,
      panel: IptvPortalPanel(
        ctrl: ctrl,
        width: SidePanelOverlay.defaultUseSideRail(context)
            ? _panelWidth
            : MediaQuery.sizeOf(context).width * 0.92,
        onClose: ctrl.closePortalPanel,
      ),
      child: widget.child,
    );
  }
}
