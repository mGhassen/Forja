import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/shared/foundation/primitives/shell/forja_shell_scope.dart';
import 'package:forja/shared/foundation/primitives/shell/forja_shell_input_policy.dart';
import 'package:forja/shared/foundation/primitives/chrome/shell_focusable_tap.dart';
import 'package:forja/shared/foundation/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/player/controls/menus/player_popup_panel.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Presentational Portals chip — props only (RFC-095).
///
/// Features map portal label / health / seats into these fields.
class KitPortalsChip extends StatefulWidget {
  const KitPortalsChip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.hasPortal = false,
    this.checking = false,
    this.healthy,
    this.seatsUsed,
    this.seatsMax,
    this.compact = false,
    this.accentColor,
    this.tvTabId,
    this.tvRowId,
    this.tvItemIndex,
    this.tvZone = ShellTvZone.topBar,
    this.onLeftEdge,
    this.onRightEdge,
    this.onUpEdge,
    this.onDownEdge,
    this.onFocusChange,
    this.onHoverChange,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool hasPortal;
  final bool checking;
  /// `true` ok · `false` failed · `null` unchecked / unknown.
  final bool? healthy;
  final String? seatsUsed;
  final String? seatsMax;
  final bool compact;
  final Color? accentColor;
  final String? tvTabId;
  final String? tvRowId;
  final int? tvItemIndex;
  final ShellTvZone? tvZone;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final ValueChanged<bool>? onFocusChange;
  final ValueChanged<bool>? onHoverChange;

  @override
  State<KitPortalsChip> createState() => _KitPortalsChipState();
}

class _KitPortalsChipState extends State<KitPortalsChip> {
  static const _height = 40.0;
  static const _radius = 8.0;

  bool _focused = false;
  bool _hovered = false;

  Color get _accent => widget.accentColor ?? ForjaShellColors.brandGreen;

  bool get _revealSeats =>
      widget.hasPortal && (_hovered || _focused);

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final active = ShellInputPolicy.interactiveActive(
      policy,
      hovered: _hovered,
      focused: _focused,
      context: context,
    );
    final tvFocus = policy.useFocusableMoodChips;
    final tvFocused = tvFocus && _focused;
    final showHighlight = widget.selected || active;

    final minW = widget.compact ? _height : 156.0;
    final maxW = widget.compact
        ? (_revealSeats ? 96.0 : _height)
        : (_revealSeats ? 300.0 : 260.0);
    final chipRadius = BorderRadius.circular(_radius);
    final borderColor = tvFocused
        ? ForjaShellColors.brandGreen
        : !widget.hasPortal
            ? _accent.withValues(alpha: 0.65)
            : Colors.white.withValues(alpha: showHighlight ? 0.28 : 0.10);
    final borderW = tvFocused ? 1.5 : 1.0;
    final side = BorderSide(color: borderColor, width: borderW);
    final fg = tvFocused
        ? ForjaShellColors.brandGreen
        : active
            ? Colors.white
            : Colors.white;
    final fgMuted = tvFocused
        ? ForjaShellColors.brandGreen
        : active
            ? Colors.white
            : Colors.white60;

    // Size to chip only (no Align fill). Expanding seats must shrink the
    // trailing Spacer — not paint over Search / view icons to the left.
    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: _radius,
      tvZone: widget.tvZone,
      tvTabId: widget.tvTabId,
      tvRowId: widget.tvRowId,
      tvItemIndex: widget.tvItemIndex,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onUpEdge: widget.onUpEdge,
      onDownEdge: widget.onDownEdge,
      onFocusChange: (focused) {
        setState(() => _focused = focused);
        widget.onFocusChange?.call(focused);
      },
      onHoverChange: (hovered) {
        setState(() => _hovered = hovered);
        widget.onHoverChange?.call(hovered);
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
                  ? Colors.white
                      .withValues(alpha: widget.selected ? 0.14 : 0.10)
                  : Colors.white.withValues(alpha: 0.06),
          borderRadius: chipRadius,
          border: Border.fromBorderSide(side),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.hasPortal)
              ClipRect(
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerRight,
                  widthFactor: _revealSeats ? 1 : 0,
                  child: Padding(
                    padding: EdgeInsets.only(right: widget.compact ? 6 : 8),
                    child: _seats(),
                  ),
                ),
              ),
            SizedBox(
              width: 14,
              height: 14,
              child: Center(
                child: widget.hasPortal
                    ? _statusDot()
                    : Icon(
                        Icons.add_link_rounded,
                        size: 16,
                        color: tvFocused
                            ? ForjaShellColors.brandGreen
                            : active
                                ? Colors.white
                                : _accent,
                      ),
              ),
            ),
            if (!widget.compact) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: fg,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                widget.selected
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
                color: fgMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusDot() {
    if (widget.checking) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: playerSourceStatusColor(PlayerSourceStatus.checking),
        ),
      );
    }
    final color = widget.healthy == true
        ? playerSourceStatusColor(PlayerSourceStatus.active)
        : widget.healthy == false
            ? playerSourceStatusColor(PlayerSourceStatus.failed)
            : playerSourceStatusColor(PlayerSourceStatus.unchecked);
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _seats() {
    final used = (widget.seatsUsed ?? '').trim().isEmpty
        ? '0'
        : widget.seatsUsed!.trim();
    final cap = (widget.seatsMax ?? '').trim().isEmpty
        ? '?'
        : widget.seatsMax!.trim();
    final activeN = int.tryParse(used);
    final maxN = int.tryParse(cap);
    final full =
        activeN != null && maxN != null && maxN > 0 && activeN >= maxN;
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
