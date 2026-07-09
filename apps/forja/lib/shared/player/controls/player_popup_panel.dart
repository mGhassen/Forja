import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';

/// Floating player menu anchored to a control button when possible.
/// Uses [OverlayEntry] — never touches the shell route stack.
class PlayerPopupPanel {
  static const _bottomControlsZoneHeight = 120.0;
  static const _progressBarClearance = 56.0;

  static OverlayEntry? _entry;
  static Completer<void>? _completer;

  static bool get isShowing => _entry != null;

  static void dismiss() {
    _entry?.remove();
    _entry = null;
    _completer?.complete();
    _completer = null;
  }

  static Rect? _anchorRectInOverlay(
    BuildContext anchorContext,
    BuildContext overlayContext,
  ) {
    final anchorBox = anchorContext.findRenderObject() as RenderBox?;
    if (anchorBox == null || !anchorBox.hasSize) return null;

    final overlayBox =
        Overlay.of(overlayContext).context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return null;

    final offset = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    return offset & anchorBox.size;
  }

  static Future<void> show({
    required BuildContext context,
    required String title,
    IconData? leadingIcon,
    Widget? trailing,
    required Widget child,
    double width = 300,
    double maxHeight = 380,
    Alignment alignment = Alignment.bottomLeft,
    EdgeInsets margin = const EdgeInsets.only(left: 16, bottom: 88),
    BuildContext? anchorContext,
    double anchorGap = 8,
    EdgeInsets screenPadding = const EdgeInsets.all(8),
    VoidCallback? onBack,
  }) {
    dismiss();

    final overlay = Overlay.of(context);
    _completer = Completer<void>();

    void close() {
      dismiss();
    }

    _entry = OverlayEntry(
      builder: (overlayContext) {
        final overlaySize = MediaQuery.sizeOf(overlayContext);
        final anchorRect = anchorContext != null
            ? _anchorRectInOverlay(anchorContext, overlayContext)
            : null;
        final reserveAbove = anchorRect == null
            ? 0.0
            : _progressBarReserveAbove(
                overlaySize: overlaySize,
                anchorRect: anchorRect,
                screenPadding: screenPadding,
              );

        final panel = Material(
          type: MaterialType.transparency,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: width,
              maxHeight: anchorRect == null
                  ? maxHeight
                  : _anchoredMaxHeight(
                      overlaySize: overlaySize,
                      anchorRect: anchorRect,
                      anchorGap: anchorGap,
                      screenPadding: screenPadding,
                      maxHeight: maxHeight,
                      reserveAbove: reserveAbove,
                    ),
            ),
            child: _PanelShell(
              title: title,
              leadingIcon: leadingIcon,
              trailing: trailing,
              onBack: onBack == null
                  ? null
                  : () {
                      close();
                      onBack();
                    },
              onClose: close,
              child: child,
            ),
          ),
        );

        final Widget panelLayer;
        if (anchorRect != null) {
          final left = (anchorRect.center.dx - width / 2).clamp(
            screenPadding.left,
            overlaySize.width - width - screenPadding.right,
          );

          final spaceAbove = anchorRect.top -
              screenPadding.top -
              anchorGap -
              reserveAbove;
          final spaceBelow = overlaySize.height -
              anchorRect.bottom -
              screenPadding.bottom -
              anchorGap;
          final showAbove =
              spaceAbove >= spaceBelow && spaceAbove > 0;

          panelLayer = showAbove
              ? Positioned(
                  left: left,
                  bottom: overlaySize.height -
                      anchorRect.top +
                      anchorGap +
                      reserveAbove,
                  width: width,
                  child: panel,
                )
              : Positioned(
                  left: left,
                  top: anchorRect.bottom + anchorGap,
                  width: width,
                  child: panel,
                );
        } else {
          panelLayer = Align(
            alignment: alignment,
            child: Padding(
              padding: margin,
              child: panel,
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: close,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.shrink(),
              ),
            ),
            panelLayer,
          ],
        );
      },
    );

    overlay.insert(_entry!);
    return _completer!.future;
  }

  static double _progressBarReserveAbove({
    required Size overlaySize,
    required Rect anchorRect,
    required EdgeInsets screenPadding,
  }) {
    final anchorFromBottom =
        overlaySize.height - anchorRect.bottom - screenPadding.bottom;
    return anchorFromBottom < _bottomControlsZoneHeight
        ? _progressBarClearance
        : 0.0;
  }

  static double _anchoredMaxHeight({
    required Size overlaySize,
    required Rect anchorRect,
    required double anchorGap,
    required EdgeInsets screenPadding,
    required double maxHeight,
    required double reserveAbove,
  }) {
    final spaceAbove =
        anchorRect.top - screenPadding.top - anchorGap - reserveAbove;
    final spaceBelow = overlaySize.height -
        anchorRect.bottom -
        screenPadding.bottom -
        anchorGap;
    final available = spaceAbove >= spaceBelow ? spaceAbove : spaceBelow;
    return available.clamp(120, maxHeight);
  }
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({
    required this.title,
    required this.child,
    this.leadingIcon,
    this.trailing,
    this.onBack,
    this.onClose,
  });

  final String title;
  final Widget child;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ForjaShellColors.cinematic.menuSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ForjaShellColors.cinematic.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
            child: Row(
              children: [
                if (onBack != null)
                  ForjaPlainIcon(
                    icon: Icons.arrow_back_rounded,
                    size: 20,
                    color: Colors.white,
                    onTap: onBack,
                  )
                else if (leadingIcon != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, right: 4),
                    child: Icon(leadingIcon, color: Colors.white70, size: 18),
                  )
                else
                  const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
                ForjaPlainIcon(
                  icon: Icons.close_rounded,
                  size: 20,
                  color: Colors.white54,
                  onTap: onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          Flexible(child: child),
        ],
      ),
    );
  }
}

class PlayerPopupListTile extends StatelessWidget {
  const PlayerPopupListTile({
    super.key,
    required this.label,
    this.badge,
    this.subtitle,
    this.selected = false,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String? badge;
  final String? subtitle;
  final bool selected;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, color: Colors.white, size: 18)
              else if (trailing != null)
                trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
