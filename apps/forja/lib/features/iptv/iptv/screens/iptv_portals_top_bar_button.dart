import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/features/iptv/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';
import 'package:forja/features/iptv/iptv/iptv_tv_focus.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';

/// IPTV-style Portals chip (top-right). Shared by IPTV catalog + Live Matches.
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
  final VoidCallback? onDownEdge;

  @override
  State<IptvPortalsTopBarButton> createState() =>
      _IptvPortalsTopBarButtonState();
}

class _IptvPortalsTopBarButtonState extends State<IptvPortalsTopBarButton> {
  static const _height = 40.0;
  static const _radius = 8.0;

  bool _focused = false;
  bool _hovered = false;

  IptvController get ctrl => widget.ctrl;

  String get _portalLabel {
    final p = ctrl.activePortal;
    if (p == null) return 'Portals';
    return p.displayLabel;
  }

  @override
  Widget build(BuildContext context) {
    final selected = ctrl.portalPanelOpen;
    final portal = ctrl.activePortal;
    final hasPortal = portal != null;
    final active = iptvFocusActive(
      context,
      hovered: _hovered,
      focused: _focused,
    );
    final tvFocused = iptvTvFocused(context, focused: _focused);
    final showHighlight = selected || active;
    final revealSeats = hasPortal && (_hovered || _focused);
    final health = portal == null ? null : ctrl.portalHealthFor(portal.key);
    final checking =
        portal != null && ctrl.isPortalHealthChecking(portal.key);

    final minW = widget.compact ? _height : 156.0;
    final maxW = widget.compact
        ? (revealSeats ? 96.0 : _height)
        : (revealSeats ? 300.0 : 260.0);
    final chipRadius = BorderRadius.circular(_radius);
    final borderColor = tvFocused
        ? ForjaShellColors.brandGreen
        : !hasPortal
            ? IptvShellStyle.accent.withValues(alpha: 0.65)
            : Colors.white.withValues(alpha: showHighlight ? 0.28 : 0.10);
    final borderW = tvFocused ? 1.5 : 1.0;
    final side = BorderSide(color: borderColor, width: borderW);

    return Align(
      alignment: Alignment.centerRight,
      child: iptvTap(
        context: context,
        onTap: widget.onTogglePanel,
        borderRadius: _radius,
        tvZone: ShellTvZone.topBar,
        tvTabId: widget.tvTabId,
        tvRowId: widget.tvRowId,
        tvItemIndex: widget.tvItemIndex,
        onLeftEdge: widget.onLeftEdge,
        onRightEdge: widget.onRightEdge,
        onDownEdge: widget.onDownEdge,
        onFocusChange: (focused) {
          setState(() => _focused = focused);
          final p = ctrl.activePortal;
          if (p == null) return;
          if (focused) {
            ctrl.schedulePortalHealthCheck(p);
          } else if (!_hovered) {
            ctrl.cancelPortalHealthCheck(p.key);
          }
        },
        onHoverChange: (hovered) {
          setState(() => _hovered = hovered);
          final p = ctrl.activePortal;
          if (p == null) return;
          if (hovered) {
            ctrl.schedulePortalHealthCheck(p);
          } else if (!_focused) {
            ctrl.cancelPortalHealthCheck(p.key);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: _height,
          constraints: BoxConstraints(minWidth: minW, maxWidth: maxW),
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 10 : 14),
          decoration: BoxDecoration(
            color: tvFocused
                ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
                : showHighlight
                    ? Colors.white.withValues(alpha: selected ? 0.14 : 0.10)
                    : Colors.white.withValues(alpha: 0.06),
            borderRadius: chipRadius,
            border: Border.fromBorderSide(side),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (portal != null)
                ClipRect(
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerRight,
                    widthFactor: revealSeats ? 1 : 0,
                    child: Padding(
                      padding: EdgeInsets.only(right: widget.compact ? 6 : 8),
                      child: _seats(
                        active: portal.activeConnections,
                        max: portal.maxConnections,
                      ),
                    ),
                  ),
                ),
              SizedBox(
                width: 14,
                height: 14,
                child: Center(
                  child: portal != null
                      ? _statusDot(checking: checking, health: health)
                      : Icon(
                          Icons.add_link_rounded,
                          size: 16,
                          color: iptvFocusFg(
                            IptvShellStyle.accent,
                            active: active,
                            tvFocused: tvFocused,
                          ),
                        ),
                ),
              ),
              if (!widget.compact) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _portalLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: iptvFocusFg(
                        Colors.white,
                        active: active,
                        tvFocused: tvFocused,
                      ),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  selected
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: iptvFocusFg(
                    Colors.white60,
                    active: active,
                    tvFocused: tvFocused,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusDot({required bool checking, required bool? health}) {
    if (checking) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: Colors.white54,
        ),
      );
    }
    final color = health == true
        ? playerSourceStatusColor(PlayerSourceStatus.active)
        : health == false
            ? playerSourceStatusColor(PlayerSourceStatus.failed)
            : playerSourceStatusColor(PlayerSourceStatus.unchecked);
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _seats({required String active, required String max}) {
    final used = active.trim().isEmpty ? '0' : active.trim();
    final cap = max.trim().isEmpty ? '?' : max.trim();
    final activeN = int.tryParse(used);
    final maxN = int.tryParse(cap);
    final full = activeN != null && maxN != null && maxN > 0 && activeN >= maxN;
    final color = full ? const Color(0xFFFBBF24) : const Color(0xFF22C55E);
    return Text(
      '$used/$cap',
      maxLines: 1,
      style: GoogleFonts.plusJakartaSans(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    );
  }
}
