import 'dart:async';

import 'package:flutter/material.dart';

import 'package:forja/shared/navigation/shell_back_icon_button.dart';
import 'package:forja/shared/player/controls/menus/player_menu_return_focus.dart';
import 'package:forja/shared/player/controls/chrome/player_seek_scrub_cancel.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja_foundation/widgets/feedback/frosted_panel.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
enum PlayerSourceStatus { unchecked, ready, active, failed, checking }

/// Desktop hybrid keeps mouse hover while D-pad focus is on; leanback does not.
({bool tvFocus, bool mouseHover, bool instantChrome}) _popupInput(
  BuildContext context,
) {
  final p = ShellScope.inputPolicyOf(context);
  return (
    tvFocus: p.useFocusableMoodChips,
    mouseHover: p.scaleOnHover,
    instantChrome: p.instantFocusChrome,
  );
}

/// Desktop: mouse → hover; keyboard/D-pad → focus chrome.
bool _popupHighlight(
  BuildContext context, {
  required bool hovered,
  required bool focused,
}) =>
    ShellInputPolicy.interactiveActive(
      ShellScope.inputPolicyOf(context),
      hovered: hovered,
      focused: focused,
      context: context,
    );

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
  /// Lift above the seekbar when the panel anchors to a transport button under it.
  /// Desktop IPTV chrome (seek row + padded round icons) needs ~56; leanback stays
  /// tighter so menus sit closer to the ATV control strip.
  static const _progressBarClearance = 56.0;
  static const _tvProgressBarClearance = 36.0;
  static const _tvMaxWidth = 280.0;
  static const _tvMaxHeight = 340.0;
  static const _tvFallbackMargin = EdgeInsets.only(left: 16, bottom: 72);

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

    // ATV: same anchored chrome as desktop, but smaller + tighter to the
    // seekbar — never enlarge or center. D-pad still works via TvOverlayScope.
    // Capture opener before dismiss clears the anchor.
    playerMenuCaptureReturnFocus(context);

    final leanback = capturedConfig.inputPolicy.leanbackOnly;
    final effectiveWidth = leanback ? width.clamp(0.0, _tvMaxWidth) : width;
    final effectiveMaxHeight =
        leanback ? maxHeight.clamp(0.0, _tvMaxHeight) : maxHeight;
    final effectiveMargin = leanback &&
            margin == const EdgeInsets.only(left: 16, bottom: 88)
        ? _tvFallbackMargin
        : margin;

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
                      clearance: leanback
                          ? _tvProgressBarClearance
                          : _progressBarClearance,
                    );

              final panel = Material(
                type: MaterialType.transparency,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: effectiveWidth,
                    maxHeight: anchorRect == null
                        ? effectiveMaxHeight
                        : _anchoredMaxHeight(
                            overlaySize: overlaySize,
                            anchorRect: anchorRect,
                            anchorGap: anchorGap,
                            screenPadding: screenPadding,
                            maxHeight: effectiveMaxHeight,
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
                final left = (anchorRect.center.dx - effectiveWidth / 2).clamp(
                  screenPadding.left,
                  overlaySize.width - effectiveWidth - screenPadding.right,
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
                        width: effectiveWidth,
                        child: panel,
                      )
                    : Positioned(
                        left: left,
                        top: anchorRect.bottom + anchorGap,
                        width: effectiveWidth,
                        child: panel,
                      );
              } else if (centered) {
                panelLayer = Center(
                  child: Padding(padding: screenPadding, child: panel),
                );
              } else {
                panelLayer = Align(
                  alignment: alignment,
                  child: Padding(padding: effectiveMargin, child: panel),
                );
              }

              return tvFocusableOverlay(
                overlayContext: scopedContext,
                onDismiss: popOrClose,
                autofocusFirst: !autofocusClose,
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
    required double clearance,
  }) {
    final anchorFromBottom =
        overlaySize.height - anchorRect.bottom - screenPadding.bottom;
    return anchorFromBottom < _bottomControlsZoneHeight ? clearance : 0.0;
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
    bool autofocusFirst = true,
  }) {
    return TvOverlayScope(
      enabled: ShellScope.maybeOf(overlayContext)
              ?.inputPolicy
              .useFocusableMoodChips ??
          false,
      // When Close claims open focus, skip nextFocus (would land on Off).
      autofocusFirst: autofocusFirst,
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

/// Close [FocusNode] for trailing chips (Off / tune → right → X).
class PlayerPopupCloseFocus extends InheritedWidget {
  const PlayerPopupCloseFocus({
    super.key,
    required this.focusNode,
    required super.child,
  });

  final FocusNode focusNode;

  static FocusNode? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PlayerPopupCloseFocus>()
        ?.focusNode;
  }

  static void request(BuildContext context) {
    final node = of(context);
    if (node != null && node.canRequestFocus) node.requestFocus();
  }

  @override
  bool updateShouldNotify(PlayerPopupCloseFocus oldWidget) =>
      focusNode != oldWidget.focusNode;
}

/// Floating-menu surface tokens - translucent dark chrome + brand-green accent.
/// Select cards: idle [cardBg], selected/hover/focus = green *tint* ([accentFill]),
/// never solid [accent] fill.
///
/// Type on TV maps to the shell ladder; spatial chrome uses [ShellTokens.tvChromeScale].
abstract final class PlayerPopupTokens {
  /// Same α as player side panels ([ForjaFrostedPanel] without blur).
  static const Color shellBg = Color(0xD1141414); // menuSurface @ ~0.82
  static const Color cardBg = Color(0xFF1A1A1A);
  static const Color border = Color(0xFF2A2A2A);
  static const Color accent = ForjaShellColors.brandGreen;
  static const Color accentFill = Color(0x291CE783); // green @ ~0.16
  static const Color accentBorder = Color(0x661CE783); // green @ ~0.40
  static const Color accentFg = Color(0xFF0A0A0A);
  static const Color selectedFill = accentFill;
  static const Color selectedFg = Colors.white;
  static const Color muted = Color(0xFF9CA3AF);

  static const double _s = ShellTokens.tvChromeScale;

  static const double shellRadius = 16;
  static const double shellRadiusTv = 10;
  static const double cardRadius = 12;
  static const double cardRadiusTv = 8;
  static const double chipRadius = 8;
  static const double chipRadiusTv = 5;
  static const double badgeRadius = 6;
  static const double badgeRadiusTv = 4;

  static const EdgeInsets selectCardPadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 11);
  static const EdgeInsets selectCardPaddingTv =
      EdgeInsets.symmetric(horizontal: 8, vertical: 7);
  static const EdgeInsets selectCardGap = EdgeInsets.only(bottom: 8);
  static const EdgeInsets selectCardGapTv = EdgeInsets.only(bottom: 5);

  static const double titleFontSize = 14;
  static const double titleFontSizeTv = ShellTokens.tvTitleFontSize;
  static const double optionFontSize = 13;
  static const double optionFontSizeTv = ShellTokens.tvBodyFontSize;
  static const double subtitleFontSize = 11;
  static const double subtitleFontSizeTv = ShellTokens.tvMetaFontSize;
  static const double chipFontSize = 12;
  static const double chipFontSizeTv = ShellTokens.tvBodyFontSize;
  static const double badgeFontSize = 10;
  static const double badgeFontSizeTv = ShellTokens.tvMetaFontSize;

  static const double headerBlockHeight = 52;
  static const double headerBlockHeightTv = 36;
  static const double headerPadH = 10;
  static const double headerPadHTv = 8;
  static const double headerPadTop = 10;
  static const double headerPadTopTv = 6;
  static const double headerPadBottom = 8;
  static const double headerPadBottomTv = 5;

  static const double chromeBtnSize = 28;
  static const double chromeBtnSizeTv = chromeBtnSize * _s;
  static const double chromeIconSize = 14;
  static const double chromeIconSizeTv = ShellTokens.tvTitleFontSize;
  static const double iconBoxSize = 28;
  static const double iconBoxSizeTv = iconBoxSize * _s;
  static const double iconBoxGlyphSize = 15;
  static const double iconBoxGlyphSizeTv = ShellTokens.tvTitleFontSize;
  static const double checkIconSize = 18;
  static const double checkIconSizeTv = checkIconSize * _s;
  static const double headerChipHeight = 28;
  static const double headerChipHeightTv = headerChipHeight * _s;

  static bool _tv(BuildContext context) =>
      ShellPaintScope.usesTvDensityOf(context);

  static double shellRadiusOf(BuildContext context) =>
      _tv(context) ? shellRadiusTv : shellRadius;

  static double cardRadiusOf(BuildContext context) =>
      _tv(context) ? cardRadiusTv : cardRadius;

  static double chipRadiusOf(BuildContext context) =>
      _tv(context) ? chipRadiusTv : chipRadius;

  static double badgeRadiusOf(BuildContext context) =>
      _tv(context) ? badgeRadiusTv : badgeRadius;

  static EdgeInsets selectCardPaddingOf(BuildContext context) =>
      _tv(context) ? selectCardPaddingTv : selectCardPadding;

  static EdgeInsets selectCardGapOf(BuildContext context) =>
      _tv(context) ? selectCardGapTv : selectCardGap;

  static double titleFontSizeOf(BuildContext context) =>
      _tv(context) ? titleFontSizeTv : titleFontSize;

  static double optionFontSizeOf(BuildContext context) =>
      _tv(context) ? optionFontSizeTv : optionFontSize;

  static double subtitleFontSizeOf(BuildContext context) =>
      _tv(context) ? subtitleFontSizeTv : subtitleFontSize;

  static double chipFontSizeOf(BuildContext context) =>
      _tv(context) ? chipFontSizeTv : chipFontSize;

  static double badgeFontSizeOf(BuildContext context) =>
      _tv(context) ? badgeFontSizeTv : badgeFontSize;

  static double headerBlockHeightOf(BuildContext context) =>
      _tv(context) ? headerBlockHeightTv : headerBlockHeight;

  static EdgeInsets headerPaddingOf(BuildContext context) => EdgeInsets.fromLTRB(
        _tv(context) ? headerPadHTv : headerPadH,
        _tv(context) ? headerPadTopTv : headerPadTop,
        _tv(context) ? 6 : 6,
        _tv(context) ? headerPadBottomTv : headerPadBottom,
      );

  static double chromeBtnSizeOf(BuildContext context) =>
      _tv(context) ? chromeBtnSizeTv : chromeBtnSize;

  static double chromeIconSizeOf(BuildContext context) =>
      _tv(context) ? chromeIconSizeTv : chromeIconSize;

  static double iconBoxSizeOf(BuildContext context) =>
      _tv(context) ? iconBoxSizeTv : iconBoxSize;

  static double iconBoxGlyphSizeOf(BuildContext context) =>
      _tv(context) ? iconBoxGlyphSizeTv : iconBoxGlyphSize;

  static double checkIconSizeOf(BuildContext context) =>
      _tv(context) ? checkIconSizeTv : checkIconSize;

  static double headerChipHeightOf(BuildContext context) =>
      _tv(context) ? headerChipHeightTv : headerChipHeight;
}

