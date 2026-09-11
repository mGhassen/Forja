import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Groups [Button] children with optional separator / text slots.
class ButtonGroup extends StatelessWidget {
  const ButtonGroup({
    super.key,
    required this.children,
    this.orientation = Axis.horizontal,
    this.spacing,
  });

  final List<Widget> children;
  final Axis orientation;
  final double? spacing;

  /// Hairline divider between group actions.
  static Widget separator({Key? key, Axis axis = Axis.vertical}) {
    return _ButtonGroupSeparator(key: key, axis: axis);
  }

  /// Non-interactive label between group actions.
  static Widget text(String label, {Key? key, TextStyle? style}) {
    return _ButtonGroupText(key: key, label: label, style: style);
  }

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
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: spaced,
    );
  }
}

class _ButtonGroupSeparator extends StatelessWidget {
  const _ButtonGroupSeparator({super.key, required this.axis});

  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    if (axis == Axis.vertical) {
      return Container(width: 1, height: 20, color: theme.borderSubtle);
    }
    return Container(width: 20, height: 1, color: theme.borderSubtle);
  }
}

class _ButtonGroupText extends StatelessWidget {
  const _ButtonGroupText({super.key, required this.label, this.style});

  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    return Text(
      label,
      style: style ??
          TextStyle(
            color: theme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
