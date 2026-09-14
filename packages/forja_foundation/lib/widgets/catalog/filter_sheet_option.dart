import 'package:flutter/material.dart';
import 'package:forja_foundation/components/focusable_tap.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Flat list row for catalog / schedule filter sheets (Zone A paint).
///
/// Host injects TV focus via [interactiveBuilder] (shellFocusableTap).
class FilterSheetOption extends StatefulWidget {
  const FilterSheetOption({
    super.key,
    required this.label,
    required this.selected,
    required this.icon,
    required this.onSelected,
    this.subtitle,
    this.focusNode,
    this.scaleOnHover = true,
    this.tvFocus = false,
    this.interactiveBuilder,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final IconData icon;
  final VoidCallback onSelected;
  final FocusNode? focusNode;
  final bool scaleOnHover;
  final bool tvFocus;

  /// When set, wraps [body] for host TV/focus chrome.
  final Widget Function({
    required Widget child,
    required VoidCallback onTap,
    ValueChanged<bool>? onFocusChange,
    ValueChanged<bool>? onHoverChange,
    FocusNode? focusNode,
  })? interactiveBuilder;

  @override
  State<FilterSheetOption> createState() => _FilterSheetOptionState();
}

class _FilterSheetOptionState extends State<FilterSheetOption> {
  bool _focused = false;
  bool _hovered = false;

  bool get _highlight {
    if (widget.tvFocus) return _focused;
    return _hovered || _focused;
  }

  @override
  Widget build(BuildContext context) {
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
              _highlight || widget.selected ? FontWeight.bold : FontWeight.w600,
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
          : const SizedBox.shrink(),
      onTap: widget.tvFocus ? null : widget.onSelected,
    );

    final body = Material(
      color: _highlight ? ForjaShellColors.inkHover : Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: tile,
    );

    final padded = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: body,
    );

    final wrap = widget.interactiveBuilder;
    if (wrap != null) {
      return wrap(
        child: padded,
        onTap: widget.onSelected,
        focusNode: widget.focusNode,
        onFocusChange: (f) => setState(() => _focused = f),
        onHoverChange: widget.scaleOnHover
            ? (h) => setState(() => _hovered = h)
            : null,
      );
    }

    if (!widget.tvFocus) {
      return MouseRegion(
        onEnter:
            widget.scaleOnHover ? (_) => setState(() => _hovered = true) : null,
        onExit:
            widget.scaleOnHover ? (_) => setState(() => _hovered = false) : null,
        child: padded,
      );
    }

    return FocusableTap(
      onTap: widget.onSelected,
      focusNode: widget.focusNode,
      borderRadius: BorderRadius.circular(radius),
      child: padded,
    );
  }
}
