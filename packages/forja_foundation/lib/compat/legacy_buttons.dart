import 'package:flutter/material.dart';
import 'package:forja_foundation/components/button.dart';

/// Deprecated aliases for Part 2 G14-A migration — prefer [Button] variants.

@Deprecated('Use Button(variant: ButtonVariant.ghost)')
class ForjaGhostButton extends StatelessWidget {
  const ForjaGhostButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.autoFocus = false,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool autoFocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Button(
      variant: ButtonVariant.ghost,
      label: label,
      icon: icon,
      onPressed: onTap,
      autofocus: autoFocus,
      focusNode: focusNode,
    );
  }
}

@Deprecated('Use Button(variant: ButtonVariant.plainIcon, size: ButtonSize.icon)')
class ForjaPlainIcon extends StatelessWidget {
  const ForjaPlainIcon({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.focusNode,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Button(
      variant: ButtonVariant.plainIcon,
      size: ButtonSize.icon,
      icon: icon,
      onPressed: onTap,
      tooltip: tooltip,
      focusNode: focusNode,
    );
  }
}

@Deprecated('Use Button(variant: ButtonVariant.outline, size: ButtonSize.icon)')
class ForjaIconButton extends StatelessWidget {
  const ForjaIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Button(
      variant: ButtonVariant.outline,
      size: ButtonSize.icon,
      icon: icon,
      onPressed: onTap,
      tooltip: tooltip,
    );
  }
}

@Deprecated('Use Button(variant: ButtonVariant.plainIcon, size: ButtonSize.icon, icon: Icons.close)')
class ForjaCloseButton extends StatelessWidget {
  const ForjaCloseButton({
    super.key,
    this.onTap,
    this.tooltip = 'Close',
    this.focusNode,
  });

  final VoidCallback? onTap;
  final String? tooltip;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Button(
      variant: ButtonVariant.plainIcon,
      size: ButtonSize.icon,
      icon: Icons.close,
      onPressed: onTap,
      tooltip: tooltip,
      focusNode: focusNode,
    );
  }
}
