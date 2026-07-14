import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/navigation/shell_back_icon_button.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';

enum PlayerSourceStatus { unchecked, ready, active, failed, checking }

Color playerSourceBadgeColor(String? badge) {
  switch (badge?.toUpperCase()) {
    case 'HLS':
      return const Color(0xFF5B21B6);
    case 'MP4':
    case 'VIDEO':
      return const Color(0xFF0369A1);
    case 'DASH':
      return const Color(0xFFB45309);
    case 'AUTO':
      return const Color(0xFF3F3F46);
    default:
      return const Color(0xFF2A2A2A);
  }
}

Color playerSourceStatusColor(PlayerSourceStatus status) {
  switch (status) {
    case PlayerSourceStatus.active:
    case PlayerSourceStatus.ready:
      // Green = up (verified / playable). Playing is shown by the arrow, not the dot.
      return const Color(0xFF22C55E);
    case PlayerSourceStatus.failed:
      return const Color(0xFFEF4444);
    case PlayerSourceStatus.checking:
      return const Color(0xFF38BDF8);
    case PlayerSourceStatus.unchecked:
      return const Color(0x3DFFFFFF);
  }
}

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
    if (!anchorContext.mounted) return null;

    final renderObject = anchorContext.findRenderObject();
    if (renderObject is! RenderBox) return null;
    final anchorBox = renderObject;
    if (!anchorBox.hasSize) return null;

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
    bool centered = false,
  }) {
    dismiss();

    final tv = ShellScope.maybeOf(context)?.inputPolicy.useFocusableMoodChips ??
        false;
    if (tv) {
      centered = true;
      anchorContext = null;
      final overlaySize = MediaQuery.sizeOf(context);
      width = (overlaySize.width * 0.72).clamp(420.0, 640.0);
      maxHeight = overlaySize.height * 0.82;
      margin = EdgeInsets.zero;
      screenPadding = const EdgeInsets.all(24);
    }

    final overlay = Overlay.of(context);
    _completer = Completer<void>();

    void close() {
      dismiss();
    }

    _entry = OverlayEntry(
      builder: (overlayContext) {
        return ShellScope.rehost(
          context,
          Builder(
            builder: (scopedContext) {
              if (anchorContext != null && !anchorContext.mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (isShowing) dismiss();
                });
                return const SizedBox.shrink();
              }

              final overlaySize = MediaQuery.sizeOf(scopedContext);
        final rawAnchorRect = anchorContext != null
            ? _anchorRectInOverlay(anchorContext, overlayContext)
            : null;
        // Mis-anchored to a full-screen context places the panel off-screen.
        final anchorRect = rawAnchorRect != null &&
                rawAnchorRect.height < overlaySize.height * 0.25
            ? rawAnchorRect
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
        } else if (centered) {
          panelLayer = Center(
            child: Padding(
              padding: screenPadding,
              child: panel,
            ),
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

              return tvFocusableOverlay(
                overlayContext: scopedContext,
                onDismiss: close,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: close,
                        behavior: HitTestBehavior.opaque,
                        child: ColoredBox(
                          color: centered
                              ? Colors.black.withValues(alpha: 0.62)
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    panelLayer,
                  ],
                ),
              );
            },
          ),
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

  static Widget tvFocusableOverlay({
    required BuildContext overlayContext,
    required VoidCallback onDismiss,
    required Widget child,
  }) {
    final tv = ShellScope.maybeOf(overlayContext)?.inputPolicy.useFocusableMoodChips ??
        false;
    if (!tv) return child;
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.goBack) {
          onDismiss();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}

class _TvPopupListFocusScope extends StatefulWidget {
  const _TvPopupListFocusScope({required this.child});

  final Widget child;

  static bool claimAutofocus(BuildContext context) {
    return context
            .findAncestorStateOfType<_TvPopupListFocusScopeState>()
            ?.claim() ??
        false;
  }

  @override
  State<_TvPopupListFocusScope> createState() =>
      _TvPopupListFocusScopeState();
}

class _TvPopupListFocusScopeState extends State<_TvPopupListFocusScope> {
  bool _claimed = false;

  bool claim() {
    if (_claimed) return false;
    _claimed = true;
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
    final tvFocus =
        ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final shell = DecoratedBox(
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
                  ShellBackIconButton(
                    icon: Icons.arrow_back_rounded,
                    size: 20,
                    tooltip: 'Back',
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
                ForjaCloseButton(
                  color: Colors.white54,
                  onTap: onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          Flexible(
            child: _TvPopupListFocusScope(child: child),
          ),
        ],
      ),
    );

    if (!tvFocus) return shell;
    return FocusTraversalGroup(child: shell);
  }
}

class PlayerPopupListTile extends StatelessWidget {
  const PlayerPopupListTile({
    super.key,
    required this.label,
    this.badge,
    this.badgeColor,
    this.subtitle,
    this.selected = false,
    this.status,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String? badge;
  final Color? badgeColor;
  final String? subtitle;
  final bool selected;
  final PlayerSourceStatus? status;
  final Widget? trailing;
  final VoidCallback? onTap;

  static const double _statusSlot = 18;

  Widget? _statusGlyph() {
    if (status == null) return null;
    final color = playerSourceStatusColor(status!);
    final Widget glyph = switch (status!) {
      PlayerSourceStatus.active => Icon(
          Icons.play_circle_filled_rounded,
          color: color,
          size: _statusSlot,
        ),
      PlayerSourceStatus.failed => Icon(
          Icons.cancel_rounded,
          color: color,
          size: _statusSlot,
        ),
      PlayerSourceStatus.checking => SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: color,
          ),
        ),
      PlayerSourceStatus.ready => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      PlayerSourceStatus.unchecked => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
    };
    return SizedBox(
      width: _statusSlot,
      height: _statusSlot,
      child: Center(child: glyph),
    );
  }

  @override
  Widget build(BuildContext context) {
    final failed = status == PlayerSourceStatus.failed;
    final active = status == PlayerSourceStatus.active;
    final statusGlyph = _statusGlyph();
    final rowColor = selected
        ? Colors.white.withValues(alpha: 0.12)
        : failed
            ? const Color(0xFFEF4444).withValues(alpha: 0.08)
            : active
                ? const Color(0xFF22C55E).withValues(alpha: 0.07)
                : Colors.transparent;

    final tvFocus =
        ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final tile = Material(
      color: rowColor,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: ForjaShellColors.inkHover,
        splashColor: ForjaShellColors.inkSplash,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: active
                ? Border.all(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                  )
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (badge != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor ?? const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      color: badgeColor != null && badgeColor != const Color(0xFF2A2A2A)
                          ? Colors.white.withValues(alpha: 0.92)
                          : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: failed
                            ? Colors.white.withValues(alpha: 0.45)
                            : Colors.white,
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        decoration: failed ? TextDecoration.lineThrough : null,
                        decorationColor: Colors.white38,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    if (status != null &&
                        status != PlayerSourceStatus.ready &&
                        status != PlayerSourceStatus.unchecked)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          switch (status!) {
                            PlayerSourceStatus.active => 'Playing',
                            PlayerSourceStatus.failed => 'Unavailable',
                            PlayerSourceStatus.checking => 'Checking…',
                            PlayerSourceStatus.ready ||
                            PlayerSourceStatus.unchecked =>
                              '',
                          },
                          style: TextStyle(
                            color: playerSourceStatusColor(status!),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (selected)
                const SizedBox(
                  width: _statusSlot,
                  height: _statusSlot,
                  child: Icon(Icons.check_rounded, color: Colors.white, size: 18),
                )
              else if (statusGlyph != null)
                statusGlyph
              else if (trailing != null)
                trailing!,
            ],
          ),
        ),
      ),
    );

    if (!tvFocus || onTap == null) return tile;

    return FocusableControl(
      autoFocus: _TvPopupListFocusScope.claimAutofocus(context),
      onTap: onTap,
      borderRadius: 8,
      showFocusBorder: true,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      child: tile,
    );
  }
}
