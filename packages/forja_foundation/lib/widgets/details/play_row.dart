import 'package:flutter/material.dart';
import 'package:forja_foundation/components/button_group.dart';

/// Details play / action row — [ButtonGroup] of play/actions (RFC-106 G5).
class PlayRow extends StatelessWidget {
  const PlayRow({
    super.key,
    required this.children,
    this.orientation = Axis.horizontal,
    this.spacing,
  });

  final List<Widget> children;
  final Axis orientation;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    return ButtonGroup(
      orientation: orientation,
      spacing: spacing,
      children: children,
    );
  }
}
