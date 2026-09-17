import 'package:flutter/material.dart';
import 'package:forja_foundation/components/focusable_tap.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
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
    this.width,
    this.height = ShellTokens.portalsChipHeight,
    this.radius = ShellTokens.portalsChipRadius,
    this.pad,
    this.fontSize = ShellTokens.portalsChipFontSize,
    this.iconSize = ShellTokens.portalsChipIconSize,
    this.chevronSize = ShellTokens.portalsChipChevronSize,
    this.seatsFontSize = ShellTokens.portalsChipSeatsFontSize,
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

  /// Pack-owned min width. Omit → intrinsic (compact idle = square).
  /// Seats / long labels may still grow past this.
  final double? width;
  final double height;
  final double radius;

  /// Horizontal padding. Null → compact ? [ShellTokens.portalsChipPadCompact] :
  /// [ShellTokens.portalsChipPad].
  final double? pad;
  final double fontSize;
  final double iconSize;
  final double chevronSize;
  final double seatsFontSize;
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
  bool _focused = false;
  bool _hovered = false;

  Color get _accent => widget.accentColor ?? ForjaShellColors.brandGreen;

  bool get _chromeActive => ShellPaintScope.interactiveActive(
        context,
        hovered: _hovered,
        focused: _focused,
      );

  bool get _revealSeats => widget.hasPortal && _chromeActive;

  bool get _active => _chromeActive;

  Color _statusColor() {
    if (widget.checking) return const Color(0xFF38BDF8);
    if (widget.healthy == true) return ForjaShellColors.brandGreen;
    if (widget.healthy == false) return const Color(0xFFEF4444);
    return const Color(0x3DFFFFFF);
  }

  @override
  Widget build(BuildContext context) {
    final tvFocused = widget.tvFocus &&
        ShellPaintScope.focusStyledOf(context, focused: _focused);
    final showHighlight = widget.selected || _active;

    final chipRadius = BorderRadius.circular(widget.radius);
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
    final hPad = widget.pad ??
        (widget.compact
            ? ShellTokens.portalsChipPadCompact
            : ShellTokens.portalsChipPad);
    final packWidth = widget.width;
    final minW = packWidth ??
        (widget.compact && !_revealSeats ? widget.height : 0.0);
    // Pack body column (inside pads). Seats prepend left of this so the chip
    // grows left while the body/chevron right edge stays put.
    final bodyW = packWidth != null ? (packWidth - hPad * 2) : null;
    final labelMax = bodyW != null
        ? (bodyW -
                ShellTokens.portalsChipStatusSlot -
                ShellTokens.portalsChipGap -
                widget.chevronSize)
            .clamp(
              ShellTokens.portalsChipLabelMaxMin,
              ShellTokens.portalsChipLabelMaxMax,
            )
        : ShellTokens.portalsChipLabelMaxFallback;

    final labelText = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(
        color: fg,
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    );

    final status = SizedBox(
      width: ShellTokens.portalsChipStatusSlot,
      height: ShellTokens.portalsChipStatusSlot,
      child: Center(
        child: widget.hasPortal
            ? _statusDot()
            : Icon(
                Icons.add_link_rounded,
                size: widget.iconSize,
                color: tvFocused
                    ? ForjaShellColors.brandGreen
                    : _active
                        ? Colors.white
                        : _accent,
              ),
      ),
    );

    final chevron = Icon(
      widget.selected
          ? Icons.expand_less_rounded
          : Icons.expand_more_rounded,
      size: widget.chevronSize,
      color: fgMuted,
    );

    // Body: status + label + chevron (chevron flush right when pack width set).
    final Widget body;
    if (widget.compact) {
      body = status;
    } else if (bodyW != null) {
      body = SizedBox(
        width: bodyW,
        child: Row(
          children: [
            status,
            const SizedBox(width: ShellTokens.portalsChipGap),
            Expanded(child: labelText),
            chevron,
          ],
        ),
      );
    } else {
      body = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          status,
          const SizedBox(width: ShellTokens.portalsChipGap),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: labelMax),
            child: labelText,
          ),
          const SizedBox(width: ShellTokens.portalsChipGapTight),
          chevron,
        ],
      );
    }

    final fill = ForjaMotionTheme.of(context).fillOnly;
    // Seats prepend left of [body]; AnimatedSize centerRight keeps the chip's
    // right edge fixed (Search/Sort shift left).
    final chip = AnimatedSize(
      duration: fill.duration,
      curve: fill.resolvedCurve,
      alignment: Alignment.centerRight,
      child: AnimatedContainer(
        duration: fill.duration,
        curve: fill.resolvedCurve,
        height: widget.height,
        constraints: BoxConstraints(minWidth: minW),
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
              SizedBox(
                width: widget.compact
                    ? ShellTokens.portalsChipGapTight
                    : ShellTokens.portalsChipGap,
              ),
            ],
            body,
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
    // Always spin while probing — including soft-refresh after a known
    // green/red (otherwise the pin looks frozen on hover recheck).
    if (widget.checking) {
      return SizedBox(
        width: ShellTokens.portalsChipStatusSlot,
        height: ShellTokens.portalsChipStatusSlot,
        child: CircularProgressIndicator(
          strokeWidth: ShellTokens.portalsChipStatusStroke,
          color: _statusColor(),
        ),
      );
    }
    return Container(
      width: ShellTokens.portalsChipDotSize,
      height: ShellTokens.portalsChipDotSize,
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
        fontSize: widget.seatsFontSize,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    );
  }
}