/// Shared idle / selected / hover-focus chrome for player select cards.
({Color bg, Color border, double borderWidth, Color labelFg})
playerPopupSelectChrome({
  required bool selected,
  required bool highlight,
  bool failed = false,
  bool disabled = false,
}) {
  if (disabled) {
    return (
      bg: PlayerPopupTokens.cardBg,
      border: PlayerPopupTokens.border,
      borderWidth: 1,
      labelFg: Colors.white.withValues(alpha: 0.38),
    );
  }
  if (failed) {
    return (
      bg: const Color(0xFFEF4444).withValues(alpha: 0.08),
      border: highlight ? PlayerPopupTokens.accent : PlayerPopupTokens.border,
      borderWidth: highlight ? 1.5 : 1,
      labelFg: Colors.white.withValues(alpha: 0.45),
    );
  }
  final active = highlight || selected;
  return (
    bg: active ? PlayerPopupTokens.accentFill : PlayerPopupTokens.cardBg,
    border: highlight
        ? PlayerPopupTokens.accent
        : selected
            ? PlayerPopupTokens.accentBorder
            : PlayerPopupTokens.border,
    borderWidth: highlight ? 1.5 : 1,
    labelFg: Colors.white,
  );
}

class _PanelShell extends StatefulWidget {
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
  State<_PanelShell> createState() => _PanelShellState();
}

