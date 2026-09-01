import 'package:flutter/material.dart';

/// Layout widget [`CatalogKitTypes.stack`] — vertical composition of pack children.
class CatalogKitStackWidget extends StatelessWidget {
  const CatalogKitStackWidget({
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

    final expandLast = spec['expandLast'] == true || spec['expand'] == true;
    final children = <Widget>[];
    var childIndex = 0;
    for (var i = 0; i < raw.length; i++) {
      final entry = raw[i];
      if (entry is! Map) continue;
      final child = childBuilder(Map<String, dynamic>.from(entry), childIndex);
      childIndex++;
      if (child == null) continue;
      if (expandLast && i == raw.length - 1) {
        children.add(Expanded(child: child));
      } else {
        children.add(child);
      }
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
