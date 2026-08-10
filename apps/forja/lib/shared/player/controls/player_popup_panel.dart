import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/navigation/shell_back_icon_button.dart';
import 'package:forja/shared/player/controls/player_menu_return_focus.dart';
import 'package:forja/shared/player/controls/player_seek_scrub_cancel.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

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
      // Brand green = up (verified / playable). Playing is shown by the arrow, not the dot.
      return PlayerPopupTokens.accent;
    case PlayerSourceStatus.failed:
      return const Color(0xFFEF4444);
    case PlayerSourceStatus.checking:
      return const Color(0xFF38BDF8);
    case PlayerSourceStatus.unchecked:
      return const Color(0x3DFFFFFF);
  }
}

/// Floating player menu anchored to a control button when possible.
/// Uses [OverlayEntry] - never touches the shell route stack.
class PlayerPopupPanel {
  static const _bottomControlsZoneHeight = 120.0;
  static const _progressBarClearance = 72.0;

  static OverlayEntry? _entry;
  static Completer<void>? _completer;
  /// Raw drill-in callback from [show] (`onBack`) - remote Back uses this to
  /// return to the parent page instead of closing the whole menu.
  static VoidCallback? _drillInOnBack;

  static bool get isShowing => _entry != null;

  static void dismiss() {
    final wasShowing = _entry != null;
    _entry?.remove();
    _entry = null;
    _completer?.complete();
    _completer = null;
    _drillInOnBack = null;
    if (wasShowing) playerMenuRestoreReturnFocus();
  }

