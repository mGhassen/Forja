import 'package:flutter/material.dart';

/// Layout widget [`LayoutTypes.stack`] — vertical composition of pack children.
class LayoutStack extends StatelessWidget {
  const LayoutStack({
    super.key,
    required this.spec,
    required this.childBuilder,
  });

  final Map<String, dynamic> spec;
  final Widget? Function(Map<String, dynamic> childSpec, int index) childBuilder;

  @override
  Widget build(BuildContext context) {
    final raw = spec['children'];
    if (raw is! List || raw.isEmpty) return const SizedBox.shrink();

    final horizontal = (spec['axis'] ?? '').toString() == 'horizontal';
    final expandLast = spec['expandLast'] == true || spec['expand'] == true;
    final children = <Widget>[];
    var childIndex = 0;
    for (var i = 0; i < raw.length; i++) {
      final entry = raw[i];
      if (entry is! Map) continue;
      final child = childBuilder(Map<String, dynamic>.from(entry), childIndex);
      childIndex++;
      if (child == null) continue;
      children.add(child);
    }
    if (children.isEmpty) return const SizedBox.shrink();
    if (horizontal) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      );
    }

    // CatalogBody mounts stacks inside unbounded scroll — never Expanded there.
    return LayoutBuilder(
      builder: (context, constraints) {
        final canExpand =
            expandLast && constraints.hasBoundedHeight && children.length > 1;
        if (!canExpand) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: children,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++)
              if (i == children.length - 1)
                Expanded(child: children[i])
              else
                children[i],
          ],
        );
      },
    );
  }
}