class _PanelShellState extends State<_PanelShell> {
  late final FocusNode _closeFocus =
      FocusNode(debugLabel: 'player-popup-close');

  @override
  void initState() {
    super.initState();
    if (widget.autofocusClose) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_closeFocus.canRequestFocus) _closeFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _closeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    // One claim scope for header + list so Close can win over selected rows.
    return PlayerPopupListFocusScope(
      child: PlayerPopupCloseFocus(
        focusNode: _closeFocus,
        child: Builder(
          builder: (context) {
            final closeAutoFocus = tvFocus &&
                widget.autofocusClose &&
                PlayerPopupListFocusScope.claimAutofocus(context);
            final radius =
                BorderRadius.circular(PlayerPopupTokens.shellRadiusOf(context));
            return ClipRRect(
              borderRadius: radius,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.shellBg ?? PlayerPopupTokens.shellBg,
                  borderRadius: radius,
                  border: Border.all(color: PlayerPopupTokens.border),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bounded = constraints.maxHeight.isFinite;
                    final header = widget.showHeader
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding:
                                    PlayerPopupTokens.headerPaddingOf(context),
                                child: Row(
                                  children: [
                                    if (widget.onBack != null)
                                      ShellBackIconButton(
                                        icon: Icons.arrow_back_rounded,
                                        size:
                                            PlayerPopupTokens.chromeIconSizeOf(
                                          context,
                                        ),
                                        tooltip: 'Back',
                                        onTap: widget.onBack,
                                      )
                                    else if (widget.leadingIcon != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 4,
                                          right: 6,
                                        ),
                                        child: Icon(
                                          widget.leadingIcon,
                                          color: PlayerPopupTokens.muted,
                                          size: PlayerPopupTokens
                                              .chromeIconSizeOf(context),
                                        ),
                                      )
                                    else
                                      const SizedBox(width: 4),
                                    if (widget.title.isNotEmpty)
                                      Expanded(
                                        child: Text(
                                          widget.title,
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: PlayerPopupTokens
                                                .titleFontSizeOf(context),
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.15,
                                          ),
                                        ),
                                      )
                                    else
                                      const Spacer(),
                                    if (widget.trailing != null) ...[
                                      widget.trailing!,
                                      const SizedBox(width: 4),
                                    ],
                                    PlayerPopupChromeButton(
                                      icon: Icons.close_rounded,
                                      tooltip: 'Close',
                                      onTap: widget.onClose,
                                      focusNode: _closeFocus,
                                      autoFocus: closeAutoFocus,
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  color: PlayerPopupTokens.border,
                                ),
                              ),
                            ],
                          )
                        : null;
                    // Bounded height: Expanded body — never guess header px
                    // (tune chip / densify mismatches used to overflow by 8).
                    final shell = bounded
                        ? SizedBox(
                            height: constraints.maxHeight,
                            width: constraints.maxWidth.isFinite
                                ? constraints.maxWidth
                                : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ?header,
                                Expanded(child: widget.child),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ?header,
                              widget.child,
                            ],
                          );
                    if (!tvFocus) return shell;
                    return FocusTraversalGroup(child: shell);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Plain header icon (Close, subtitle tune) — no card border; glyph turns
/// brand-green on hover / focus.
class PlayerPopupChromeButton extends StatefulWidget {
  const PlayerPopupChromeButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.autoFocus = false,
    this.focusNode,
    this.onLeftEdge,
    this.onRightEdge,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool autoFocus;
  final FocusNode? focusNode;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  @override
  State<PlayerPopupChromeButton> createState() =>
      _PlayerPopupChromeButtonState();
}

class _PlayerPopupChromeButtonState extends State<PlayerPopupChromeButton> {
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _focused = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    if (_hoveredN.value == hovered) return;
    _hoveredN.value = hovered;
  }

  Widget _buildFace(bool hovered) {
    final highlight = _popupHighlight(
      context,
      hovered: hovered,
      focused: _focused,
    );
    final btn = PlayerPopupTokens.chromeBtnSizeOf(context);
    final icon = PlayerPopupTokens.chromeIconSizeOf(context);
    return SizedBox(
      width: btn,
      height: btn,
      child: Icon(
        widget.icon,
        size: icon,
        color: highlight ? PlayerPopupTokens.accent : PlayerPopupTokens.muted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final input = _popupInput(context);
    final tvFocus = input.tvFocus;
    final mouseHover = input.mouseHover;
    final chipRadius = PlayerPopupTokens.chipRadiusOf(context);
    final painted = ListenableBuilder(
      listenable: _hoveredN,
      builder: (context, _) => _buildFace(_hoveredN.value),
    );
    final button = MouseRegion(
      onEnter: (_) {
        if (mouseHover) _setHovered(true);
      },
      onExit: (_) {
        if (mouseHover) _setHovered(false);
      },
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(chipRadius),
        clipBehavior: Clip.antiAlias,
        child: tvFocus
            ? FocusableControl(
                focusNode: widget.focusNode,
                autoFocus: widget.autoFocus,
                onTap: widget.onTap,
                borderRadius: chipRadius,
                scaleOnFocus: 1.0,
                showFocusBorder: false,
                showFocusFill: false,
                onFocusChange: (f) => setState(() => _focused = f),
                onHoverChange: mouseHover ? _setHovered : null,
                onLeftEdge: widget.onLeftEdge,
                onRightEdge: widget.onRightEdge,
                child: painted,
              )
            : InkWell(
                onTap: widget.onTap,
                hoverColor: Colors.transparent,
                child: painted,
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
    final box = PlayerPopupTokens.iconBoxSizeOf(context);
    final glyph = PlayerPopupTokens.iconBoxGlyphSizeOf(context);
    final radius = PlayerPopupTokens.chipRadiusOf(context);
    return Container(
      width: box,
      height: box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent
            ? PlayerPopupTokens.accentFill
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: accent
              ? PlayerPopupTokens.accentBorder
              : PlayerPopupTokens.border,
        ),
      ),
      child: Icon(
        icon,
        size: glyph,
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
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _focused = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    if (_hoveredN.value == hovered) return;
    _hoveredN.value = hovered;
  }

  bool get _valueActive {
    if (widget.selected) return true;
    final v = widget.value?.trim().toLowerCase();
    if (v == null || v.isEmpty) return false;
    return v == 'on' ||
        v == 'auto' ||
        v == 'normal' ||
        (!v.contains('off') && v != '-');
  }

  Widget _buildRow(bool hovered) {
    final tvFocus = _popupInput(context).tvFocus;
    final highlight = _popupHighlight(
      context,
      hovered: hovered,
      focused: _focused,
    );
    final chrome = playerPopupSelectChrome(
      selected: widget.selected,
      highlight: highlight,
    );
    return Material(
      color: chrome.bg,
      borderRadius: BorderRadius.circular(PlayerPopupTokens.cardRadiusOf(context)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        canRequestFocus: false,
        onTap: tvFocus ? null : widget.onTap,
        borderRadius: BorderRadius.circular(PlayerPopupTokens.cardRadiusOf(context)),
        hoverColor: Colors.transparent,
        splashColor: ForjaShellColors.inkSplash,
        child: Container(
          padding: PlayerPopupTokens.selectCardPaddingOf(context),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              PlayerPopupTokens.cardRadiusOf(context),
            ),
            border: Border.all(
              color: chrome.border,
              width: chrome.borderWidth,
            ),
          ),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                PlayerPopupIconBox(
                  icon: widget.icon!,
                  accent: widget.selected || highlight,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: chrome.labelFg,
                        fontSize: PlayerPopupTokens.optionFontSizeOf(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          widget.subtitle!,
                          style: TextStyle(
                            color: highlight || widget.selected
                                ? PlayerPopupTokens.accent
                                    .withValues(alpha: 0.85)
                                : PlayerPopupTokens.muted,
                            fontSize:
                                PlayerPopupTokens.subtitleFontSizeOf(context),
                            height: 1.2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.value != null) ...[
                PlayerPopupValueBadge(
                  widget.value!,
                  accent: _valueActive || highlight,
                ),
                const SizedBox(width: 6),
              ],
              Icon(
                Icons.chevron_right_rounded,
                size: PlayerPopupTokens.checkIconSizeOf(context),
                color: highlight || widget.selected
                    ? PlayerPopupTokens.accent
                    : PlayerPopupTokens.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final input = _popupInput(context);
    final tvFocus = input.tvFocus;
    final mouseHover = input.mouseHover;
    final painted = ListenableBuilder(
      listenable: _hoveredN,
      builder: (context, _) => _buildRow(_hoveredN.value),
    );

    if (!tvFocus || widget.onTap == null) {
      if (!mouseHover) return painted;
      return MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: painted,
      );
    }
    return FocusableControl(
      // Same as list tiles — only the active choice claims open focus.
      autoFocus:
          widget.selected && PlayerPopupListFocusScope.claimAutofocus(context),
      onTap: widget.onTap,
      borderRadius: PlayerPopupTokens.cardRadiusOf(context),
      scaleOnFocus: 1.0,
      showFocusBorder: false,
      showFocusFill: false,
      ensureVisibleMode: ShellPaintEnsureVisible.item,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: mouseHover ? _setHovered : null,
      child: painted,
    );
  }
}

class PlayerPopupValueBadge extends StatelessWidget {
  const PlayerPopupValueBadge(this.label, {super.key, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tv ? 5 : 7,
        vertical: tv ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: accent ? PlayerPopupTokens.accentFill : Colors.transparent,
        borderRadius: BorderRadius.circular(
          PlayerPopupTokens.badgeRadiusOf(context),
        ),
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
          fontSize: PlayerPopupTokens.badgeFontSizeOf(context),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Option select card — same chrome as [PlayerPopupListTile] / [PlayerPopupNavRow].
class PlayerPopupOptionChip extends StatefulWidget {
  const PlayerPopupOptionChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.expanded = false,
    this.grouped = false,
    this.subtitle,
    this.disabled = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool expanded;

  /// Side-by-side group (On/Off, Fit) — skip the list-row bottom gap.
  final bool grouped;

  /// Secondary line (e.g. why an engine is unavailable for this stream).
  final String? subtitle;
  final bool disabled;

  @override
  State<PlayerPopupOptionChip> createState() => _PlayerPopupOptionChipState();
}

class _PlayerPopupOptionChipState extends State<PlayerPopupOptionChip> {
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _focused = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    if (_hoveredN.value == hovered) return;
    _hoveredN.value = hovered;
  }

  Widget _buildChip(bool hovered) {
    final input = _popupInput(context);
    final tvFocus = input.tvFocus;
    final selected = widget.selected;
    final highlight = !widget.disabled &&
        _popupHighlight(
          context,
          hovered: hovered,
          focused: _focused,
        );
    final chromeDuration = input.instantChrome
        ? Duration.zero
        : const Duration(milliseconds: 120);
    final chrome = playerPopupSelectChrome(
      selected: selected,
      highlight: highlight,
      disabled: widget.disabled,
    );
    final radius = widget.grouped
        ? PlayerPopupTokens.chipRadiusOf(context)
        : PlayerPopupTokens.cardRadiusOf(context);
    final padding = widget.grouped
        ? EdgeInsets.symmetric(
            horizontal: ShellPaintScope.usesTvDensityOf(context) ? 8 : 11,
            vertical: ShellPaintScope.usesTvDensityOf(context) ? 5 : 8,
          )
        : PlayerPopupTokens.selectCardPaddingOf(context);
    final subtitle = widget.subtitle?.trim();
    final hasSubtitle = subtitle != null && subtitle.isNotEmpty;
    // Check slot must fit TV-dense padding without stretching selected rows
    // taller than idle ones (desktop 18 was hard-coded and blew past leanback).
    final checkSize = PlayerPopupTokens.checkIconSizeOf(context);

    Widget labelColumn() {
      final title = Text(
        widget.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: chrome.labelFg,
          fontSize: PlayerPopupTokens.optionFontSizeOf(context),
          fontWeight: highlight || selected
              ? FontWeight.w600
              : FontWeight.w500,
        ),
      );
      if (!hasSubtitle) return title;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          title,
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: chrome.labelFg.withValues(alpha: 0.72),
              fontSize: PlayerPopupTokens.subtitleFontSizeOf(context),
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ],
      );
    }

    return Material(
      color: chrome.bg,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        canRequestFocus: false,
        onTap: tvFocus ? null : widget.onTap,
        borderRadius: BorderRadius.circular(radius),
        hoverColor: Colors.transparent,
        splashColor: ForjaShellColors.inkSplash,
        child: AnimatedContainer(
          duration: chromeDuration,
          curve: Curves.easeOut,
          width: widget.expanded ? double.infinity : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            // Fixed width — selected/focus used to bump 1→1.5 and stretch the
            // card; color + fill already mark the active choice.
            border: Border.all(color: chrome.border, width: 1),
          ),
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: checkSize),
            child: Row(
              mainAxisSize:
                  widget.expanded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (widget.expanded)
                  Expanded(child: labelColumn())
                else
                  labelColumn(),
                if (selected && !widget.disabled) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: checkSize,
                    height: checkSize,
                    child: Icon(
                      Icons.check_rounded,
                      color: PlayerPopupTokens.accent,
                      size: checkSize,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final input = _popupInput(context);
    final tvFocus = input.tvFocus;
    final mouseHover = input.mouseHover;
    final painted = ListenableBuilder(
      listenable: _hoveredN,
      builder: (context, _) => _buildChip(_hoveredN.value),
    );

    if (!tvFocus || widget.onTap == null) {
      final body = !mouseHover
          ? painted
          : MouseRegion(
              onEnter: (_) => _setHovered(true),
              onExit: (_) => _setHovered(false),
              child: painted,
            );
      return widget.grouped
          ? body
          : Padding(
              padding: PlayerPopupTokens.selectCardGapOf(context),
              child: body,
            );
    }
    return Padding(
      padding: widget.grouped
          ? EdgeInsets.zero
          : PlayerPopupTokens.selectCardGapOf(context),
      child: FocusableControl(
        autoFocus: widget.selected &&
            PlayerPopupListFocusScope.claimAutofocus(context),
        onTap: widget.onTap,
        borderRadius: widget.grouped
            ? PlayerPopupTokens.chipRadiusOf(context)
            : PlayerPopupTokens.cardRadiusOf(context),
        scaleOnFocus: 1.0,
        showFocusBorder: false,
        showFocusFill: false,
        ensureVisibleMode: ShellPaintEnsureVisible.item,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onHoverChange: mouseHover ? _setHovered : null,
        child: painted,
      ),
    );
  }
}

/// Compact header chip (Off / File) — same tint/check chrome as option rows.
class PlayerPopupHeaderChip extends StatefulWidget {
  const PlayerPopupHeaderChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.focusNode,
    this.onRightEdge,
    this.autoFocus = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final FocusNode? focusNode;
  final VoidCallback? onRightEdge;
  final bool autoFocus;

  @override
  State<PlayerPopupHeaderChip> createState() => _PlayerPopupHeaderChipState();
}

class _PlayerPopupHeaderChipState extends State<PlayerPopupHeaderChip> {
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _focused = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    if (_hoveredN.value == hovered) return;
    _hoveredN.value = hovered;
  }

  Widget _buildFace(bool hovered) {
    final selected = widget.selected;
    final highlight = _popupHighlight(
      context,
      hovered: hovered,
      focused: _focused,
    );
    final chrome = playerPopupSelectChrome(
      selected: selected,
      highlight: highlight,
    );
    final fg = selected || highlight
        ? (selected ? PlayerPopupTokens.accent : Colors.white)
        : PlayerPopupTokens.muted;
    return Container(
      height: PlayerPopupTokens.headerChipHeightOf(context),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(
        horizontal: ShellPaintScope.usesTvDensityOf(context) ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: chrome.bg,
        borderRadius: BorderRadius.circular(
          PlayerPopupTokens.chipRadiusOf(context),
        ),
        border: Border.all(color: chrome.border, width: chrome.borderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(
              widget.icon,
              size: PlayerPopupTokens.chromeIconSizeOf(context),
              color: fg,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            widget.label,
            style: TextStyle(
              color: fg,
              fontSize: PlayerPopupTokens.chipFontSizeOf(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.check_rounded,
              size: PlayerPopupTokens.chromeIconSizeOf(context),
              color: PlayerPopupTokens.accent,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final input = _popupInput(context);
    final tvFocus = input.tvFocus;
    final mouseHover = input.mouseHover;
    final painted = ListenableBuilder(
      listenable: _hoveredN,
      builder: (context, _) => _buildFace(_hoveredN.value),
    );
    if (!tvFocus) {
      final chipRadius = PlayerPopupTokens.chipRadiusOf(context);
      return MouseRegion(
        onEnter: (_) {
          if (mouseHover) _setHovered(true);
        },
        onExit: (_) {
          if (mouseHover) _setHovered(false);
        },
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(chipRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(chipRadius),
            hoverColor: Colors.transparent,
            child: painted,
          ),
        ),
      );
    }
    return FocusableControl(
      autoFocus: widget.autoFocus,
      focusNode: widget.focusNode,
      onTap: widget.onTap,
      borderRadius: PlayerPopupTokens.chipRadiusOf(context),
      scaleOnFocus: 1.0,
      showFocusBorder: false,
      showFocusFill: false,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: mouseHover ? _setHovered : null,
      onRightEdge: widget.onRightEdge,
      child: painted,
    );
  }
}

class PlayerPopupListTile extends StatefulWidget {
  const PlayerPopupListTile({
    super.key,
    required this.label,
    this.leading,
    this.badge,
    this.badgeColor,
    this.subtitle,
    this.selected = false,
    this.autofocusIfSelected = true,
    this.status,
    this.trailing,
    this.onTap,
    this.focusNode,
    this.onLeftEdge,
    this.onRightEdge,
    this.onUpEdge,
    this.onDownEdge,
    this.onInteractiveChange,
  });

  final String label;
  /// Optional leading mark (e.g. channel logo).
  final Widget? leading;
  final String? badge;
  final Color? badgeColor;
  final String? subtitle;
  final bool selected;
  /// When false, [selected] is visual-only (e.g. language column while the
  /// track column owns TV open focus).
  final bool autofocusIfSelected;
  final PlayerSourceStatus? status;
  final Widget? trailing;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  /// Fired when hover or TV focus becomes active/inactive.
  final ValueChanged<bool>? onInteractiveChange;

  @override
  State<PlayerPopupListTile> createState() => _PlayerPopupListTileState();
}

class _PlayerPopupListTileState extends State<PlayerPopupListTile> {
  static const double _statusSlot = 18;

  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _focused = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    if (_hoveredN.value == hovered) return;
    final wasActive = _popupHighlight(
      context,
      hovered: _hoveredN.value,
      focused: _focused,
    );
    _hoveredN.value = hovered;
    final nextActive = _popupHighlight(
      context,
      hovered: hovered,
      focused: _focused,
    );
    if (wasActive != nextActive) {
      widget.onInteractiveChange?.call(nextActive);
    }
  }

  void _setFocused(bool focused) {
    if (_focused == focused) return;
    final wasActive = _popupHighlight(
      context,
      hovered: _hoveredN.value,
      focused: _focused,
    );
    setState(() => _focused = focused);
    final nextActive = _popupHighlight(
      context,
      hovered: _hoveredN.value,
      focused: focused,
    );
    if (wasActive != nextActive) {
      widget.onInteractiveChange?.call(nextActive);
    }
  }

  Widget? _statusGlyph() {
    final status = widget.status;
    if (status == null) return null;
    final color = playerSourceStatusColor(status);
    final Widget glyph = switch (status) {
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

  Widget _buildTile(bool hovered) {
    final failed = widget.status == PlayerSourceStatus.failed;
    final active = widget.status == PlayerSourceStatus.active;
    final selected = widget.selected;
    final statusGlyph = _statusGlyph();
    final input = _popupInput(context);
    final tvFocus = input.tvFocus;
    final highlight = _popupHighlight(
      context,
      hovered: hovered,
      focused: _focused,
    );
    final chromeDuration = input.instantChrome
        ? Duration.zero
        : const Duration(milliseconds: 120);
    final chrome = playerPopupSelectChrome(
      selected: selected || active,
      highlight: highlight,
      failed: failed,
    );
    final fg = chrome.labelFg;
    final subFg = highlight || selected || active
        ? PlayerPopupTokens.accent.withValues(alpha: 0.85)
        : PlayerPopupTokens.muted;

    final badgeOnRight = widget.leading != null;
    Widget? badgeChip;
    if (widget.badge != null) {
      final solid = widget.badgeColor;
      final useSolid = solid != null;
      badgeChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: useSolid
              ? solid
              : highlight || selected || active
              ? PlayerPopupTokens.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(PlayerPopupTokens.badgeRadius),
          border: useSolid
              ? null
              : Border.all(
                  color: highlight || selected || active
                      ? PlayerPopupTokens.accentBorder
                      : PlayerPopupTokens.border,
                ),
        ),
        child: Text(
          widget.badge!,
          style: TextStyle(
            color: useSolid
                ? Colors.white
                : highlight || selected || active
                ? PlayerPopupTokens.accent
                : PlayerPopupTokens.muted,
            fontSize: PlayerPopupTokens.badgeFontSizeOf(context),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    final cardRadius = PlayerPopupTokens.cardRadiusOf(context);
    return Material(
      color: chrome.bg,
      borderRadius: BorderRadius.circular(cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        canRequestFocus: false,
        onTap: tvFocus ? null : widget.onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        hoverColor: Colors.transparent,
        splashColor: ForjaShellColors.inkSplash,
        child: AnimatedContainer(
          duration: chromeDuration,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(
              color: chrome.border,
              width: chrome.borderWidth,
            ),
          ),
          padding: PlayerPopupTokens.selectCardPaddingOf(context),
          child: Row(
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 10),
              ],
              if (!badgeOnRight && badgeChip != null) ...[
                badgeChip,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: PlayerPopupTokens.optionFontSizeOf(context),
                        fontWeight: highlight || selected || active
                            ? FontWeight.w600
                            : FontWeight.w500,
                        decoration: failed ? TextDecoration.lineThrough : null,
                        decorationColor: Colors.white38,
                      ),
                    ),
                    if (widget.subtitle != null)
                      Text(
                        widget.subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subFg,
                          fontSize:
                              PlayerPopupTokens.subtitleFontSizeOf(context),
                        ),
                      ),
                    if (widget.status != null &&
                        widget.status != PlayerSourceStatus.ready &&
                        widget.status != PlayerSourceStatus.unchecked)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          switch (widget.status!) {
                            PlayerSourceStatus.active => 'Playing',
                            PlayerSourceStatus.failed => 'Unavailable',
                            PlayerSourceStatus.checking => 'Checking…',
                            PlayerSourceStatus.ready ||
                            PlayerSourceStatus.unchecked => '',
                          },
                          style: TextStyle(
                            color: selected || highlight
                                ? subFg
                                : playerSourceStatusColor(widget.status!),
                            fontSize:
                                PlayerPopupTokens.badgeFontSizeOf(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                SizedBox(
                  width: _statusSlot,
                  height: _statusSlot,
                  child: Icon(
                    Icons.check_rounded,
                    color: PlayerPopupTokens.accent,
                    size: PlayerPopupTokens.checkIconSizeOf(context),
                  ),
                ),
              ] else if (statusGlyph != null) ...[
                const SizedBox(width: 6),
                statusGlyph,
              ] else if (widget.trailing != null) ...[
                const SizedBox(width: 6),
                widget.trailing!,
              ],
              if (badgeOnRight && badgeChip != null) ...[
                const SizedBox(width: 8),
                badgeChip,
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final input = _popupInput(context);
    final tvFocus = input.tvFocus;
    final mouseHover = input.mouseHover;
    final painted = ListenableBuilder(
      listenable: _hoveredN,
      builder: (context, _) => _buildTile(_hoveredN.value),
    );

    Widget body = painted;
    if (!tvFocus || widget.onTap == null) {
      if (mouseHover) {
        body = MouseRegion(
          onEnter: (_) => _setHovered(true),
          onExit: (_) => _setHovered(false),
          child: painted,
        );
      }
      return Padding(
        padding: PlayerPopupTokens.selectCardGapOf(context),
        child: body,
      );
    }

    return Padding(
      padding: PlayerPopupTokens.selectCardGapOf(context),
      child: FocusableControl(
        // Prefer the current value; else first row claims via fallback nextFocus.
        autoFocus: widget.autofocusIfSelected &&
            widget.selected &&
            PlayerPopupListFocusScope.claimAutofocus(context),
        focusNode: widget.focusNode,
        onTap: widget.onTap,
        borderRadius: PlayerPopupTokens.cardRadiusOf(context),
        scaleOnFocus: 1.0,
        // Tile paints brand-green focus itself — skip gray/white overlay.
        showFocusBorder: false,
        showFocusFill: false,
        ensureVisibleMode: ShellPaintEnsureVisible.item,
        onFocusChange: _setFocused,
        onHoverChange: mouseHover ? _setHovered : null,
        onLeftEdge: widget.onLeftEdge,
        onRightEdge: widget.onRightEdge,
        onUpEdge: widget.onUpEdge,
        onDownEdge: widget.onDownEdge,
        child: painted,
      ),
    );
  }
}
