import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja/shell/focus/forja_interactive.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/guide/guide_chrome_style.dart';
import 'package:forja_foundation/widgets/guide/guide_focus_paint.dart';

/// D-pad / focus-graph surface (leanback **and** desktop hybrid).
///
/// Do **not** use this to hide mouse hover chrome (pin-on-hover, portal
/// action rails, MouseRegion). Desktop hybrid has `useFocusableMoodChips`
/// too — gate pointer UX with [liveLeanbackOnly] instead.
bool liveUseTvFocus(BuildContext context) {
  final policy = ShellScope.maybeOf(context)?.inputPolicy;
  if (policy != null) return policy.useFocusableMoodChips;
  return resolveShellProfile(context) == ShellProfile.tv;
}

/// Leanback TV (no mouse) — not desktop D-pad focus (which also uses mood chips).
///
/// Use for: hide pin until hold-OK, skip MouseRegion hover reveal, snap
/// animations, TV-only autofocus. Desktop hybrid must keep hover.
bool liveLeanbackOnly(BuildContext context) {
  final policy = ShellScope.maybeOf(context)?.inputPolicy;
  if (policy != null) {
    return policy.useFocusableMoodChips && !policy.scaleOnHover;
  }
  return resolveShellProfile(context) == ShellProfile.tv;
}

/// Volume, fullscreen, PiP — desktop + phone; hidden on leanback TV.
bool liveShowPointerChrome(BuildContext context) =>
    !liveLeanbackOnly(context);

