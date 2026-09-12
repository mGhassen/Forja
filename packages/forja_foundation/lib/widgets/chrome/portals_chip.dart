import 'package:flutter/material.dart';
import 'package:forja_foundation/components/focusable_tap.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:google_fonts/google_fonts.dart';

/// Presentational Portals chip — props only (RFC-095 / Zone A).
///
/// Host maps portal label / health / seats and injects TV tap via
/// [interactiveBuilder].
class PortalsChip extends StatefulWidget {
  const PortalsChip({
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
    this.tvFocus = false,
    this.interactiveBuilder,
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
  final bool tvFocus;
  final ValueChanged<bool>? onFocusChange;
  final ValueChanged<bool>? onHoverChange;

  final Widget Function({
    required Widget child,
    required VoidCallback onTap,
    ValueChanged<bool>? onFocusChange,
    ValueChanged<bool>? onHoverChange,
  })? interactiveBuilder;

  @override
  State<PortalsChip> createState() => _PortalsChipState();
}

class _PortalsChipState extends State<PortalsChip> {
  static const _height = 40.0;
  static const _radius = 8.0;

  bool _focused = false;
  bool _hovered = false;

  Color get _accent => widget.accentColor ?? ForjaShellColors.brandGreen;

  bool get _revealSeats => widget.hasPortal && (_hovered || _focused);

  bool get _active =>
      widget.tvFocus ? _focused : (_hovered || _focused);

  Color _statusColor() {
    if (widget.checking) return const Color(0xFF38BDF8);
    if (widget.healthy == true) return ForjaShellColors.brandGreen;
    if (widget.healthy == false) return const Color(0xFFEF4444);
    return const Color(0x3DFFFFFF);
  }

  @override
  Widget build(BuildContext context) {
    final tvFocused = widget.tvFocus && _focused;
    final showHighlight = widget.selected || _active;

    final chipRadius = BorderRadius.circular(_radius);
    final borderColor = tvFocused
        ? ForjaShellColors.brandGreen
        : !widget.hasPortal
            ? _accent.withValues(alpha: 0.65)
            : Colors.white.withValues(alpha: showHighlight ? 0.28 : 0.10);
    final borderW = tvFocused ? 1.5 : 1.0;
    final side = BorderSide(color: borderColor, width: borderW);
    final fg = Colors.white;
    final fgMuted = tvFocused
        ? ForjaShellColors.brandGreen
        : _active
            ? Colors.white
            : Colors.white60;
    final hPad = widget.compact ? 10.0 : 14.0;

    // Intrinsic width only — no minWidth sponge. Seats add real layout width
    // so the trailing top-bar row pushes Search/Sort left (right edge stays).
    final chip = AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerRight,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: _height,
        // Compact idle stays a square hit target; seats widen past that.
        constraints: widget.compact && !_revealSeats
            ? const BoxConstraints(minWidth: _height)
            : const BoxConstraints(),
        padding: EdgeInsets.symmetric(horizontal: hPad),
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
            if (widget.hasPortal && _revealSeats) ...[
              _seats(),
              SizedBox(width: widget.compact ? 6 : 8),
            ],
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
                            : _active
                                ? Colors.white
                                : _accent,
                      ),
              ),
            ),
            if (!widget.compact) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
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

    void onFocus(bool focused) {
      setState(() => _focused = focused);
      widget.onFocusChange?.call(focused);
    }

    void onHover(bool hovered) {
      setState(() => _hovered = hovered);
      widget.onHoverChange?.call(hovered);
    }

    final wrap = widget.interactiveBuilder;
    if (wrap != null) {
      return wrap(
        child: chip,
        onTap: widget.onTap,
        onFocusChange: onFocus,
        onHoverChange: onHover,
      );
    }

    return FocusableTap(
      onTap: widget.onTap,
      borderRadius: chipRadius,
      child: chip,
    );
  }

  Widget _statusDot() {
    if (widget.checking) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: _statusColor(),
        ),
      );
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: _statusColor(), shape: BoxShape.circle),
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
