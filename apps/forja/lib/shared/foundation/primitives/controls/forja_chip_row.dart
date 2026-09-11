import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/primitives/chrome/shell_focusable_tap.dart';
import 'package:forja/shared/foundation/primitives/controls/forja_shell_chip.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Kit primitive — horizontal chip strip (kind / filter rows).
class ForjaChipRow extends StatelessWidget {
  const ForjaChipRow({
    super.key,
    required this.tabId,
    required this.rowId,
    required this.items,
    required this.selectedId,
    required this.onSelect,
    this.onDownEdge,
    this.height = 48,
  });

  final String tabId;
  final String rowId;
  final List<({String id, String label})> items;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback? onDownEdge;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: ShellTokens.compactChromeLeadingInset(context),
          vertical: 8,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          final on = selectedId == item.id;
          return shellFocusableTap(
            context: context,
            onTap: () => onSelect(item.id),
            listIndex: i,
            tvTabId: tabId,
            tvRowId: rowId,
            tvItemIndex: i,
            onDownEdge: onDownEdge,
            child: ForjaShellChip(
              label: item.label,
              selected: on,
            ),
          );
        },
      ),
    );
  }
}
