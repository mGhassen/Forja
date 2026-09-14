/// Empty app chassis — nav rail + body (+ optional top bar / bottom nav).
///
/// Packs fill [body]. The host only supplies destinations and mounts
/// [PackLayoutHost] / painter output here. No product tab vocabulary.
library;

import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/shell/shell_block.dart';

/// Declarative empty-shell frame for the pack-product host.
///
/// Prefer this over a fat host scaffold when composing the app chrome.
class EmptyShellFrame extends StatelessWidget {
  const EmptyShellFrame({
    super.key,
    required this.body,
    this.sideRail,
    this.topBar,
    this.bottomNav,
    this.sideRailWidth = 72,
    this.railOnLeading = true,
  });

  final Widget body;
  final Widget? sideRail;
  final Widget? topBar;
  final Widget? bottomNav;
  final double sideRailWidth;
  final bool railOnLeading;

  @override
  Widget build(BuildContext context) {
    final shell = ShellBlock(
      topBar: topBar,
      body: body,
      sideRail: sideRail,
      sideRailWidth: sideRailWidth,
      railOnLeading: railOnLeading,
    );
    if (bottomNav == null) return shell;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: shell),
        bottomNav!,
      ],
    );
  }
}
