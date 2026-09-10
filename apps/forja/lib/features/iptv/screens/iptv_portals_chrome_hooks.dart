import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/iptv/channel_search/iptv_forja_sports_gate.dart';
import 'package:forja/features/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/iptv_tv_focus.dart';
import 'package:forja/features/iptv/providers/iptv_controller_provider.dart';
import 'package:forja/features/iptv/screens/iptv_catalog_workspace.dart';
import 'package:forja/features/iptv/screens/iptv_portals_top_bar_button.dart';
import 'package:forja/shared/foundation/components/chrome/kit_schedule_event_search.dart';
import 'package:forja/shared/foundation/components/panel/kit_side_panel_overlay.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/foundation/services/registry/kit_top_bar_host_hooks.dart';
import 'package:forja/shared/foundation/services/schedule/kit_live_boot.dart';
import 'package:forja/shared/foundation/services/schedule/kit_schedule_layout.dart';
import 'package:forja/shared/foundation/services/schedule/kit_schedule_prefs.dart';
import 'package:forja/shared/foundation/tv/shell_tv_coordinator.dart';

/// Registers event Search + List/Cards + Portals chip on kit tabs that use
/// [KitLiveBoot.listSourceId].
///
/// Design: [KitScheduleEventSearch] / [KitPortalsChip] / [KitSidePanelOverlay].
/// Data: IPTV controller + pack `forjaSportsEnabled` gate for Portals (RFC-096).
abstract final class IptvPortalsChromeHooks {
  IptvPortalsChromeHooks._();

  static void ensureRegistered() {
    KitTopBarHostHooks.buildTrailingCluster = _buildTrailingCluster;
    KitTopBarHostHooks.wrapListBody = _wrapListBody;
  }

  static List<Widget> _buildTrailingCluster(
    BuildContext context,
    WidgetRef ref, {
    required String tabId,
    required String rowId,
    required int startIndex,
    VoidCallback? onDownEdge,
  }) {
    final enabled = ref.watch(_forjaSportsEnabledProvider).asData?.value;
    final showPortals = enabled != false;
    final searchIndex = startIndex;
    final viewIndex = startIndex + 1;
    final portalsIndex = startIndex + 2;
    final style = ref.watch(kitScheduleLayoutProvider);
    final isCards = style == KitSchedulePrefs.styleCards;

    final out = <Widget>[
      KitScheduleEventSearch(
        tabId: tabId,
        rowId: rowId,
        itemIndex: searchIndex,
        onDownEdge: onDownEdge,
        onRightEdge: () => ShellTvFocusCoordinator.focusRowItem(
              tabId,
              rowId,
              viewIndex,
            ),
      ),
      _ScheduleViewIconButton(
        isCards: isCards,
        tvTabId: tabId,
        tvRowId: rowId,
        tvItemIndex: viewIndex,
        onDownEdge: onDownEdge,
        onLeftEdge: () => ShellTvFocusCoordinator.focusRowItem(
              tabId,
              rowId,
              searchIndex,
            ),
        onRightEdge: showPortals
            ? () => ShellTvFocusCoordinator.focusRowItem(
                  tabId,
                  rowId,
                  portalsIndex,
                )
            : () {},
        onTap: () {
          unawaited(
            ref.read(kitScheduleLayoutProvider.notifier).toggleStyle(),
          );
        },
      ),
    ];
    if (!showPortals) return out;

    final ctrl = ref.watch(iptvControllerProvider);
    final panelOpen = ctrl.portalPanelOpen;
    out.add(
      IptvPortalsTopBarButton(
        ctrl: ctrl,
        onTogglePanel: () {
          final opening = !ctrl.portalPanelOpen;
          ctrl.togglePortalPanel();
          // Same as IPTV hub: OK on Portals lands D-pad on the selected portal.
          if (opening) iptvClaimPortalListFocus(ctrl);
        },
        tvTabId: tabId,
        tvRowId: rowId,
        tvItemIndex: portalsIndex,
        onLeftEdge: () => ShellTvFocusCoordinator.focusRowItem(
              tabId,
              rowId,
              viewIndex,
            ),
        // When closed, trap → at the chrome edge. When open, enter the list
        // (IPTV hub Portals chip does the same via iptvFocusPortalList).
        onRightEdge: panelOpen ? () => iptvClaimPortalListFocus(ctrl) : () {},
        onDownEdge: panelOpen
            ? () => iptvClaimPortalListFocus(ctrl)
            : onDownEdge,
      ),
    );
    return out;
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

/// Icon-only List/Cards toggle — same 40px circle chrome as event Search.
class _ScheduleViewIconButton extends StatefulWidget {
  const _ScheduleViewIconButton({
    required this.isCards,
    required this.onTap,
    this.tvTabId,
    this.tvRowId,
    this.tvItemIndex,
    this.onLeftEdge,
    this.onRightEdge,
    this.onDownEdge,
  });

  final bool isCards;
  final VoidCallback onTap;
  final String? tvTabId;
  final String? tvRowId;
  final int? tvItemIndex;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onDownEdge;

  @override
  State<_ScheduleViewIconButton> createState() =>
      _ScheduleViewIconButtonState();
}

class _ScheduleViewIconButtonState extends State<_ScheduleViewIconButton> {
  static const _size = 40.0;

  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final active = ShellInputPolicy.interactiveActive(
      policy,
      hovered: _hovered,
      focused: _focused,
      context: context,
    );
    final tv = policy.useFocusableMoodChips;
    final tvFocused = tv && _focused;
    final tip = widget.isCards ? 'Cards view' : 'List view';
    final icon =
        widget.isCards ? Icons.grid_view_rounded : Icons.view_list_rounded;

    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: _size / 2,
      scaleOnFocus: 1.0,
      suppressInkHover: true,
      showFocusFill: false,
      tvTabId: widget.tvTabId,
      tvRowId: widget.tvRowId,
      tvItemIndex: widget.tvItemIndex,
      tvZone: ShellTvZone.topBar,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onDownEdge: widget.onDownEdge,
      onUpEdge: () {},
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: (h) => setState(() => _hovered = h),
      child: Tooltip(
        message: tip,
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: active || tvFocused ? 0.16 : 0.08,
            ),
            borderRadius: BorderRadius.circular(_size / 2),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: tvFocused
                    ? 0.45
                    : active
                        ? 0.28
                        : 0.12,
              ),
              width: tvFocused ? 1.5 : 1,
            ),
          ),
          child: Icon(
            icon,
            color: active || tvFocused ? Colors.white : Colors.white60,
            size: 20,
          ),
        ),
      ),
    );
  }
}