  /// One Back step: reopen parent when this panel is a drill-in, else dismiss.
  /// Returns false when nothing was showing.
  static bool popLayerOrDismiss() {
    if (_entry == null) return false;
    final reopen = _drillInOnBack;
    dismiss();
    if (reopen != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        reopen();
      });
    }
    return true;
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
    /// When false, omit title / close chrome (barrier tap still dismisses).
    bool showHeader = true,
    /// Override panel fill (default [PlayerPopupTokens.shellBg]).
    Color? shellBg,
    /// TV: land D-pad on Close (e.g. read-only panels with no list options).
    bool autofocusClose = false,
  }) {
    if (!context.mounted) return Future.value();

    // Read overlay ancestors before [dismiss] - [context] may live inside the
    // panel we are about to remove (drill-in / back navigation).
    final shellScope = ShellScope.maybeOf(context);
    final ShellProfile capturedProfile;
    final ShellPlatformConfig capturedConfig;
    if (shellScope != null) {
      capturedProfile = shellScope.profile;
      capturedConfig = shellScope.config;
    } else {
      capturedProfile = resolveShellProfile(context);
      capturedConfig = shellPlatformConfigFor(capturedProfile);
    }

    final tv = capturedConfig.inputPolicy.useFocusableMoodChips;
    // Capture opener before dismiss / TV centering clears the anchor.
    playerMenuCaptureReturnFocus(context);
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
    dismiss();
    playerChromeCancelSeekScrubs();
    _drillInOnBack = onBack;

    _completer = Completer<void>();

    void close() {
      dismiss();
    }

    void popOrClose() {
      popLayerOrDismiss();
    }

    _entry = OverlayEntry(
      builder: (overlayContext) {
        return ShellScope(
          profile: capturedProfile,
          config: capturedConfig,
          child: Builder(
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
              final anchorRect =
                  rawAnchorRect != null &&
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
                    shellBg: shellBg,
                    showHeader: showHeader,
                    autofocusClose: autofocusClose,
                    onBack: onBack == null ? null : popOrClose,
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

                final spaceAbove =
                    anchorRect.top -
                    screenPadding.top -
                    anchorGap -
                    reserveAbove;
                final spaceBelow =
                    overlaySize.height -
                    anchorRect.bottom -
                    screenPadding.bottom -
                    anchorGap;
                final showAbove = spaceAbove >= spaceBelow && spaceAbove > 0;

                panelLayer = showAbove
                    ? Positioned(
                        left: left,
                        bottom:
                            overlaySize.height -
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
                  child: Padding(padding: screenPadding, child: panel),
                );
              } else {
                panelLayer = Align(
                  alignment: alignment,
                  child: Padding(padding: margin, child: panel),
                );
              }

              return tvFocusableOverlay(
                overlayContext: scopedContext,
                onDismiss: popOrClose,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: close,
                        // Opaque hit target - fully transparent colors can let
                        // the seek bar under the overlay still receive taps on
                        // desktop (Source / Audio / Settings menus sit above it).
                        behavior: HitTestBehavior.opaque,
                        child: ColoredBox(
                          color: centered
                              ? Colors.black.withValues(alpha: 0.62)
                              : const Color(0x01000000),
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
    final spaceBelow =
        overlaySize.height -
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
    return TvOverlayScope(
      enabled: ShellScope.maybeOf(overlayContext)
              ?.inputPolicy
              .useFocusableMoodChips ??
          false,
      onDismiss: onDismiss,
      child: child,
    );
  }
}

/// Lets the selected list row claim autofocus once; otherwise open falls back
/// to the first focusable via [FocusScope.nextFocus].
class PlayerPopupListFocusScope extends StatefulWidget {
  const PlayerPopupListFocusScope({super.key, required this.child});

  final Widget child;

  static bool claimAutofocus(BuildContext context) {
    return context
            .findAncestorStateOfType<_PlayerPopupListFocusScopeState>()
            ?.claim() ??
        false;
  }

  @override
  State<PlayerPopupListFocusScope> createState() =>
      _PlayerPopupListFocusScopeState();
}

class _PlayerPopupListFocusScopeState extends State<PlayerPopupListFocusScope> {
  bool _claimed = false;

  bool claim() {
    if (_claimed) return false;
    _claimed = true;
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Floating-menu surface tokens - flat dark chrome + brand-green accent.
abstract final class PlayerPopupTokens {
  static const Color shellBg = Color(0xFF0E0E0E);
  static const Color cardBg = Color(0xFF161616);
  static const Color border = Color(0xFF2A2A2A);
  static const Color accent = ForjaShellColors.brandGreen;
  static const Color accentFill = Color(0x291CE783); // green @ ~0.16
  static const Color accentBorder = Color(0x661CE783); // green @ ~0.40
  static const Color accentFg = Color(0xFF0A0A0A);
  static const Color selectedFill = accent;
  static const Color selectedFg = accentFg;
  static const Color muted = Color(0xFF9CA3AF);
  static const double shellRadius = 12;
  static const double cardRadius = 8;
  static const double chipRadius = 6;
  static const double badgeRadius = 4;
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({
    required this.title,
    required this.child,
    this.leadingIcon,
    this.trailing,
    this.onBack,
    this.onClose,
    this.showHeader = true,
    this.shellBg,
    this.autofocusClose = false,
  });

  final String title;
  final Widget child;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onBack;
  final VoidCallback? onClose;
  final bool showHeader;
  final Color? shellBg;
  final bool autofocusClose;

  @override
  Widget build(BuildContext context) {
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final shell = DecoratedBox(
      decoration: BoxDecoration(
        color: shellBg ?? PlayerPopupTokens.shellBg,
        borderRadius: BorderRadius.circular(PlayerPopupTokens.shellRadius),
        border: Border.all(color: PlayerPopupTokens.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHeader) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
              child: Row(
                children: [
                  if (onBack != null)
                    ShellBackIconButton(
                      icon: Icons.arrow_back_rounded,
                      size: 18,
                      tooltip: 'Back',
                      onTap: onBack,
                    )
                  else if (leadingIcon != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, right: 6),
                      child: Icon(
                        leadingIcon,
                        color: PlayerPopupTokens.muted,
                        size: 16,
                      ),
                    )
                  else
                    const SizedBox(width: 4),
                  if (title.isNotEmpty)
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.15,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (trailing != null) ...[
                    trailing!,
                    const SizedBox(width: 4),
                  ],
                  _PopupChromeButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    onTap: onClose,
                    autoFocus: tvFocus && autofocusClose,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Divider(
                height: 1,
                thickness: 0.5,
                color: PlayerPopupTokens.border,
              ),
            ),
          ],
          Flexible(child: PlayerPopupListFocusScope(child: child)),
        ],
      ),
    );

    if (!tvFocus) return shell;
    return FocusTraversalGroup(child: shell);
  }
}

class _PopupChromeButton extends StatefulWidget {
  const _PopupChromeButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.autoFocus = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool autoFocus;

  @override
  State<_PopupChromeButton> createState() => _PopupChromeButtonState();
}

class _PopupChromeButtonState extends State<_PopupChromeButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final highlight = _hovered || _focused;
    final borderColor = highlight
        ? PlayerPopupTokens.accentBorder
        : PlayerPopupTokens.border;
    final iconColor = highlight
        ? PlayerPopupTokens.accent
        : PlayerPopupTokens.muted;
    final face = Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
        border: Border.all(color: borderColor),
      ),
      child: Icon(widget.icon, size: 14, color: iconColor),
    );
    final button = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
        clipBehavior: Clip.antiAlias,
        child: tvFocus
            ? FocusableControl(
                autoFocus: widget.autoFocus,
                onTap: widget.onTap,
                borderRadius: PlayerPopupTokens.chipRadius,
                scaleOnFocus: 1.0,
                showFocusBorder: true,
                onFocusChange: (f) => setState(() => _focused = f),
                child: face,
              )
            : InkWell(
                onTap: widget.onTap,
                hoverColor: PlayerPopupTokens.accentFill,
                child: face,
              ),
      ),
    );
    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}

