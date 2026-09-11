import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Presentational side-panel overlay — props only (RFC-095).
///
/// When [open] is false, returns [child] unchanged. When open, stacks [panel]
/// on the right (side rail) or as a dimmed modal sheet.
class KitSidePanelOverlay extends StatelessWidget {
  const KitSidePanelOverlay({
    super.key,
    required this.open,
    required this.child,
    required this.panel,
    required this.onDismiss,
    this.panelWidth = 380,
    this.useSideRail,
    this.scrimColor,
  });

  final bool open;
  final Widget child;
  final Widget panel;
  final VoidCallback onDismiss;
  final double panelWidth;
  /// `true` = docked right rail; `false` = modal. Null → wide / ATV rail.
  final bool? useSideRail;
  final Color? scrimColor;

  static bool defaultUseSideRail(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return wide || ShellTokens.isAndroidTvDevice;
  }

  @override
  Widget build(BuildContext context) {
    if (!open) return child;

    final side = useSideRail ?? defaultUseSideRail(context);
    final scrim = scrimColor ?? Colors.black.withValues(alpha: 0.45);

    return Stack(
      children: [
        child,
        if (side)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: panelWidth,
            child: panel,
          )
        else
          Positioned.fill(
            child: GestureDetector(
              onTap: onDismiss,
              child: ColoredBox(
                color: scrim,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {},
                    child: panel,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
