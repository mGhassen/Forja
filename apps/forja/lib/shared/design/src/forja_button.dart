import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/shell_scope.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';

/// Visual tone for [ForjaButton].
///
/// All tones share the same rectangle + small-radius + border language; only the
/// accent (border / text / subtle fill) changes.
enum ForjaButtonVariant {
  /// Brand-green accent - the affirmative / save action.
  primary,

  /// Neutral chrome accent - the default secondary action.
  neutral,

  /// Red accent - destructive / logout / remove actions.
  destructive,
}

/// Canonical Forja action button.
///
/// Rectangle with a small corner radius, a hairline border, and a lightly
/// tinted (not saturated) fill. This is the shared component to use everywhere
/// **except** the cinematic hero pill CTAs (`HeroPillPlayButton` & friends),
/// which are a separate glass system.
class ForjaButton extends StatefulWidget {
  const ForjaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = ForjaButtonVariant.neutral,
    this.busy = false,
    this.expand = false,
    this.height = 44,
    this.autofocus = false,
    this.focusNode,
  });

  /// Brand-green affirmative action.
  const ForjaButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = false,
    this.height = 44,
    this.autofocus = false,
    this.focusNode,
  }) : variant = ForjaButtonVariant.primary;

  /// Red destructive action.
  const ForjaButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = false,
    this.height = 44,
    this.autofocus = false,
    this.focusNode,
  }) : variant = ForjaButtonVariant.destructive;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ForjaButtonVariant variant;
  final bool busy;

  /// Fill the parent's width and center the content. When false the button
  /// hugs its content.
  final bool expand;
  final double height;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<ForjaButton> createState() => _ForjaButtonState();
}

class _ForjaButtonState extends State<ForjaButton> {
  bool _hovered = false;
  bool _focused = false;

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(8));

  Color get _accent => switch (widget.variant) {
        ForjaButtonVariant.primary => ForjaShellColors.brandGreen,
        ForjaButtonVariant.destructive => const Color(0xFFF87171),
        ForjaButtonVariant.neutral => ForjaShellColors.textPrimary,
      };

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final tvFocus =
        ShellScope.maybeOf(context)?.inputPolicy.useFocusableMoodChips ?? false;
    final ownFocus =
        tvFocus || ShellTvLinearFocusScope.activeOf(context);
    final active = _hovered || _focused;
    final accent = _accent;

    final Color fill;
    final Color border;
    final Color foreground;

    if (!enabled) {
      fill = Colors.transparent;
      border = ForjaShellColors.borderSubtle;
      foreground = ForjaShellColors.textSecondary.withValues(alpha: 0.45);
    } else if (widget.variant == ForjaButtonVariant.primary) {
      // Solid brand-green fill with dark text for maximum legibility.
      fill = active
          ? const Color(0xFF3CEF98) // slightly brighter on hover/focus
          : ForjaShellColors.brandGreen;
      border = fill;
      foreground = const Color(0xFF06130D);
    } else if (widget.variant == ForjaButtonVariant.neutral) {
      fill = Colors.white.withValues(alpha: active ? 0.06 : 0.03);
      border = active
          ? ForjaShellColors.textPrimary.withValues(alpha: 0.45)
          : ForjaShellColors.ghostBorder;
      foreground = ForjaShellColors.textPrimary;
    } else {
      // Destructive - tinted fill + red border/text.
      fill = accent.withValues(alpha: active ? 0.20 : 0.12);
      border = accent.withValues(alpha: active ? 0.95 : 0.55);
      foreground = accent;
    }

    final Widget content = widget.busy
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: foreground),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          );

    final core = Material(
      color: fill,
      borderRadius: _radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? widget.onPressed : null,
        onHover: (v) => setState(() => _hovered = v),
        onFocusChange: ownFocus ? null : (v) => setState(() => _focused = v),
        // TV / linear menus: parent [Focus] owns the node so D-pad does not
        // leak via InkWell geometry to siblings outside the pane.
        canRequestFocus: !ownFocus,
        focusNode: ownFocus ? null : widget.focusNode,
        autofocus: ownFocus ? false : widget.autofocus,
        borderRadius: _radius,
        hoverColor: Colors.transparent,
        child: Container(
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: _radius,
            border: Border.all(color: border, width: 1.5),
          ),
          child: content,
        ),
      ),
    );

    final sized =
        widget.expand ? SizedBox(width: double.infinity, child: core) : core;

    if (!ownFocus) return sized;

    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        final linearScope = ShellTvLinearFocusScope.activeOf(context) &&
            !ShellTvDisableLinearFocus.activeOf(context);
        if (linearScope) {
          final linear = shellTvLinearMenuArrows(context: context, event: event);
          if (linear == KeyEventResult.handled) return linear;
          if (shellTvIsNavigationKey(event)) {
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.arrowUp ||
                key == LogicalKeyboardKey.arrowDown ||
                key == LogicalKeyboardKey.arrowLeft ||
                key == LogicalKeyboardKey.arrowRight) {
              return KeyEventResult.handled;
            }
          }
        } else if (shellTvIsNavigationKey(event)) {
          final key = event.logicalKey;
          TraversalDirection? direction;
          if (key == LogicalKeyboardKey.arrowLeft) {
            direction = TraversalDirection.left;
          } else if (key == LogicalKeyboardKey.arrowRight) {
            direction = TraversalDirection.right;
          } else if (key == LogicalKeyboardKey.arrowUp) {
            direction = TraversalDirection.up;
          } else if (key == LogicalKeyboardKey.arrowDown) {
            direction = TraversalDirection.down;
          }
          final focusNode = widget.focusNode ?? node;
          if (direction != null && focusNode.focusInDirection(direction)) {
            return KeyEventResult.handled;
          }
        }
        if (enabled && shellTvIsActivateKey(event)) {
          widget.onPressed!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: sized,
    );
  }
}