/// D-pad / hover active state for IPTV focusable controls.
bool liveFocusActive(
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

/// TV D-pad / keyboard focus chrome — not mouse-retained focus on desktop.
bool liveTvFocused(BuildContext context, {required bool focused}) {
  if (!liveUseTvFocus(context) || !focused) return false;
  return ShellScope.inputPolicyOf(context)
      .focusChromeVisible(context, focused: focused);
}

/// Focus a registered live/portal row item (restores last index when [index] is null).
bool liveFocusRowItem(String rowId, [int? index]) {
  final handle = ShellTvFocusCoordinator.rowHandle('iptv', rowId);
  if (handle == null || handle.itemCount <= 0) return false;
  final idx = (index ?? handle.lastFocusedIndex).clamp(0, handle.itemCount - 1);
  return ShellTvFocusCoordinator.focusRowItem('iptv', rowId, idx);
}

/// List index of the active (playing) portal, or `0` when none is selected.
/// Arm the channel pane's D-pad memory at [index] without moving focus.
///
/// Catalog restore on open keeps focus on the category rail; this makes the
/// first → land on the restored channel instead of the first tile.
/// Returns false while the row is not registered yet (caller should retry).
bool liveArmBrowserStreamFocusMemory(int index) {
  if (index < 0) return false;
  // Pack layout row id is `items` (pre-wipe used `browser-streams`).
  const rowId = 'items';
  final tab = ShellTvFocus.currentNavTabId ?? 'iptv';
  final handle = ShellTvFocusCoordinator.rowHandle(tab, rowId);
  if (handle == null || handle.itemCount <= index) return false;
  ShellTvFocusCoordinator.setRowLastFocusedIndex(tab, rowId, index);
  return true;
}

/// Focus a catalog channel tile after leaving the player (exact index only).
///
/// Does not fall back to tile 0 — callers must scroll the lazy grid into view
/// and retry until the target node is registered.
bool liveFocusBrowserStreamAt(int index) {
  if (index < 0) return false;
  const rowId = 'items';
  final tab = ShellTvFocus.currentNavTabId ?? 'iptv';
  ShellTvFocusCoordinator.setRowLastFocusedIndex(tab, rowId, index);
  return ShellTvFocusCoordinator.focusRowItemExact(tab, rowId, index);
}

Widget liveTap({
  required BuildContext context,
  required Widget child,
  VoidCallback? onTap,
  double borderRadius = 12,
  double? scaleOnFocus,
  int? listIndex,
  int? gridIndex,
  int? gridColumns,
  bool navLeftAlways = false,
  String? tvTabId,
  String? tvRowId,
  int? tvItemIndex,
  ShellTvZone? tvZone,
  FocusNode? focusNode,
  VoidCallback? onLeftEdge,
  VoidCallback? onRightEdge,
  VoidCallback? onUpEdge,
  VoidCallback? onDownEdge,
  ValueChanged<bool>? onFocusChange,
  ValueChanged<bool>? onHoverChange,
  bool showFocusBorder = false,
  bool suppressInkHover = false,
  bool allowNestedFocus = false,
  FocusOnKeyEventCallback? onKeyEvent,
  ShellPaintEnsureVisible ensureVisibleMode = ShellPaintEnsureVisible.row,
}) {
  if (onTap == null) return child;
  final resolvedScale = scaleOnFocus ??
      (liveUseTvFocus(context) ? 1.0 : ShellTokens.focusActiveScale);
  return shellFocusableTap(
    context: context,
    onTap: onTap,
    borderRadius: borderRadius,
    scaleOnFocus: resolvedScale,
    listIndex: listIndex,
    gridIndex: gridIndex,
    gridColumns: gridColumns,
    navLeftAlways: navLeftAlways,
    tvTabId: tvTabId ?? 'iptv',
    tvRowId: tvRowId,
    tvItemIndex: tvItemIndex ?? listIndex ?? gridIndex,
    tvZone: tvZone ?? (tvRowId != null ? ShellTvZone.row : null),
    focusNode: focusNode,
    onLeftEdge: onLeftEdge,
    onRightEdge: onRightEdge,
    onUpEdge: onUpEdge,
    onDownEdge: onDownEdge,
    onFocusChange: onFocusChange,
    onHoverChange: onHoverChange,
    showFocusBorder: showFocusBorder,
    suppressInkHover: suppressInkHover,
    allowNestedFocus: allowNestedFocus,
    onKeyEvent: onKeyEvent,
    ensureVisibleMode: ensureVisibleMode,
    child: child,
  );
}

/// Registers an IPTV catalog row via [TvKitRow].
Widget liveCatalogRow({
  required String rowId,
  required int sortOrder,
  required int itemCount,
  required Widget child,
  VoidCallback? onFocusUp,
  ShellTvRowOrientation orientation = ShellTvRowOrientation.horizontal,
}) {
  return TvKitRow(
    tabId: 'iptv',
    rowId: rowId,
    sortOrder: sortOrder,
    itemCount: itemCount,
    onFocusUp: onFocusUp,
    orientation: orientation,
    registerWhen: liveUseTvFocus,
    child: child,
  );
}

/// Imperative register for chrome that syncs before focus (player / dispose).
/// Prefer [liveCatalogRow] when wrapping a subtree.
void liveSyncRow({
  required String rowId,
  required int sortOrder,
  required int itemCount,
  VoidCallback? onFocusUp,
  ShellTvRowOrientation orientation = ShellTvRowOrientation.horizontal,
}) {
  if (itemCount <= 0) {
    shellTvUnregisterRow(tabId: 'iptv', rowId: rowId);
    return;
  }
  shellTvRegisterRow(
    tabId: 'iptv',
    rowId: rowId,
    sortOrder: sortOrder,
    itemCount: itemCount,
    onFocusUp: onFocusUp,
    orientation: orientation,
  );
}

Widget liveBackButton(
  BuildContext context, {
  required VoidCallback? onTap,
  Color color = Colors.white70,
  double size = 22,
  String tooltip = 'Back',
  FocusNode? focusNode,
  String? tvRowId,
  int? tvItemIndex,
  VoidCallback? onUpEdge,
  VoidCallback? onDownEdge,
  VoidCallback? onLeftEdge,
  VoidCallback? onRightEdge,
  ValueChanged<bool>? onFocusChange,
}) {
  if (onTap == null) return const SizedBox.shrink();
  if (liveUseTvFocus(context)) {
    return _FocusIconTap(
      icon: Icons.arrow_back_rounded,
      onTap: onTap,
      idleColor: color,
      size: size,
      hitSize: size + 12,
      borderRadius: 22,
      tooltip: tooltip,
      focusNode: focusNode,
      tvRowId: tvRowId,
      tvItemIndex: tvItemIndex,
      onUpEdge: onUpEdge,
      onDownEdge: onDownEdge,
      onLeftEdge: onLeftEdge,
      onRightEdge: onRightEdge,
      onFocusChange: onFocusChange,
    );
  }
  return Button(
    variant: ButtonVariant.plainIcon,
    size: ButtonSize.icon,
    icon: Icons.arrow_back_rounded,
    onPressed: onTap,
    color: color,
    iconSize: size,
    tooltip: tooltip,
  );
}

Widget liveCloseButton(
  BuildContext context, {
  required VoidCallback? onTap,
  Color? color,
  double size = 18,
  double hitSize = 32,
}) {
  if (onTap == null) return const SizedBox.shrink();
  final idle = color ?? Colors.white54;
  if (liveUseTvFocus(context)) {
    return _FocusIconTap(
      icon: Icons.close_rounded,
      onTap: onTap,
      idleColor: idle,
      size: size,
      hitSize: hitSize,
      borderRadius: hitSize / 2,
    );
  }
  return Button(
    variant: ButtonVariant.plainIcon,
    size: ButtonSize.icon,
    icon: Icons.close_rounded,
    compact: true,
    color: idle,
    iconSize: size,
    height: hitSize,
    onPressed: onTap,
  );
}

class _FocusIconTap extends StatefulWidget {
  const _FocusIconTap({
    required this.icon,
    required this.onTap,
    required this.idleColor,
    required this.size,
    required this.hitSize,
    required this.borderRadius,
    this.tooltip,
    this.focusNode,
    this.tvRowId,
    this.tvItemIndex,
    this.onUpEdge,
    this.onDownEdge,
    this.onLeftEdge,
    this.onRightEdge,
    this.onFocusChange,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color idleColor;
  final double size;
  final double hitSize;
  final double borderRadius;
  final String? tooltip;
  final FocusNode? focusNode;
  final String? tvRowId;
  final int? tvItemIndex;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final ValueChanged<bool>? onFocusChange;

  @override
  State<_FocusIconTap> createState() => _FocusIconTapState();
}

class _FocusIconTapState extends State<_FocusIconTap> {
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

  bool _activeFor(bool hovered) =>
      liveFocusActive(context, hovered: hovered, focused: _focused);

  bool get _tvFocused =>
      liveTvFocused(context, focused: _focused);

  Widget _buildBody(bool hovered) {
    final policy = ShellScope.inputPolicyOf(context);
    final active = _activeFor(hovered);
    final pointerActive = active && !_tvFocused;
    final fg = _tvFocused
        ? ForjaShellColors.brandGreen
        : pointerActive
        ? ForjaShellColors.iconHover
        : widget.idleColor;
    Widget body = SizedBox(
      width: widget.hitSize,
      height: widget.hitSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: guideFocusSurfaceColor(
            active: active,
            tvFocused: _tvFocused,
            idleAlpha: 0,
            hoverAlpha: 0.14,
          ),
          border: _tvFocused
              ? Border.all(color: ForjaShellColors.brandGreen, width: 1.5)
              : null,
        ),
        child: Center(
          child: Icon(widget.icon, size: widget.size, color: fg),
        ),
      ),
    );
    if (policy.scaleOnHover && pointerActive) {
      body = AnimatedScale(
        scale: 1.15,
        duration: policy.instantFocusChrome
            ? Duration.zero
            : const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: body,
      );
    }
    return body;
  }

  @override
  Widget build(BuildContext context) {
    final tap = liveTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: widget.borderRadius,
      focusNode: widget.focusNode,
      tvRowId: widget.tvRowId,
      tvItemIndex: widget.tvItemIndex,
      onUpEdge: widget.onUpEdge,
      onDownEdge: widget.onDownEdge,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onFocusChange: (focused) {
        setState(() => _focused = focused);
        widget.onFocusChange?.call(focused);
      },
      onHoverChange: _setHovered,
      child: ListenableBuilder(
        listenable: _hoveredN,
        builder: (context, _) => _buildBody(_hoveredN.value),
      ),
    );
    if (widget.tooltip == null) return tap;
    return Tooltip(message: widget.tooltip!, child: tap);
  }
}

