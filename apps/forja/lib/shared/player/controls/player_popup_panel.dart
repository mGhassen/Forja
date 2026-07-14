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

/// Floating-menu surface tokens (Lab-style chrome — not side panels).
abstract final class PlayerPopupTokens {
  static const Color shellBg = Color(0xFF121212);
  static const Color cardBg = Color(0xFF1C1C1C);
  static const Color border = Color(0xFF2F2F2F);
  static const Color selectedFill = Colors.white;
  static const Color selectedFg = Colors.black;
  static const Color muted = Color(0xFF9CA3AF);
  static const double shellRadius = 14;
  static const double cardRadius = 12;
  static const double chipRadius = 8;
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
        color: PlayerPopupTokens.shellBg,
        borderRadius: BorderRadius.circular(PlayerPopupTokens.shellRadius),
        border: Border.all(color: PlayerPopupTokens.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 8, 10),
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
                    padding: const EdgeInsets.only(left: 6, right: 6),
                    child: Icon(
                      leadingIcon,
                      color: PlayerPopupTokens.muted,
                      size: 18,
                    ),
                  )
                else
                  const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  trailing!,
                  const SizedBox(width: 4),
                ],
                _PopupChromeButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  onTap: onClose,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Divider(height: 1, color: PlayerPopupTokens.border),
          ),
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

class _PopupChromeButton extends StatelessWidget {
  const _PopupChromeButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: ForjaShellColors.inkHover,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: PlayerPopupTokens.border),
          ),
          child: Icon(icon, size: 16, color: PlayerPopupTokens.muted),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Bordered section card used inside floating menus.
class PlayerPopupSectionCard extends StatelessWidget {
  const PlayerPopupSectionCard({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.valueBadge,
    required this.child,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final String? valueBadge;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: PlayerPopupTokens.cardBg,
        borderRadius: BorderRadius.circular(PlayerPopupTokens.cardRadius),
        border: Border.all(color: PlayerPopupTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: PlayerPopupTokens.muted,
                          fontSize: 11,
                          height: 1.25,
                        ),
                      ),
                  ],
                ),
              ),
              if (valueBadge != null) PlayerPopupValueBadge(valueBadge!),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class PlayerPopupValueBadge extends StatelessWidget {
  const PlayerPopupValueBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: PlayerPopupTokens.border),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: PlayerPopupTokens.muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Segmented option chip — selected = white fill / black text.
class PlayerPopupOptionChip extends StatelessWidget {
  const PlayerPopupOptionChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.expanded = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final tvFocus =
        ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final chip = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
        hoverColor: ForjaShellColors.inkHover,
        child: Container(
          width: expanded ? double.infinity : null,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? PlayerPopupTokens.selectedFill
                : Colors.transparent,
            borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
            border: Border.all(
              color: selected
                  ? PlayerPopupTokens.selectedFill
                  : PlayerPopupTokens.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? PlayerPopupTokens.selectedFg
                  : PlayerPopupTokens.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );

    if (!tvFocus || onTap == null) return chip;
    return FocusableControl(
      onTap: onTap,
      borderRadius: PlayerPopupTokens.chipRadius,
      showFocusBorder: true,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      child: chip,
    );
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
        ? PlayerPopupTokens.selectedFill
        : failed
            ? const Color(0xFFEF4444).withValues(alpha: 0.08)
            : active
                ? const Color(0xFF22C55E).withValues(alpha: 0.07)
                : Colors.transparent;
    final fg = selected
        ? PlayerPopupTokens.selectedFg
        : failed
            ? Colors.white.withValues(alpha: 0.45)
            : Colors.white;
    final subFg = selected
        ? PlayerPopupTokens.selectedFg.withValues(alpha: 0.62)
        : PlayerPopupTokens.muted;

    final tvFocus =
        ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final tile = Material(
      color: rowColor,
      borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
        hoverColor: selected
            ? Colors.black.withValues(alpha: 0.06)
            : ForjaShellColors.inkHover,
        splashColor: selected
            ? Colors.black.withValues(alpha: 0.1)
            : ForjaShellColors.inkSplash,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
            border: Border.all(
              color: selected
                  ? PlayerPopupTokens.selectedFill
                  : active
                      ? const Color(0xFF22C55E).withValues(alpha: 0.35)
                      : PlayerPopupTokens.border,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (badge != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.black.withValues(alpha: 0.08)
                        : (badgeColor ?? PlayerPopupTokens.cardBg),
                    borderRadius: BorderRadius.circular(6),
                    border: selected
                        ? null
                        : Border.all(color: PlayerPopupTokens.border),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      color: selected
                          ? PlayerPopupTokens.selectedFg
                          : badgeColor != null &&
                                  badgeColor != const Color(0xFF2A2A2A)
                              ? Colors.white.withValues(alpha: 0.92)
                              : PlayerPopupTokens.muted,
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
                        color: fg,
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        decoration: failed ? TextDecoration.lineThrough : null,
                        decorationColor: Colors.white38,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: subFg,
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
                            color: selected
                                ? subFg
                                : playerSourceStatusColor(status!),
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
                  child: Icon(
                    Icons.check_rounded,
                    color: PlayerPopupTokens.selectedFg,
                    size: 18,
                  ),
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

    if (!tvFocus || onTap == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: tile,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: FocusableControl(
        autoFocus: _TvPopupListFocusScope.claimAutofocus(context),
        onTap: onTap,
        borderRadius: PlayerPopupTokens.chipRadius,
        showFocusBorder: true,
        ensureVisibleMode: ShellTvEnsureVisibleMode.item,
        child: tile,
      ),
    );
  }
}
