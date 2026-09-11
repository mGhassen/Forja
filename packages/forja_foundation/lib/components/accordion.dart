import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Expandable / collapsible section.
class Accordion extends StatefulWidget {
  const Accordion({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
    this.expanded,
    this.onExpansionChanged,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  /// Controlled expanded state; when null, widget is uncontrolled.
  final bool? expanded;
  final ValueChanged<bool>? onExpansionChanged;

  @override
  State<Accordion> createState() => _AccordionState();
}

class _AccordionState extends State<Accordion> {
  late bool _open;

  @override
  void initState() {
    super.initState();
    _open = widget.expanded ?? widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant Accordion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != null && widget.expanded != oldWidget.expanded) {
      _open = widget.expanded!;
    }
  }

  void _toggle() {
    final next = !_open;
    if (widget.expanded == null) {
      setState(() => _open = next);
    }
    widget.onExpansionChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final open = widget.expanded ?? _open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(theme.radiusMd),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spaceMd,
              vertical: theme.spaceSm + 4,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.expand_more,
                    color: theme.textSecondary,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: EdgeInsets.fromLTRB(
              theme.spaceMd,
              0,
              theme.spaceMd,
              theme.spaceMd,
            ),
            child: widget.child,
          ),
          crossFadeState:
              open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),
      ],
    );
  }
}

/// Alias for collapsible panels.
typedef Collapsible = Accordion;