class FocusIconAction extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final double iconSize;
  final String? tvRowId;
  final int? tvItemIndex;
  final ShellTvZone? tvZone;
  final VoidCallback? onDownEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  const FocusIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.iconSize = 24,
    this.tvRowId,
    this.tvItemIndex,
    this.tvZone,
    this.onDownEdge,
    this.onUpEdge,
    this.onLeftEdge,
    this.onRightEdge,
  });

  @override
  State<FocusIconAction> createState() => _FocusIconActionState();
}

class _FocusIconActionState extends State<FocusIconAction> {
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

  bool _activeFor(bool hovered) =>
      liveFocusActive(context, hovered: hovered, focused: _focused);

  bool get _tvFocused =>
      liveTvFocused(context, focused: _focused);

  /// Idle: muted gray (or brand green when caller marks active).
  /// Hover / TV focus: brand green. Never idle near-white accent.
  Color get _idleColor {
    final c = widget.color;
    if (c == null) return ForjaShellColors.textSecondary;
    if (c == GuideChromeStyle.accent) return ForjaShellColors.brandGreen;
    return c;
  }

  Color _fg({required bool active, required bool tvFocused}) {
    if (tvFocused || active) return ForjaShellColors.brandGreen;
    return _idleColor;
  }

  Widget _icon(Color fg) => Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(widget.icon, color: fg, size: widget.iconSize),
      );

  @override
  Widget build(BuildContext context) {
    if (liveUseTvFocus(context)) {
      return liveTap(
        context: context,
        onTap: widget.onPressed,
        borderRadius: 24,
        tvRowId: widget.tvRowId,
        tvItemIndex: widget.tvItemIndex,
        tvZone: widget.tvZone,
        onDownEdge: widget.onDownEdge,
        onUpEdge: widget.onUpEdge,
        onLeftEdge: widget.onLeftEdge,
        onRightEdge: widget.onRightEdge,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onHoverChange: _setHovered,
        child: ListenableBuilder(
          listenable: _hoveredN,
          builder: (context, _) {
            final fg = _fg(
              active: _activeFor(_hoveredN.value),
              tvFocused: _tvFocused,
            );
            return Tooltip(
              message: widget.tooltip,
              child: _icon(fg),
            );
          },
        ),
      );
    }
    return ForjaInteractive(
      onTap: widget.onPressed,
      hoverScale: 1.08,
      pressScale: 0.88,
      builder: (hover, pressed) {
        final fg = _fg(active: hover || pressed, tvFocused: false);
        return Tooltip(
          message: widget.tooltip,
          child: _icon(fg),
        );
      },
    );
  }
}

class FocusTextAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  const FocusTextAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  State<FocusTextAction> createState() => _FocusTextActionState();
}

class _FocusTextActionState extends State<FocusTextAction> {
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

  bool _activeFor(bool hovered) =>
      liveFocusActive(context, hovered: hovered, focused: _focused);

  bool get _tvFocused =>
      liveTvFocused(context, focused: _focused);

  @override
  Widget build(BuildContext context) {
    final idle = widget.color ?? GuideChromeStyle.accent;
    if (liveUseTvFocus(context)) {
      return liveTap(
        context: context,
        onTap: widget.onPressed,
        borderRadius: 8,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onHoverChange: _setHovered,
        child: ListenableBuilder(
          listenable: _hoveredN,
          builder: (context, _) {
            final fg = guideFocusFg(
              idle,
              active: _activeFor(_hoveredN.value),
              tvFocused: _tvFocused,
            );
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: fg, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    widget.label,
                    style: GoogleFonts.plusJakartaSans(color: fg),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
    return TextButton.icon(
      onPressed: widget.onPressed,
      icon: Icon(widget.icon, color: idle, size: 18),
      label: Text(widget.label, style: GoogleFonts.plusJakartaSans(color: idle)),
    );
  }
}

class FocusPrimaryButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool subtle;
  final String? tvRowId;
  final int? tvItemIndex;
  final FocusNode? focusNode;
  final bool dense;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  const FocusPrimaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.subtle = false,
    this.tvRowId,
    this.tvItemIndex,
    this.focusNode,
    this.dense = false,
    this.onUpEdge,
    this.onDownEdge,
    this.onLeftEdge,
    this.onRightEdge,
  });

  @override
  State<FocusPrimaryButton> createState() => _FocusPrimaryButtonState();
}

class _FocusPrimaryButtonState extends State<FocusPrimaryButton> {
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

