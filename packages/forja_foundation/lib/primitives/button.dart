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
    return button;
  }
}