/// Bordered rounded-square icon box (nav-row leading).
class PlayerPopupIconBox extends StatelessWidget {
  const PlayerPopupIconBox({super.key, required this.icon, this.accent = false});

  final IconData icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent
            ? PlayerPopupTokens.accentFill
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
        border: Border.all(
          color: accent
              ? PlayerPopupTokens.accentBorder
              : PlayerPopupTokens.border,
        ),
      ),
      child: Icon(
        icon,
        size: 15,
        color: accent
            ? PlayerPopupTokens.accent
            : Colors.white.withValues(alpha: 0.9),
      ),
    );
  }
}

/// Drill-in row: optional leading icon box, title + subtitle, value badge, chevron.
class PlayerPopupNavRow extends StatefulWidget {
  const PlayerPopupNavRow({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.selected = false,
    this.onTap,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final String? value;

  /// When true the row uses the brand-green accent (green icon box + border) -
  /// e.g. a language group that contains the active subtitle.
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<PlayerPopupNavRow> createState() => _PlayerPopupNavRowState();
}

class _PlayerPopupNavRowState extends State<PlayerPopupNavRow> {
  bool _focused = false;

  bool get _valueActive {
    if (widget.selected) return true;
    final v = widget.value?.trim().toLowerCase();
    if (v == null || v.isEmpty) return false;
    return v == 'on' ||
        v == 'auto' ||
        v == 'normal' ||
        (!v.contains('off') && v != '-');
  }

  @override
  Widget build(BuildContext context) {
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    // Opaque cardBg would cover FocusableControl's flat focus fill - paint
    // the gray highlight on the row itself (same look as option chips).
    final bg = widget.selected
        ? PlayerPopupTokens.accentFill
        : _focused
        ? Colors.white.withValues(alpha: 0.08)
        : PlayerPopupTokens.cardBg;
    final border = widget.selected
        ? PlayerPopupTokens.accentBorder
        : _focused
        ? Colors.white.withValues(alpha: 0.28)
        : PlayerPopupTokens.border;
    final row = Material(
      color: bg,
      borderRadius: BorderRadius.circular(PlayerPopupTokens.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        canRequestFocus: false,
        onTap: tvFocus ? null : widget.onTap,
        borderRadius: BorderRadius.circular(PlayerPopupTokens.cardRadius),
        hoverColor: ForjaShellColors.inkHover,
        splashColor: ForjaShellColors.inkSplash,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PlayerPopupTokens.cardRadius),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                PlayerPopupIconBox(
                  icon: widget.icon!,
                  accent: widget.selected,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          widget.subtitle!,
                          style: const TextStyle(
                            color: PlayerPopupTokens.muted,
                            fontSize: 11,
                            height: 1.2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.value != null) ...[
                PlayerPopupValueBadge(widget.value!, accent: _valueActive),
                const SizedBox(width: 6),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: PlayerPopupTokens.muted,
              ),
            ],
          ),
        ),
      ),
    );

    if (!tvFocus || widget.onTap == null) return row;
    return FocusableControl(
      autoFocus: PlayerPopupListFocusScope.claimAutofocus(context),
      onTap: widget.onTap,
      borderRadius: PlayerPopupTokens.cardRadius,
      scaleOnFocus: 1.0,
      showFocusBorder: false,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: row,
    );
  }
}

