import 'package:flutter/material.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';

/// Pack `kit.menu` — selection chips via [LayoutScope].
class PackMenuSlot extends StatelessWidget {
  const PackMenuSlot({super.key, required this.spec});

  final Map<String, dynamic> spec;

  @override
  Widget build(BuildContext context) {
    final items = layoutItemsFromSpec(spec);
    if (items.isEmpty) return const SizedBox.shrink();
    final scope = LayoutScope.maybeOf(context);
    final id = (spec['id'] ?? '').toString();
    final selected = scope?.selectedId(id);
    final toggle = spec['toggle'] == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in items)
            ForjaShellChip(
              label: item.label,
              selected: selected == item.id,
              onTap: () {
                scope?.onSelect(id, item.id, toggle: toggle);
              },
            ),
        ],
      ),
    );
  }
}

/// Pack `kit.tabs` — status / section chips via [LayoutScope].
class PackTabsSlot extends StatelessWidget {
  const PackTabsSlot({super.key, required this.spec});

  final Map<String, dynamic> spec;

  @override
  Widget build(BuildContext context) {
    final items = layoutItemsFromSpec(spec);
    if (items.isEmpty) return const SizedBox.shrink();
    final scope = LayoutScope.maybeOf(context);
    final id = (spec['id'] ?? '').toString();
    final selected = scope?.selectedId(id) ??
        (spec['default'] ?? items.first.id).toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              ForjaShellChip(
                label: items[i].label,
                selected: selected == items[i].id,
                onTap: () {
                  scope?.onSelect(id, items[i].id, toggle: false);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
