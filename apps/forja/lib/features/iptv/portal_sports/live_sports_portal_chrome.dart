import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/portal_sports/iptv_portal_sports_config.dart';
import 'package:forja/features/iptv/providers/iptv_controller_provider.dart';
import 'package:forja/features/iptv/screens/iptv_catalog_workspace.dart';
import 'package:forja/features/iptv/screens/iptv_portals_top_bar_button.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/foundation/services/registry/kit_top_bar_host_hooks.dart';
import 'package:forja/shared/foundation/services/schedule/kit_live_boot.dart';

/// Live Sports top-bar **Portals** + side panel (same IPTV chrome).
///
/// Foundation stays pack-agnostic via [KitTopBarHostHooks]; this feature
/// module owns IPTV controller + [IptvPortalSportsConfig] sync.
abstract final class LiveSportsPortalChrome {
  LiveSportsPortalChrome._();

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
    // Pack default is on; hide only when explicitly disabled.
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
    return _LiveSportsPortalPanelHost(
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

class _LiveSportsPortalPanelHost extends ConsumerStatefulWidget {
  const _LiveSportsPortalPanelHost({
    required this.child,
    required this.shellTabVisible,
  });

  final Widget child;
  final bool shellTabVisible;

  @override
  ConsumerState<_LiveSportsPortalPanelHost> createState() =>
      _LiveSportsPortalPanelHostState();
}

class _LiveSportsPortalPanelHostState
    extends ConsumerState<_LiveSportsPortalPanelHost> {
  static const _panelWidth = 380.0;

  String? _lastSyncedPortalKey;
  bool _prepared = false;

  @override
  void didUpdateWidget(covariant _LiveSportsPortalPanelHost oldWidget) {
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

    if (!ctrl.portalPanelOpen) return widget.child;

    final wide = MediaQuery.sizeOf(context).width >= 900;
    final useSidePanel = wide || ShellTokens.isAndroidTvDevice;

    return Stack(
      children: [
        widget.child,
        if (useSidePanel)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: _panelWidth,
            child: IptvPortalPanel(
              ctrl: ctrl,
              width: _panelWidth,
              onClose: ctrl.closePortalPanel,
            ),
          )
        else
          Positioned.fill(
            child: GestureDetector(
              onTap: ctrl.closePortalPanel,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.45),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {},
                    child: IptvPortalPanel(
                      ctrl: ctrl,
                      width: MediaQuery.sizeOf(context).width * 0.92,
                      onClose: ctrl.closePortalPanel,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
