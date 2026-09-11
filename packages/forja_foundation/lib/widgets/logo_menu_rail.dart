import 'package:flutter/material.dart';
import 'package:forja_foundation/components/vertical_menu.dart';

/// One selectable logo+label row for [LogoMenuRail].
class LogoMenuItem {
  const LogoMenuItem({
    required this.id,
    required this.label,
    this.logoUrl,
    this.leading,
  });

  final String id;
  final String label;
  final String? logoUrl;

  /// Host-supplied leading (SVG tile, PackAssets mark). Wins over [logoUrl].
  final Widget? leading;
}

/// Props-only logo menu — builds [VerticalMenu] from [items].
///
/// No registry / tabId / pack resolve. Caller supplies [leading] widgets
/// and/or absolute [logoUrl]s.
class LogoMenuRail extends StatelessWidget {
  const LogoMenuRail({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelect,
    this.visible = true,
    this.width = 220,
    this.itemBuilder,
  });

  final List<LogoMenuItem> items;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final bool visible;
  final double width;

  /// Optional override for each row (focus nodes, TV). Defaults to [VerticalMenu.item].
  final Widget Function(BuildContext context, LogoMenuItem item, bool selected)?
      itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return VerticalMenu(
      width: width,
      children: [
        for (final item in items)
          itemBuilder?.call(context, item, item.id == selectedId) ??
              VerticalMenu.item(
                key: ValueKey(item.id),
                label: item.label,
                selected: item.id == selectedId,
                onTap: () => onSelect(item.id),
                leading: item.leading ?? _logo(item.logoUrl),
              ),
      ],
    );
  }

  static Widget? _logo(String? url) {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return Image.network(
      trimmed,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}
