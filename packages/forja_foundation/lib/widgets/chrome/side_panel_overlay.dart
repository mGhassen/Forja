import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Presentational side-panel overlay — props only (RFC-095).
///
/// Always keeps [child] mounted so toggling [open] does not remount the body
/// (e.g. IPTV feed). Wide / ATV: docked rail pushes [child] aside in a [Row].
/// Narrow: dimmed modal sheet stacked over [child].
class SidePanelOverlay extends StatelessWidget {
  const SidePanelOverlay({
    super.key,
    required this.open,
    required this.child,
    required this.panel,
    required this.onDismiss,
    this.panelWidth = ShellTokens.sidePanelWidth,
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
    final side = useSideRail ?? defaultUseSideRail(context);
    final scrim = scrimColor ?? Colors.black.withValues(alpha: 0.45);

    if (side) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: child),
          if (open)
            SizedBox(
              width: panelWidth,
              child: panel,
            ),
        ],
      );
    }

    return Stack(
      children: [
        child,
        if (open)
          Positioned.fill(
            child: GestureDetector(
              onTap: onDismiss,
              child: ColoredBox(
                color: scrim,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {},
                    child: SizedBox(
                      width: panelWidth,
                      height: MediaQuery.sizeOf(context).height,
                      child: panel,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
