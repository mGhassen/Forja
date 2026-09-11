import 'package:flutter/material.dart';

/// Shell page template — topBar + body + optional side rail (RFC-106 G6).
class ShellBlock extends StatelessWidget {
  const ShellBlock({
    super.key,
    this.topBar,
    required this.body,
    this.sideRail,
    this.sideRailWidth = 220,
    this.railOnLeading = true,
  });

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topBar != null) topBar!,
        Expanded(child: content),
      ],
    );
  }
}