class PlayerPopupValueBadge extends StatelessWidget {
  const PlayerPopupValueBadge(this.label, {super.key, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: accent ? PlayerPopupTokens.accentFill : Colors.transparent,
        borderRadius: BorderRadius.circular(PlayerPopupTokens.badgeRadius),
        border: Border.all(
          color: accent
              ? PlayerPopupTokens.accentBorder
              : PlayerPopupTokens.border,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: accent ? PlayerPopupTokens.accent : PlayerPopupTokens.muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Segmented option chip - selected = brand green fill / dark text.
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
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final chip = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        canRequestFocus: false,
        onTap: tvFocus ? null : onTap,
        borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
        hoverColor: selected
            ? Colors.black.withValues(alpha: 0.06)
            : ForjaShellColors.inkHover,
        child: Container(
          width: expanded ? double.infinity : null,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      // Prefer the current value; else first chip claims via fallback nextFocus.
      autoFocus:
          selected && PlayerPopupListFocusScope.claimAutofocus(context),
      onTap: onTap,
      borderRadius: PlayerPopupTokens.chipRadius,
      scaleOnFocus: 1.0,
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
    this.focusNode,
    this.onLeftEdge,
    this.onRightEdge,
    this.onUpEdge,
    this.onDownEdge,
  });

  final String label;
  final String? badge;
  final Color? badgeColor;
  final String? subtitle;
  final bool selected;
  final PlayerSourceStatus? status;
  final Widget? trailing;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;

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
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      ),
      PlayerSourceStatus.ready => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      PlayerSourceStatus.unchecked => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
    final rowColor = selected || active
        ? PlayerPopupTokens.accentFill
        : failed
        ? const Color(0xFFEF4444).withValues(alpha: 0.08)
        : Colors.transparent;
    final fg = failed
        ? Colors.white.withValues(alpha: 0.45)
        : selected || active
        ? Colors.white
        : Colors.white.withValues(alpha: 0.92);
    final subFg = selected || active
        ? PlayerPopupTokens.accent.withValues(alpha: 0.85)
        : PlayerPopupTokens.muted;

    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final tile = Material(
      color: rowColor,
      borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        canRequestFocus: false,
        onTap: tvFocus ? null : onTap,
        borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
        hoverColor: ForjaShellColors.inkHover,
        splashColor: ForjaShellColors.inkSplash,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
            border: Border.all(
              color: selected
                  ? PlayerPopupTokens.accentBorder
                  : active
                  ? PlayerPopupTokens.accentBorder
                  : PlayerPopupTokens.border,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(
            children: [
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: selected || active
                        ? PlayerPopupTokens.accent.withValues(alpha: 0.12)
                        : (badgeColor ?? PlayerPopupTokens.cardBg),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: selected || active
                          ? PlayerPopupTokens.accentBorder
                          : PlayerPopupTokens.border,
                    ),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      color: selected || active
                          ? PlayerPopupTokens.accent
                          : badgeColor != null &&
                                badgeColor != const Color(0xFF2A2A2A)
                          ? Colors.white.withValues(alpha: 0.92)
                          : PlayerPopupTokens.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
                        fontSize: 13,
                        fontWeight: selected || active
                            ? FontWeight.w600
                            : FontWeight.w500,
                        decoration: failed ? TextDecoration.lineThrough : null,
                        decorationColor: Colors.white38,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(color: subFg, fontSize: 11),
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
                            PlayerSourceStatus.unchecked => '',
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
                    color: PlayerPopupTokens.accent,
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
      return Padding(padding: const EdgeInsets.only(bottom: 5), child: tile);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: FocusableControl(
        // Prefer the current value; else first row claims via fallback nextFocus.
        autoFocus:
            selected && PlayerPopupListFocusScope.claimAutofocus(context),
        focusNode: focusNode,
        onTap: onTap,
        borderRadius: PlayerPopupTokens.chipRadius,
        scaleOnFocus: 1.0,
        showFocusBorder: true,
        ensureVisibleMode: ShellTvEnsureVisibleMode.item,
        onLeftEdge: onLeftEdge,
        onRightEdge: onRightEdge,
        onUpEdge: onUpEdge,
        onDownEdge: onDownEdge,
        child: tile,
      ),
    );
  }
}
