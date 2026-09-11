import 'package:flutter/material.dart' hide Radio, RadioGroup;
import 'package:flutter/material.dart' as material show Radio;
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Single radio option — use inside [RadioGroup] or with shared [groupValue].
class Radio<T> extends StatelessWidget {
  const Radio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.label,
    this.focusNode,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final radio = material.Radio<T>(
      // ignore: deprecated_member_use — Forja Radio keeps explicit groupValue API
      value: value,
      // ignore: deprecated_member_use
      groupValue: groupValue,
      // ignore: deprecated_member_use
      onChanged: onChanged,
      focusNode: focusNode,
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return theme.brandGreen;
        return theme.borderSubtle;
      }),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
    if (label == null) return radio;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(value),
      borderRadius: BorderRadius.circular(theme.radiusSm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          radio,
          SizedBox(width: theme.spaceSm),
          Flexible(
            child: Text(
              label!,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Controlled radio group — shared [value] / [onChanged].
///
/// Import with `hide RadioGroup` from Material when both are in scope.
class RadioGroup<T> extends StatelessWidget {
  const RadioGroup({
    super.key,
    required this.value,
    required this.onChanged,
    required this.children,
    this.orientation = Axis.vertical,
    this.spacing,
  });

  final T? value;
  final ValueChanged<T?>? onChanged;
  final List<Widget> children;
  final Axis orientation;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final gap = spacing ?? theme.spaceSm;
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        spaced.add(
          orientation == Axis.horizontal
              ? SizedBox(width: gap)
              : SizedBox(height: gap),
        );
      }
      spaced.add(children[i]);
    }
    return Flex(
      direction: orientation,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: spaced,
    );
  }
}
