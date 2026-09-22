import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:flutter/services.dart';
import 'package:forja_foundation/widgets/feedback/loading_dots.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:google_fonts/google_fonts.dart';

/// Flat shell chip fill + border - matches sources panel / home filter style.
BoxDecoration shellChipDecoration({
  required bool selected,
  bool accentHover = false,
  double radius = ShellTokens.shellChipRadiusPill,
}) {
  final Color fill;
  final Color border;
  if (accentHover) {
    // Solid brand border — matches IPTV / Live Sports D-pad chips.
    fill = ForjaShellColors.brandGreen.withValues(alpha: 0.14);
    border = ForjaShellColors.brandGreen;
  } else if (selected) {
    fill = ForjaShellColors.chipSelectedBg;
    border = ForjaShellColors.chipSelectedBorder;
  } else {
    fill = Colors.white.withValues(alpha: 0.07);
    border = ForjaShellColors.cinematic.borderSubtle;
  }
  return BoxDecoration(
    color: fill,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: border,
      width: accentHover ? 1.5 : 1,
    ),
  );
}

/// Clipped Material + InkWell - hover/splash follow [radius] (pills, list rows).
Widget shellRoundedInkHost({
  required Widget child,
  required double radius,
  VoidCallback? onTap,
  Color? backgroundColor,
  BoxDecoration? decoration,
  EdgeInsetsGeometry? padding,
  bool suppressInkHover = false,
}) {
  final hoverColor =
      suppressInkHover ? Colors.transparent : ForjaShellColors.inkHover;
  final splashColor =
      suppressInkHover ? Colors.transparent : ForjaShellColors.inkSplash;
  final highlightColor =
      suppressInkHover ? Colors.transparent : null;
  final focusColor = suppressInkHover ? Colors.transparent : null;
  final borderRadius = BorderRadius.circular(radius);
  Widget body = child;
  if (padding != null) {
    body = Padding(padding: padding, child: body);
  }

  if (onTap == null && decoration == null && backgroundColor == null) {
    return body;
  }

  if (onTap == null) {
    return Material(
      color: backgroundColor ?? Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: radius > 0 ? Clip.antiAlias : Clip.none,
      child: decoration != null
          ? Ink(decoration: decoration, child: body)
          : body,
    );
  }

  final clip = radius > 0 ? Clip.antiAlias : Clip.none;

  return Material(
    color: backgroundColor ?? Colors.transparent,
    borderRadius: borderRadius,
    clipBehavior: clip,
    child: decoration != null
        ? Ink(
            decoration: decoration,
            child: InkWell(
              borderRadius: borderRadius,
              onTap: onTap,
              hoverColor: hoverColor,
              splashColor: splashColor,
              highlightColor: highlightColor,
              focusColor: focusColor,
              child: body,
            ),
          )
        : InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            hoverColor: hoverColor,
            splashColor: splashColor,
            highlightColor: highlightColor,
            focusColor: focusColor,
            child: body,
          ),
  );
}

/// Rounded hover/focus overlay for [MenuItemButton] and compact list rows.
ButtonStyle shellMenuItemStyle({
  double radius = ShellTokens.shellChipRadius,
  EdgeInsetsGeometry padding =
      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
}) {
  return ButtonStyle(
    padding: WidgetStatePropertyAll(padding),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    ),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused) ||
          states.contains(WidgetState.pressed)) {
        return ForjaShellColors.inkHover;
      }
      return null;
    }),
  );
}

/// Selectable pill chip for filters, moods, modes - no theme purple borders.
class ForjaShellChip extends StatefulWidget {
  const ForjaShellChip({
    super.key,
    required this.label,
    this.selected = false,
    this.icon,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.longPressDuration = const Duration(seconds: 2),
    this.radius = ShellTokens.shellChipRadiusPill,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    this.fontSize = ShellTokens.shellChipFontSize,
    this.iconSize = ShellTokens.shellChipIconSize,
    this.focusNode,
    this.listIndex,
    this.onDownEdge,
    this.onUpEdge,
    this.onLeftEdge,
    this.onRightEdge,
    this.accentHover = false,
    this.loading = false,
    this.onCancel,
    this.onReload,
    this.ensureVisibleMode = ShellPaintEnsureVisible.row,
  });

  final String label;
  final bool selected;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Hold pointer / OK for [longPressDuration] (Sources provider reload).
  final VoidCallback? onLongPress;
  final Duration longPressDuration;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final double iconSize;
  final FocusNode? focusNode;
  final int? listIndex;
  final VoidCallback? onDownEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  /// Desktop hover: tinted brand-green chrome instead of solid white ink.
  final bool accentHover;

