import 'package:flutter/material.dart' hide Checkbox;
import 'package:flutter/material.dart' as material show Checkbox;
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Forja checkbox — brand-green check, subtle border.
class Checkbox extends StatelessWidget {
  const Checkbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.tristate = false,
    this.label,
    this.focusNode,
  });

  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final bool tristate;
  final String? label;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final box = material.Checkbox(
      value: value,
      tristate: tristate,
      onChanged: onChanged,
      focusNode: focusNode,
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return theme.brandGreen;
        return Colors.transparent;
      }),
      checkColor: theme.bgDark,
      side: BorderSide(color: theme.borderSubtle, width: 1.5),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
    if (label == null) return box;
    return InkWell(
      onTap: onChanged == null
          ? null
          : () {
              if (tristate) {
                if (value == null) {
                  onChanged!(false);
                } else if (value == false) {
                  onChanged!(true);
                } else {
                  onChanged!(null);
                }
              } else {
                onChanged!(!(value ?? false));
              }
            },
      borderRadius: BorderRadius.circular(theme.radiusSm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          box,
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

/// Vertical stack of labeled checkboxes.
class CheckboxGroup extends StatelessWidget {
  const CheckboxGroup({
    super.key,
    required this.children,
    this.spacing,
  });

  final List<Widget> children;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final gap = spacing ?? theme.spaceSm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );
  }
}
