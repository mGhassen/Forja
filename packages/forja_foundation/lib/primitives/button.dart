import 'package:flutter/material.dart';

/// Flutter-base button — hit target, focus, semantics. Style values in; no variants.
class PrimitiveButton extends StatelessWidget {
  const PrimitiveButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.style,
    this.padding,
    this.constraints,
    this.borderRadius,
    this.tooltip,
    this.onKeyEvent,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final ButtonStyle? style;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final BorderRadius? borderRadius;
  final String? tooltip;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  @override
  Widget build(BuildContext context) {
    final effectiveEnabled = enabled && onPressed != null;
    Widget button = TextButton(
      onPressed: effectiveEnabled ? onPressed : null,
      focusNode: focusNode,
      autofocus: autofocus,
      style: (style ?? const ButtonStyle()).copyWith(
        padding: padding != null
            ? WidgetStatePropertyAll(padding)
            : null,
        minimumSize: constraints != null
            ? WidgetStatePropertyAll(
                Size(constraints!.minWidth, constraints!.minHeight),
              )
            : null,
        shape: borderRadius != null
            ? WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: borderRadius!),
              )
            : null,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: child,
    );
    if (tooltip != null && tooltip!.isNotEmpty) {
      button = Tooltip(message: tooltip!, child: button);
    }
    final node = focusNode;
    final keyHook = onKeyEvent;
    if (node != null && keyHook != null) {
      button = _FocusKeyHook(node: node, onKeyEvent: keyHook, child: button);
    }
    return button;
  }
}

class _FocusKeyHook extends StatefulWidget {
  const _FocusKeyHook({
    required this.node,
    required this.onKeyEvent,
    required this.child,
  });

  final FocusNode node;
  final KeyEventResult Function(FocusNode node, KeyEvent event) onKeyEvent;
  final Widget child;

  @override
  State<_FocusKeyHook> createState() => _FocusKeyHookState();
}

class _FocusKeyHookState extends State<_FocusKeyHook> {
  @override
  void initState() {
    super.initState();
    widget.node.onKeyEvent = widget.onKeyEvent;
  }

  @override
  void didUpdateWidget(covariant _FocusKeyHook oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node != widget.node) {
      if (oldWidget.node.onKeyEvent == oldWidget.onKeyEvent) {
        oldWidget.node.onKeyEvent = null;
      }
    }
    widget.node.onKeyEvent = widget.onKeyEvent;
  }

  @override
  void dispose() {
    if (widget.node.onKeyEvent == widget.onKeyEvent) {
      widget.node.onKeyEvent = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
