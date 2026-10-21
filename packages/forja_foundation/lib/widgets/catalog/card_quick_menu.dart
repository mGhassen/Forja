import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/card_quick_menu_tokens.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:google_fonts/google_fonts.dart';

/// One quick-menu row — presentational only (RFC-095). The host decides
/// which actions exist for a card and what they do.
class CardQuickMenuAction {
  const CardQuickMenuAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  /// Stable key for tests / telemetry (e.g. `play`, `details`, `list`).
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// Where the menu sits relative to the card it was opened from.
///
/// Prefers the trailing side of [anchor]; flips to the leading side when
/// that overflows; clamps inside [screen] minus the edge margin. Pure so the
/// host overlay and tests share one rule.
Offset cardQuickMenuOrigin({
  required Rect anchor,
  required Size menu,
  required Size screen,
  required bool tv,
}) {
  final gap = CardQuickMenuTokens.anchorGapOf(tv);
  final margin = CardQuickMenuTokens.screenMarginOf(tv);
  final maxX = screen.width - margin - menu.width;
  final maxY = screen.height - margin - menu.height;

  var x = anchor.right + gap;
  if (x > maxX) {
    x = anchor.left - gap - menu.width;
  }
  if (x < margin) {
    // Neither side fits — centre on the card, then clamp.
    x = anchor.center.dx - menu.width / 2;
  }
  x = x.clamp(margin, maxX < margin ? margin : maxX);

  var y = anchor.top;
  y = y.clamp(margin, maxY < margin ? margin : maxY);
  return Offset(x, y);
}

/// [CustomSingleChildLayout] delegate that applies [cardQuickMenuOrigin].
class CardQuickMenuLayoutDelegate extends SingleChildLayoutDelegate {
  const CardQuickMenuLayoutDelegate({required this.anchor, required this.tv});

  final Rect anchor;
  final bool tv;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) => cardQuickMenuOrigin(
    anchor: anchor,
    menu: childSize,
    screen: size,
    tv: tv,
  );

  @override
  bool shouldRelayout(covariant CardQuickMenuLayoutDelegate oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.tv != tv;
}

/// Catalog card quick menu — decorated action column (no overlay chrome).
///
/// Props + callbacks only. On TV the rows are host focusables via
/// [ShellPaintScope.focusableTap]; the first row autofocuses when
/// [autoFocusFirst] is set so OK acts immediately after the hold opens it.
class CardQuickMenu extends StatelessWidget {
  const CardQuickMenu({
    super.key,
    required this.actions,
    this.title,
    this.tvFocus = false,
    this.autoFocusFirst = false,
  });

  final List<CardQuickMenuAction> actions;

  /// Card name shown above the actions (omitted when blank).
  final String? title;
  final bool tvFocus;
  final bool autoFocusFirst;

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final heading = (title ?? '').trim();
    // Host FocusableControl breaks IntrinsicWidth through Transform; pin a
    // min width that fits the longest label ("Remove from My List").
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: CardQuickMenuTokens.minWidthOf(tv),
        maxWidth: CardQuickMenuTokens.maxWidthOf(tv),
      ),
      child: IntrinsicWidth(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ForjaShellColors.cinematic.menuSurface.withValues(
              alpha: CardQuickMenuTokens.surfaceAlpha,
            ),
            borderRadius: BorderRadius.circular(
              CardQuickMenuTokens.radiusOf(tv),
            ),
            border: Border.all(
              color: ForjaShellColors.textPrimary.withValues(
                alpha: CardQuickMenuTokens.borderAlpha,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: CardQuickMenuTokens.shadowAlpha,
                ),
                blurRadius: CardQuickMenuTokens.shadowBlur,
                offset: const Offset(0, CardQuickMenuTokens.shadowOffsetY),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: CardQuickMenuTokens.padVOf(tv),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (heading.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(
                      left: CardQuickMenuTokens.rowPadHOf(tv),
                      right: CardQuickMenuTokens.rowPadHOf(tv),
                      bottom: CardQuickMenuTokens.titlePadBOf(tv),
                    ),
                    child: Text(
                      heading,
                      maxLines: CardQuickMenuTokens.titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: CardQuickMenuTokens.titleFontSizeOf(tv),
                        fontWeight: FontWeight.w600,
                        color: ForjaShellColors.textSecondary,
                      ),
                    ),
                  ),
                for (var i = 0; i < actions.length; i++)
                  CardQuickMenuRow(
                    action: actions[i],
                    tvFocus: tvFocus,
                    autoFocus: autoFocusFirst && tvFocus && i == 0,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon + label row. Hover / D-pad focus gets the brand tint.
class CardQuickMenuRow extends StatefulWidget {
  const CardQuickMenuRow({
    super.key,
    required this.action,
    required this.tvFocus,
    this.autoFocus = false,
  });

  final CardQuickMenuAction action;
  final bool tvFocus;
  final bool autoFocus;

  @override
  State<CardQuickMenuRow> createState() => _CardQuickMenuRowState();
}

class _CardQuickMenuRowState extends State<CardQuickMenuRow> {
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _focused = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool h) {
    if (_hoveredN.value == h) return;
    _hoveredN.value = h;
  }

  bool _active(bool hovered) => hovered || (widget.tvFocus && _focused);

  Widget _row(bool active) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final accent = active
        ? ForjaShellColors.brandGreen
        : ForjaShellColors.textPrimary;
    final motion = ForjaMotionTheme.of(context).fillOnly;
    return AnimatedContainer(
      duration: motion.duration,
      curve: motion.resolvedCurve,
      padding: EdgeInsets.symmetric(
        horizontal: CardQuickMenuTokens.rowPadHOf(tv),
        vertical: CardQuickMenuTokens.rowPadVOf(tv),
      ),
      color: active
          ? ForjaShellColors.brandGreen.withValues(
              alpha: CardQuickMenuTokens.activeFillAlpha,
            )
          : Colors.transparent,
      child: Row(
        children: [
          Icon(
            widget.action.icon,
            size: CardQuickMenuTokens.iconSizeOf(tv),
            color: accent,
          ),
          SizedBox(width: CardQuickMenuTokens.gapOf(tv)),
          Expanded(
            child: Text(
              widget.action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: CardQuickMenuTokens.labelFontSizeOf(tv),
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = ListenableBuilder(
      listenable: _hoveredN,
      builder: (context, _) => _row(_active(_hoveredN.value)),
    );

    if (!widget.tvFocus) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: GestureDetector(
          onTap: widget.action.onTap,
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      );
    }

    // Host FocusableControl (via ShellPaintScope) owns Select → onTap.
    return ShellPaintScope.focusableTap(
      context: context,
      onTap: widget.action.onTap,
      autoFocus: widget.autoFocus,
      borderRadius: 0,
      motion: ForjaMotionPreset.fillOnly,
      showFocusFill: false,
      showFocusBorder: false,
      suppressInkHover: true,
      onFocusChange: (f) {
        if (_focused == f) return;
        setState(() => _focused = f);
      },
      onHoverChange: _setHovered,
      child: content,
    );
  }
}