  /// Same cycling `...` as Sources kind tabs while this chip is checking.
  final bool loading;

  /// Hover loading → ✕; tap cancels this chip's fetch (kind-tab parity).
  final VoidCallback? onCancel;

  /// Idle selected chip: refresh icon re-runs this chip only.
  final VoidCallback? onReload;

  /// Settings / vertical menus: [ShellPaintEnsureVisible.item] keeps long pages
  /// scrolled so bottom chips stay on screen.
  final ShellPaintEnsureVisible ensureVisibleMode;

  @override
  State<ForjaShellChip> createState() => _ForjaShellChipState();
}

class _ForjaShellChipState extends State<ForjaShellChip> {
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  final ValueNotifier<bool> _busyHoveredN = ValueNotifier(false);
  final ValueNotifier<bool> _reloadHoveredN = ValueNotifier(false);
  bool _focused = false;
  Timer? _holdTimer;
  bool _longPressFired = false;
  LogicalKeyboardKey? _holdActivateKey;

  @override
  void dispose() {
    _holdTimer?.cancel();
    _hoveredN.dispose();
    _busyHoveredN.dispose();
    _reloadHoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    if (_hoveredN.value == hovered) return;
    _hoveredN.value = hovered;
    if (!hovered) {
      _busyHoveredN.value = false;
      _reloadHoveredN.value = false;
    }
  }

  void _setBusyHovered(bool v) {
    if (_busyHoveredN.value == v) return;
    _busyHoveredN.value = v;
  }

  void _setReloadHovered(bool v) {
    if (_reloadHoveredN.value == v) return;
    _reloadHoveredN.value = v;
  }

