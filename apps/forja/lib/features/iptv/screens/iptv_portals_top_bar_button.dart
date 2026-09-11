import 'package:flutter/material.dart';
import 'package:forja/features/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/iptv_shell_style.dart';
import 'package:forja/shared/foundation/components/chrome/kit_portals_chip.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';

/// IPTV data adapter over [KitPortalsChip] (RFC-095).
class IptvPortalsTopBarButton extends StatefulWidget {
  const IptvPortalsTopBarButton({
    super.key,
    required this.ctrl,
    required this.onTogglePanel,
    this.compact = false,
    this.tvTabId,
    this.tvRowId,
    this.tvItemIndex,
    this.onLeftEdge,
    this.onRightEdge,
    this.onUpEdge,
    this.onDownEdge,
  });

  final IptvController ctrl;
  final VoidCallback onTogglePanel;
  final bool compact;
  final String? tvTabId;
  final String? tvRowId;
  final int? tvItemIndex;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;

  @override
  State<IptvPortalsTopBarButton> createState() =>
      _IptvPortalsTopBarButtonState();
}

class _IptvPortalsTopBarButtonState extends State<IptvPortalsTopBarButton> {
  bool _focused = false;
  bool _hovered = false;

  IptvController get ctrl => widget.ctrl;

  void _onFocus(bool focused) {
    _focused = focused;
    final p = ctrl.activePortal;
    if (p == null) return;
    if (focused) {
      ctrl.schedulePortalHealthCheck(p);
    } else if (!_hovered) {
      ctrl.cancelPortalHealthCheck(p.key);
    }
  }

  void _onHover(bool hovered) {
    _hovered = hovered;
    final p = ctrl.activePortal;
    if (p == null) return;
    if (hovered) {
      ctrl.schedulePortalHealthCheck(p);
    } else if (!_focused) {
      ctrl.cancelPortalHealthCheck(p.key);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final portal = ctrl.activePortal;
        final hasPortal = portal != null;
        final health =
            portal == null ? null : ctrl.portalHealthFor(portal.key);
        final checking =
            portal != null && ctrl.isPortalHealthChecking(portal.key);
        final label = portal?.displayLabel ?? 'Portals';

        return KitPortalsChip(
          label: label,
          onTap: widget.onTogglePanel,
          selected: ctrl.portalPanelOpen,
          hasPortal: hasPortal,
          checking: checking,
          healthy: health,
          seatsUsed: portal?.activeConnections,
          seatsMax: portal?.maxConnections,
          compact: widget.compact,
          accentColor: IptvShellStyle.accent,
          tvTabId: widget.tvTabId,
          tvRowId: widget.tvRowId,
          tvItemIndex: widget.tvItemIndex,
          tvZone: ShellTvZone.topBar,
          onLeftEdge: widget.onLeftEdge,
          onRightEdge: widget.onRightEdge,
          onUpEdge: widget.onUpEdge,
          onDownEdge: widget.onDownEdge,
          onFocusChange: _onFocus,
          onHoverChange: _onHover,
        );
      },
    );
  }
}
