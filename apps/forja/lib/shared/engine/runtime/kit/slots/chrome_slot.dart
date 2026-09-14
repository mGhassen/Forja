import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja_foundation/widgets/chrome/logo_menu_rail.dart';
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

/// Pack `kit.categoryBar` — horizontal chip strip (default) or vertical rail.
///
/// Live Sports body-top uses chips. IPTV side column: `orientation: 'vertical'`.
class PackCategoryBarSlot extends StatelessWidget {
  const PackCategoryBarSlot({super.key, required this.spec});

  final Map<String, dynamic> spec;

  @override
  Widget build(BuildContext context) {
    final items = layoutItemsFromSpec(spec);
    if (items.isEmpty) return const SizedBox.shrink();
    final scope = LayoutScope.maybeOf(context);
    final id = (spec['id'] ?? '').toString();
    final selected = scope?.selectedId(id) ??
        (spec['default'] ?? items.first.id).toString();
    final orientation = (spec['orientation'] ?? spec['axis'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final vertical = orientation == 'vertical' ||
        orientation == 'rail' ||
        spec['vertical'] == true;

    if (!vertical) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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

    final width = (spec['width'] is num)
        ? (spec['width'] as num).toDouble()
        : 220.0;

    return ColoredBox(
      color: ForjaShellColors.surfaceElevated,
      child: LogoMenuRail(
        width: width,
        selectedId: selected,
        onSelect: (itemId) {
          scope?.onSelect(id, itemId, toggle: false);
        },
        items: [
          for (final item in items)
            LogoMenuItem(id: item.id, label: item.label),
        ],
      ),
    );
  }
}

/// Pack `kit.topBar` — horizontal action/menu strip for [ColumnsHeaderBlock].
///
/// Nested `actions[]` with `items` become selectable chip groups via
/// [LayoutScope]. Complex host actions (portals panel, search overlay) stay
/// host-owned; this paints the pack-declared chrome labels.
class PackTopBarSlot extends StatelessWidget {
  const PackTopBarSlot({super.key, required this.spec});

  final Map<String, dynamic> spec;

  @override
  Widget build(BuildContext context) {
    final scope = LayoutScope.maybeOf(context);
    final actions = spec['actions'];
    if (actions is! List || actions.isEmpty) {
      final title = (spec['title'] ?? spec['label'] ?? '').toString().trim();
      if (title.isEmpty) return const SizedBox(height: 48);
      return SizedBox(
        height: 48,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: const TextStyle(
                color: ForjaShellColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    final leading = <Widget>[];
    final trailing = <Widget>[];
    for (final raw in actions) {
      if (raw is! Map) continue;
      final action = Map<String, dynamic>.from(raw);
      final actionId = (action['id'] ?? '').toString().trim();
      if (actionId.isEmpty) continue;
      final label = (action['label'] ?? actionId).toString();
      final isTrailing = action['trailing'] == true;
      final nested = layoutItemsFromSpec(action);
      late final Widget chip;
      if (nested.isEmpty) {
        chip = ForjaShellChip(
          label: label,
          selected: false,
          onTap: () {
            scope?.onSelect(actionId, actionId, toggle: false);
          },
        );
      } else {
        final selected = scope?.selectedId(actionId) ??
            (action['default'] ?? nested.first.id).toString();
        String chipLabel = label;
        for (final e in nested) {
          if (e.id == selected) {
            chipLabel = e.label;
            break;
          }
        }
        chip = ForjaShellChip(
          label: chipLabel,
          selected: true,
          onTap: () {
            final idx = nested.indexWhere((e) => e.id == selected);
            final next = nested[(idx < 0 ? 0 : idx + 1) % nested.length];
            scope?.onSelect(actionId, next.id, toggle: false);
          },
        );
      }
      (isTrailing ? trailing : leading).add(chip);
    }

    return Material(
      color: ForjaShellColors.surfaceElevated,
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (var i = 0; i < leading.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                leading[i],
              ],
              const Spacer(),
              for (var i = 0; i < trailing.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                trailing[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