  bool _activeFor(bool hovered) =>
      liveFocusActive(context, hovered: hovered, focused: _focused);

  bool get _tvFocused =>
      liveTvFocused(context, focused: _focused);

  @override
  Widget build(BuildContext context) {
    final tv = liveUseTvFocus(context);
    return Material(
      color: Colors.transparent,
      child: liveTap(
        context: context,
        onTap: widget.busy ? null : widget.onPressed,
        borderRadius: 14,
        tvRowId: widget.tvRowId,
        tvItemIndex: widget.tvItemIndex,
        focusNode: widget.focusNode,
        onUpEdge: widget.onUpEdge,
        onDownEdge: widget.onDownEdge,
        onLeftEdge: widget.onLeftEdge,
        onRightEdge: widget.onRightEdge,
        onFocusChange: tv
            ? (focused) => setState(() => _focused = focused)
            : null,
        onHoverChange: tv ? _setHovered : null,
        child: ListenableBuilder(
          listenable: _hoveredN,
          builder: (context, _) {
            final active = _activeFor(_hoveredN.value);
            final decoration = tv
                ? guideFocusButtonDecoration(
                    active: active,
                    tvFocused: _tvFocused,
                    borderRadius: 14,
                    subtle: widget.subtle,
                  )
                : GuideChromeStyle.primaryButtonDecoration(
                    subtle: widget.subtle,
                  );
            final fg = _tvFocused ? ForjaShellColors.brandGreen : Colors.white;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              decoration: decoration,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: widget.dense ? 10 : 14,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.busy)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: fg,
                        ),
                      )
                    else
                      Icon(widget.icon, color: fg, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: GoogleFonts.plusJakartaSans(
                        color: fg,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class FocusRoundIcon extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool big;
  final String? tvRowId;
  final int? tvItemIndex;
  final FocusNode? focusNode;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  const FocusRoundIcon({
    super.key,
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.big = false,
    this.tvRowId,
    this.tvItemIndex,
    this.focusNode,
    this.onUpEdge,
    this.onDownEdge,
    this.onLeftEdge,
    this.onRightEdge,
  });

  @override
  State<FocusRoundIcon> createState() => _FocusRoundIconState();
}

class _FocusRoundIconState extends State<FocusRoundIcon> {
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

  bool _activeFor(bool hovered) =>
      liveFocusActive(context, hovered: hovered, focused: _focused);

  bool get _tvFocused => liveTvFocused(context, focused: _focused);

  @override
  Widget build(BuildContext context) {
    final size = widget.big ? 56.0 : 44.0;
    if (liveUseTvFocus(context)) {
      return ListenableBuilder(
        listenable: _hoveredN,
        builder: (context, _) {
          final active = _activeFor(_hoveredN.value);
          final fg = guideFocusFg(
            Colors.white,
            active: active,
            tvFocused: _tvFocused,
          );
          final shape = CircleBorder(
            side: _tvFocused
                ? const BorderSide(color: ForjaShellColors.brandGreen, width: 1.5)
                : BorderSide.none,
          );
          return Material(
            color: guideFocusSurfaceColor(
              active: active,
              tvFocused: _tvFocused,
              idleAlpha: 0.12,
              hoverAlpha: 0.22,
            ),
            shape: shape,
            child: liveTap(
              context: context,
              onTap: widget.onTap,
              borderRadius: size / 2,
              focusNode: widget.focusNode,
              tvRowId: widget.tvRowId,
              tvItemIndex: widget.tvItemIndex,
              onUpEdge: widget.onUpEdge,
              onDownEdge: widget.onDownEdge,
              onLeftEdge: widget.onLeftEdge,
              onRightEdge: widget.onRightEdge,
              onFocusChange: (focused) => setState(() => _focused = focused),
              onHoverChange: _setHovered,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(widget.icon, color: fg, size: widget.big ? 32 : 22),
              ),
            ),
          );
        },
      );
    }
    final child = SizedBox(
      width: size,
      height: size,
      child: Icon(widget.icon, color: Colors.white, size: widget.big ? 32 : 22),
    );
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: child,
      ),
    );
  }
}
