import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Segment label for [SegmentedControl].
class SegmentedOption<T> {
  const SegmentedOption({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// Horizontal segmented control (single selection).
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<SegmentedOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(theme.radiusMd),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++)
            _Segment(
              option: options[i],
              selected: options[i].value == value,
              onTap: () => onChanged(options[i].value),
              isFirst: i == 0,
              isLast: i == options.length - 1,
            ),
        ],
      ),
    );
  }
}

class _Segment<T> extends StatefulWidget {
  const _Segment({
    required this.option,
    required this.selected,
    required this.onTap,
    required this.isFirst,
    required this.isLast,
  });

  final SegmentedOption<T> option;
  final bool selected;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  @override
  State<_Segment<T>> createState() => _SegmentState<T>();
}

class _SegmentState<T> extends State<_Segment<T>> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final radius = BorderRadius.horizontal(
      left: widget.isFirst ? Radius.circular(theme.radiusMd - 1) : Radius.zero,
      right: widget.isLast ? Radius.circular(theme.radiusMd - 1) : Radius.zero,
    );
    final active = ShellPaintScope.interactiveActive(
      context,
      hovered: _hovered,
      focused: _focused,
    );
    return ForjaMotionScale(
      preset: ForjaMotionPreset.chipLift,
      active: active,
      child: Material(
        color: widget.selected
            ? ForjaShellColors.chipSelectedBg
            : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: radius,
          onHover: (h) => setState(() => _hovered = h),
          onFocusChange: (f) => setState(() => _focused = f),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spaceMd,
              vertical: theme.spaceSm + 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.option.icon != null) ...[
                  Icon(
                    widget.option.icon,
                    size: 16,
                    color: widget.selected
                        ? theme.textPrimary
                        : theme.textSecondary,
                  ),
                  SizedBox(width: theme.spaceSm / 2),
                ],
                Text(
                  widget.option.label,
                  style: TextStyle(
                    color: widget.selected
                        ? theme.textPrimary
                        : theme.textSecondary,
                    fontSize: 13,
                    fontWeight:
                        widget.selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
