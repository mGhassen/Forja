import 'package:flutter/material.dart';
import 'package:forja_foundation/components/focusable_tap.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

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
    this.radius = 12,
    this.fontSize,
    this.padding = const EdgeInsets.symmetric(vertical: 2),
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
  final double radius;
  final double? fontSize;
  final EdgeInsetsGeometry padding;

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
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool h) {
    if (_hoveredN.value == h) return;
    _hoveredN.value = h;
  }

  bool _highlightFor(bool hovered) => ShellPaintScope.interactiveActive(
        context,
        hovered: hovered,
        focused: _focused,
      );

  Widget _buildBody(bool hovered) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final radius = widget.radius;
    final highlight = _highlightFor(hovered);
    final fontSize = widget.fontSize ??
        (tv
            ? ShellTokens.filterSheetOptionFontSizeTv
            : ShellTokens.filterSheetOptionFontSize);
    final iconSize = tv
        ? ShellTokens.filterSheetIconSizeTv
        : ShellTokens.filterSheetIconSize;
    final checkSize = tv
        ? ShellTokens.filterSheetCheckSizeTv
        : ShellTokens.filterSheetCheckSize;
    final metaSize = tv
        ? ShellTokens.filterSheetMetaFontSizeTv
        : ShellTokens.filterSheetMetaFontSize;
    final tile = ListTile(
      dense: tv,
      visualDensity: tv ? VisualDensity.compact : VisualDensity.standard,
      contentPadding: tv
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 0)
          : null,
      minLeadingWidth: tv ? iconSize + 4 : null,
      minVerticalPadding: tv ? 4 : null,
      leading: Icon(
        widget.icon,
        size: iconSize,
        color: widget.selected
            ? ForjaShellColors.sectionAccent
            : Colors.white54,
      ),
      title: Text(
        widget.label,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight:
              highlight || widget.selected ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      subtitle: (widget.subtitle ?? '').trim().isEmpty
          ? null
          : Text(
              widget.subtitle!.trim(),
              style: TextStyle(color: Colors.white38, fontSize: metaSize),
            ),
      trailing: widget.selected
          ? Icon(
              Icons.check_rounded,
              color: ForjaShellColors.sectionAccent,
              size: checkSize,
            )
          : const SizedBox.shrink(),
      onTap: widget.tvFocus ? null : widget.onSelected,
    );

    return Padding(
      padding: widget.padding,
      child: Material(
        color: highlight ? ForjaShellColors.inkHover : Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: tile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final painted = ListenableBuilder(
      listenable: _hoveredN,
      builder: (context, _) => _buildBody(_hoveredN.value),
    );

    final wrap = widget.interactiveBuilder;
    if (wrap != null) {
      return wrap(
        child: painted,
        onTap: widget.onSelected,
        focusNode: widget.focusNode,
        onFocusChange: (f) => setState(() => _focused = f),
        onHoverChange: widget.scaleOnHover ? _setHovered : null,
      );
    }

    if (!widget.tvFocus) {
      if (!widget.scaleOnHover) return painted;
      return MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: painted,
      );
    }

    return FocusableTap(
      onTap: widget.onSelected,
      focusNode: widget.focusNode,
      borderRadius: BorderRadius.circular(widget.radius),
      child: painted,
    );
  }
}
