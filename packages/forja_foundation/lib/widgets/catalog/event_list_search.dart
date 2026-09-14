import 'package:flutter/material.dart';
import 'package:forja_foundation/components/focusable_tap.dart';
import 'package:forja_foundation/components/input.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Expanding list search paint for `kit.topBar` event search (Zone A).
///
/// Host owns Riverpod query + TV browse field; pass [expanded] / callbacks.
class EventListSearch extends StatelessWidget {
  const EventListSearch({
    super.key,
    required this.expanded,
    required this.controller,
    required this.onExpand,
    required this.onCollapse,
    required this.onChanged,
    this.placeholder = 'Search…',
    this.tooltip = 'Search',
    this.focusNode,
    this.fieldBuilder,
    this.toolBuilder,
    this.closeBuilder,
    this.widthCollapsed = 40,
    this.widthExpanded = 260,
  });

  final bool expanded;
  final TextEditingController controller;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final ValueChanged<String> onChanged;
  final String placeholder;
  final String tooltip;
  final FocusNode? focusNode;
  final double widthCollapsed;
  final double widthExpanded;

  final Widget Function({
    required TextEditingController controller,
    required FocusNode? focusNode,
    required ValueChanged<String> onChanged,
    required String placeholder,
  })? fieldBuilder;

  final Widget Function({required VoidCallback onTap})? toolBuilder;
  final Widget Function({required VoidCallback onTap})? closeBuilder;

  @override
  Widget build(BuildContext context) {
    final tool = toolBuilder?.call(onTap: onExpand) ??
        FocusableTap(
          onTap: onExpand,
          child: Tooltip(
            message: tooltip,
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.search_rounded, color: Colors.white70),
            ),
          ),
        );

    final close = closeBuilder?.call(onTap: onCollapse) ??
        FocusableTap(
          onTap: onCollapse,
          child: const SizedBox(
            width: 36,
            height: 40,
            child: Icon(Icons.close_rounded, color: Colors.white54),
          ),
        );

    final field = fieldBuilder?.call(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          placeholder: placeholder,
        ) ??
        Input(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          hintText: placeholder,
          variant: InputVariant.search,
        );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: expanded ? widthExpanded : widthCollapsed,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: expanded ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: expanded ? 0.22 : 0.10),
        ),
      ),
      child: expanded
          ? Row(
              children: [
                const SizedBox(width: 8),
                Expanded(child: field),
                close,
              ],
            )
          : tool,
    );
  }
}

/// Collapsed search glyph paint used by [EventListSearch] defaults.
class EventListSearchToolIcon extends StatelessWidget {
  const EventListSearchToolIcon({
    super.key,
    this.focused = false,
    this.color,
  });

  final bool focused;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.search_rounded,
      color: color ??
          (focused
              ? ForjaShellColors.brandGreen
              : ForjaShellColors.textSecondary),
    );
  }
}
