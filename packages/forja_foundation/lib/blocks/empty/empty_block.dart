import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/props_map.dart';
import 'package:forja_foundation/components/empty.dart';

/// Prebuilt empty state from props.
///
/// ```json
/// { "type": "empty", "props": { "title": "Nothing here", "description": "…" } }
/// ```
class EmptyBlock extends StatelessWidget {
  const EmptyBlock({
    super.key,
    this.title,
    this.description,
    this.icon,
    this.action,
    this.size = EmptySize.md,
  });

  factory EmptyBlock.fromProps(
    Map<String, dynamic> props, {
    Widget? action,
  }) {
    final sizeRaw = propsString(props, 'size');
    final size = switch (sizeRaw) {
      'sm' => EmptySize.sm,
      'lg' => EmptySize.lg,
      _ => EmptySize.md,
    };
    return EmptyBlock(
      title: propsString(props, 'title'),
      description: propsString(props, 'description'),
      action: action,
      size: size,
    );
  }

  final String? title;
  final String? description;
  final IconData? icon;
  final Widget? action;
  final EmptySize size;

  @override
  Widget build(BuildContext context) {
    return Empty(
      title: title,
      description: description,
      icon: icon,
      action: action,
      size: size,
    );
  }
}
