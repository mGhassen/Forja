import 'package:flutter/material.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja_foundation/widgets/catalog/category_circle_meta.dart';

/// Layout widget [`kit.categoryBar`] paint — kind chips (Zone A).
///
/// Host resolves dynamic kinds / TV circle and passes [items] + [onSelect].
class CategoryBar extends StatelessWidget {
  const CategoryBar({
    super.key,
    required this.spec,
    required this.items,
    required this.selectedId,
    required this.onSelect,
    this.circleBuilder,
    this.wrapRow,
    this.padding,
  });

  final Map<String, dynamic> spec;
  final List<({String id, String label, String? icon})> items;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  /// Host [ShellMoodCircle] / TV chrome.
  final Widget Function({
    required List<({String id, String label, String? icon})> items,
    required String? selectedId,
    required ValueChanged<String> onSelect,
  })? circleBuilder;

  final Widget Function(Widget child)? wrapRow;
  final EdgeInsetsGeometry? padding;

  String get widgetId => (spec['id'] ?? 'kind').toString();

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final builder = circleBuilder;
    Widget child;
    if (builder != null) {
      child = builder(
        items: items,
        selectedId: selectedId,
        onSelect: onSelect,
      );
    } else {
      child = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              _Chip(
                label: items[i].label,
                icon: kitMoodCircleMeta(
                  id: items[i].id,
                  icon: items[i].icon,
                ).icon,
                selected: selectedId == items[i].id,
                onTap: () => onSelect(items[i].id),
              ),
            ],
          ],
        ),
      );
    }

    final wrap = wrapRow;
    return wrap == null ? child : wrap(child);
  }
}

/// Convenience: read selection from [LayoutScope] and write back.
class CategoryBarFromScope extends StatelessWidget {
  const CategoryBarFromScope({
    super.key,
    required this.spec,
    required this.items,
    this.circleBuilder,
    this.wrapRow,
  });

  final Map<String, dynamic> spec;
  final List<({String id, String label, String? icon})> items;
  final Widget Function({
    required List<({String id, String label, String? icon})> items,
    required String? selectedId,
    required ValueChanged<String> onSelect,
  })? circleBuilder;
  final Widget Function(Widget child)? wrapRow;

  @override
  Widget build(BuildContext context) {
    final scope = LayoutScope.of(context);
    final id = (spec['id'] ?? 'kind').toString();
    return CategoryBar(
      spec: spec,
      items: items,
      selectedId: scope.selectedId(id),
      onSelect: (v) => scope.onSelect(id, v, toggle: false),
      circleBuilder: circleBuilder,
      wrapRow: wrapRow,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: selected ? 0.28 : 0.10),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: Colors.white70),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
