import 'package:flutter/material.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja/shared/shell/forja_shell_input_policy.dart';
import 'package:forja/shared/shell/shell_focusable_tap.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Flat list row for kit filter sheets (Catalog / Schedule / generic pickers).
class KitFilterSheetOption extends StatefulWidget {
  const KitFilterSheetOption({
    super.key,
    required this.label,
    required this.selected,
    required this.icon,
    required this.onSelected,
    required this.tvTabId,
    this.subtitle,
    this.tvItemIndex,
    this.tvRowId,
    this.focusNode,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final IconData icon;
  final VoidCallback onSelected;
  final String tvTabId;
  final int? tvItemIndex;
  final String? tvRowId;
  final FocusNode? focusNode;

  @override
  State<KitFilterSheetOption> createState() => _KitFilterSheetOptionState();
}

class _KitFilterSheetOptionState extends State<KitFilterSheetOption> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final mouseHover = policy.scaleOnHover;
    final tvFocus = policy.useFocusableMoodChips;
    final highlight = ShellInputPolicy.interactiveActive(
      policy,
      hovered: _hovered,
      focused: _focused,
      context: context,
    );
    const radius = 12.0;

    final tile = ListTile(
      leading: Icon(
        widget.icon,
        color: widget.selected
            ? ForjaShellColors.sectionAccent
            : Colors.white54,
      ),
      title: Text(
        widget.label,
        style: TextStyle(
          color: Colors.white,
          fontWeight:
              highlight || widget.selected ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      subtitle: (widget.subtitle ?? '').trim().isEmpty
          ? null
          : Text(
              widget.subtitle!.trim(),
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
      trailing: widget.selected
          ? Icon(Icons.check_rounded, color: ForjaShellColors.sectionAccent)
          : const Icon(Icons.chevron_right, color: Colors.white38),
      // Desktop: ListTile owns the tap (nested InkWell hosts ate clicks).
      onTap: tvFocus ? null : widget.onSelected,
    );

    final body = Material(
      color: highlight ? ForjaShellColors.inkHover : Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: tile,
    );

    if (!tvFocus) {
      return MouseRegion(
        onEnter: mouseHover ? (_) => setState(() => _hovered = true) : null,
        onExit: mouseHover ? (_) => setState(() => _hovered = false) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: body,
        ),
      );
    }

    return shellFocusableTap(
      context: context,
      onTap: widget.onSelected,
      borderRadius: radius,
      scaleOnFocus: 1.0,
      showFocusBorder: false,
      showFocusFill: false,
      navLeftAlways: true,
      focusNode: widget.focusNode,
      listIndex: widget.tvItemIndex,
      tvTabId: widget.tvTabId,
      tvRowId: widget.tvRowId,
      tvItemIndex: widget.tvItemIndex,
      tvZone: ShellTvZone.row,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: mouseHover
          ? (hovered) => setState(() => _hovered = hovered)
          : null,
      child: body,
    );
  }
}
