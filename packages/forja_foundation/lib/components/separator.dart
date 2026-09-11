import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Hairline divider — horizontal or vertical.
class Separator extends StatelessWidget {
  const Separator({
    super.key,
    this.orientation = Axis.horizontal,
    this.thickness = 1,
    this.color,
    this.indent = 0,
    this.endIndent = 0,
  });

  final Axis orientation;
  final double thickness;
  final Color? color;
  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final c = color ?? theme.borderSubtle;
    if (orientation == Axis.vertical) {
      return Container(
        margin: EdgeInsets.only(top: indent, bottom: endIndent),
        width: thickness,
        color: c,
      );
    }
    return Container(
      margin: EdgeInsets.only(left: indent, right: endIndent),
      height: thickness,
      color: c,
    );
  }
}