  void _startHold() {
    if (widget.onLongPress == null) return;
    _holdTimer?.cancel();
    _longPressFired = false;
    _holdTimer = Timer(widget.longPressDuration, () {
      if (!mounted) return;
      _longPressFired = true;
      widget.onLongPress!();
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdActivateKey = null;
  }

  void _onTap() {
    if (_longPressFired) {
      _longPressFired = false;
      return;
    }
    widget.onTap?.call();
  }

  KeyEventResult _onTvKey(FocusNode node, KeyEvent event) {
    if (widget.onLongPress == null) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isActivate = key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA;
    if (!isActivate) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      _holdActivateKey = event.logicalKey;
      _startHold();
      // Swallow activate — short press fires on KeyUp so hold can win.
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent && _holdActivateKey == event.logicalKey) {
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent && _holdActivateKey == event.logicalKey) {
      final fired = _longPressFired;
      _cancelHold();
      if (!fired) _onTap();
      _longPressFired = false;
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildFace(bool hovered, bool busyHovered, bool reloadHovered) {
    final selected = widget.selected;
    final tv = ShellPaintScope.useTvFocusOf(context);
    final scaleOnHover = ShellPaintScope.scaleOnHoverOf(context);
    final focusStyled =
        ShellPaintScope.focusStyledOf(context, focused: _focused);
    final accent = widget.accentHover && (hovered || focusStyled);
    final showReload = widget.onReload != null &&
        (!scaleOnHover || hovered || focusStyled);
    final cinematic = ForjaShellColors.cinematic;
    final fg = accent
        ? ForjaShellColors.brandGreen
        : selected
            ? cinematic.textPrimary
            : cinematic.textSecondary;
    final reloadColor = (reloadHovered || focusStyled)
        ? ForjaShellColors.brandGreen
        : fg;
    final tvDensity = ShellPaintScope.usesTvDensityOf(context);
    final labelFontSize = tvDensity &&
            widget.fontSize == ShellTokens.shellChipFontSize
        ? ShellTokens.shellChipFontSizeTv
        : widget.fontSize;
    final iconSize = tvDensity &&
            widget.iconSize == ShellTokens.shellChipIconSize
        ? ShellTokens.shellChipIconSizeTv
        : widget.iconSize;
    final padding = tvDensity &&
            widget.padding ==
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
        ? const EdgeInsets.symmetric(
            horizontal: ShellTokens.shellChipPadHTv,
            vertical: ShellTokens.shellChipPadVTv,
          )
        : widget.padding;
    final gap = tvDensity
        ? ShellTokens.shellChipGapTv
        : ShellTokens.shellChipGap;
    final gapTight = tvDensity
        ? ShellTokens.shellChipGapTightTv
        : ShellTokens.shellChipGapTight;
    final radius = tvDensity &&
            widget.radius == ShellTokens.shellChipRadiusPill
        ? ShellTokens.shellChipRadiusPillTv
        : widget.radius;

    // Cap trailing glyphs to the label size so reload / loading … never grow
    // the pill above idle height (especially on leanback type ladder).
    final trailingSize =
        iconSize > labelFontSize ? labelFontSize : iconSize;

    return AnimatedContainer(
      duration: tv
          ? Duration.zero
          : ForjaMotionTheme.of(context).fillOnly.duration,
      curve: Curves.easeOut,
      decoration: shellChipDecoration(
        selected: selected,
        accentHover: accent,
        radius: radius,
      ),
      padding: padding,
      // Fixed face height keeps idle / loading / reload the same pill size.
      // Even leading + no tight TextHeightBehavior so the label sits centered
      // in the face (tight ascent/descent was parking glyphs high in the chip).
      child: SizedBox(
        height: labelFontSize,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: trailingSize, color: fg),
              SizedBox(width: gap),
            ],
            Text(
              widget.label,
              style: GoogleFonts.plusJakartaSans(
                color: fg,
                fontSize: labelFontSize,
                height: 1.0,
                fontWeight:
                    selected || accent ? FontWeight.w600 : FontWeight.w500,
              ).copyWith(
                leadingDistribution: TextLeadingDistribution.even,
              ),
              strutStyle: StrutStyle(
                fontSize: labelFontSize,
                height: 1.0,
                forceStrutHeight: true,
                leadingDistribution: TextLeadingDistribution.even,
              ),
            ),
            if (widget.loading) ...[
              SizedBox(width: gapTight),
              ForjaBusyCancelGlyph(
                color: fg,
                size: trailingSize,
                hovered: busyHovered,
                onHover: _setBusyHovered,
                onCancel: widget.onCancel,
              ),
            ] else if (showReload) ...[
              SizedBox(width: gap),
              ExcludeFocus(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => _setReloadHovered(true),
                  onExit: (_) => _setReloadHovered(false),
                  child: GestureDetector(
                    onTap: widget.onReload,
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedRotation(
                      turns: reloadHovered ? 0.5 : 0,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.refresh_rounded,
                        size: trailingSize,
                        color: reloadColor,
                      ),
                    ),
                  ),
                ),
              ),
            ] else if (widget.trailing != null) ...[
              SizedBox(width: gapTight),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useTv = ShellPaintScope.useTvFocusOf(context);
    final scaleOnHover = ShellPaintScope.scaleOnHoverOf(context);
    final tv = useTv;
    final borderRadius = BorderRadius.circular(widget.radius);
    final trackHover = widget.accentHover ||
        widget.onReload != null ||
        widget.onLongPress != null;
    final leanback = tv && !scaleOnHover;

    final face = ListenableBuilder(
      listenable: Listenable.merge([
        _hoveredN,
        _busyHoveredN,
        _reloadHoveredN,
      ]),
      builder: (context, _) => _buildFace(
        _hoveredN.value,
        _busyHoveredN.value,
        _reloadHoveredN.value,
      ),
    );

    Widget body;
    if (tv) {
      body = ShellPaintScope.focusableTap(
        context: context,
        onTap: leanback && widget.onLongPress != null ? null : _onTap,
        focusNode: widget.focusNode,
        borderRadius: widget.radius,
        motion: ForjaMotionPreset.fillOnly,
        showFocusBorder: false,
        showFocusFill: false,
        listIndex: widget.listIndex,
        tvItemIndex: widget.listIndex,
        tvZone: ShellPaintTvZone.chipStrip,
        onDownEdge: widget.onDownEdge,
        onUpEdge: widget.onUpEdge,
        onLeftEdge: widget.onLeftEdge,
        onRightEdge: widget.onRightEdge,
        ensureVisibleMode: widget.ensureVisibleMode,
        onKeyEvent: leanback && widget.onLongPress != null ? _onTvKey : null,
        onFocusChange: widget.accentHover ||
                widget.onReload != null ||
                widget.onLongPress != null
            ? (focused) {
                setState(() => _focused = focused);
                if (!focused) _cancelHold();
              }
            : null,
        onHoverChange: trackHover ? _setHovered : null,
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: face,
        ),
      );
    } else {
      body = shellRoundedInkHost(
        radius: widget.radius,
        onTap: _onTap,
        suppressInkHover: widget.accentHover,
        child: face,
      );
    }

    if (widget.onLongPress != null) {
      body = Listener(
        onPointerDown: (_) => _startHold(),
        onPointerUp: (_) {
          final fired = _longPressFired;
          _cancelHold();
          if (fired) _longPressFired = true;
        },
        onPointerCancel: (_) => _cancelHold(),
        child: body,
      );
    }

    if (!trackHover || tv) return body;
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: body,
    );
  }
}
