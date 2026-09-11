import 'package:flutter/material.dart';
import 'package:forja_foundation/components/empty.dart';

/// Empty-state block — wraps [Empty] (RFC-106 G6).
class EmptyBlock extends StatelessWidget {
  const EmptyBlock({
    super.key,
    this.title,
    this.description,
    this.icon,
    this.action,
    this.size = EmptySize.md,
  });

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
