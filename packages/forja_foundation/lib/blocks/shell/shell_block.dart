import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/props_map.dart';

/// Prebuilt page shell: optional top bar + body + optional side rail.
///
/// ```json
/// { "type": "shell", "props": { "sideRailWidth": 220 } }
/// ```
class ShellBlock extends StatelessWidget {
  const ShellBlock({
    super.key,
    this.topBar,
    required this.body,
    this.sideRail,
    this.sideRailWidth = 220,
    this.railOnLeading = true,
  });

  factory ShellBlock.fromProps(
    Map<String, dynamic> props, {
    required Widget body,
    Widget? topBar,
    Widget? sideRail,
  }) {
    return ShellBlock(
      topBar: topBar,
      body: body,
      sideRail: sideRail,
      sideRailWidth: propsNumOr(props, 'sideRailWidth', 220),
      railOnLeading: propsBool(props, 'railOnLeading', true),
    );
  }

  final Widget? topBar;
  final Widget body;
  final Widget? sideRail;
  final double sideRailWidth;
  final bool railOnLeading;

  @override
  Widget build(BuildContext context) {
    final content = sideRail == null
        ? body
        : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (railOnLeading)
                SizedBox(width: sideRailWidth, child: sideRail),
              Expanded(child: body),
              if (!railOnLeading)
                SizedBox(width: sideRailWidth, child: sideRail),
            ],
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedHeight &&
            constraints.maxHeight.isFinite;
        if (!bounded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ?topBar,
              content,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?topBar,
            Expanded(child: content),
          ],
        );
      },
    );
  }
}
