import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/casting/casting.dart';
import 'package:forja/shared/player/controls/chrome/player_status_roulette.dart';
import 'package:forja/shared/player/controls/menus/player_popup_panel.dart';
import 'package:forja/shared/player/controls/chrome/player_seek_scrub_cancel.dart';
import 'package:forja_foundation/widgets/details/meta_line.dart';
import 'package:forja_foundation/widgets/details/hero_overview_text.dart';
import 'package:forja_foundation/widgets/details/hero_title.dart';
import 'package:forja/shell/desktop/desktop_selectable_title.dart';
import 'package:forja_foundation/widgets/details/watch_progress_bar.dart';
import 'package:forja/shared/player/entry/player_metadata.dart';
import 'package:rust/rust.dart';

import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shell/desktop/desktop_window_chrome.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
part 'player_chrome_overlay_hero.dart';

/// Scale a desktop chrome length when leanback density is on.
double playerChromeScale(BuildContext context, double desktop) =>
    ShellTokens.chromeScale(
      desktop,
      tv: ShellPaintScope.usesTvDensityOf(context),
    );

/// Desktop type → leanback ladder (never × [playerChromeScale]).
double playerChromeTypeSize(BuildContext context, double desktop) =>
    ShellPaintScope.usesTvDensityOf(context)
        ? ShellTokens.tvTypeSize(desktop)
        : desktop;

/// D-pad / hover highlight for player chrome - works even without [ShellScope].
/// Desktop: mouse → hover only; keyboard/D-pad → focus chrome.
bool playerChromeFocusActive(
  BuildContext context, {
  required bool tvFocusable,
  required bool hovered,
  required bool focused,
}) {
  final policy =
      ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
  if (!tvFocusable) {
    return policy.scaleOnHover && hovered;
  }
  return ShellInputPolicy.interactiveActive(
    policy,
    hovered: hovered,
    focused: focused,
    context: context,
  );
}

bool playerChromeTvFocused(
  BuildContext context, {
  required bool tvFocusable,
  required bool focused,
}) {
  if (!tvFocusable || !focused) return false;
  final policy =
      ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
  return policy.focusChromeVisible(context, focused: focused);
}

Color playerChromeIconColor({
  required bool enabled,
  required bool active,
  required bool highlight,
  required bool tvFocused,
}) {
  if (!enabled) return Colors.white.withValues(alpha: 0.4);
  if (active) return Colors.white;
  if (tvFocused) return ForjaShellColors.brandGreen;
  if (highlight) return Colors.white;
  return Colors.white.withValues(alpha: 0.54);
}

Color playerChromeBackgroundColor({
  required bool active,
  required bool highlight,
  required bool tvFocused,
}) {
  if (active) return Colors.white.withValues(alpha: 0.18);
  if (tvFocused) return ForjaShellColors.brandGreen.withValues(alpha: 0.14);
  if (highlight) return Colors.white.withValues(alpha: 0.14);
  return Colors.transparent;
}

ShapeBorder playerChromeButtonShape({
  required bool isCircle,
  required bool tvFocused,
  double borderRadius = 8,
}) {
  final side = tvFocused
      ? const BorderSide(color: ForjaShellColors.brandGreen, width: 1.5)
      : BorderSide.none;
  if (isCircle) return CircleBorder(side: side);
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(borderRadius),
    side: side,
  );
}

class PlayerFlatIconButton extends StatefulWidget {
  const PlayerFlatIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.onPressedWithContext,
    this.label,
    this.tooltip,
    this.active = false,
    this.size = 40,
    this.iconSize = 22,
    this.tvFocusable = false,
    this.focusNode,
    this.onLeftEdge,
    this.onRightEdge,
    this.onUpEdge,
    this.onDownEdge,
  }) : assert(onPressed != null || onPressedWithContext != null);

  final IconData icon;
  final VoidCallback? onPressed;
  final ValueChanged<BuildContext>? onPressedWithContext;
  final String? label;
  final String? tooltip;
  final bool active;
  final double size;
  final double iconSize;
  final bool tvFocusable;
  final FocusNode? focusNode;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;

  @override
  State<PlayerFlatIconButton> createState() => _PlayerFlatIconButtonState();
}

class _PlayerFlatIconButtonState extends State<PlayerFlatIconButton> {
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

  bool _highlightFor(bool hovered) => playerChromeFocusActive(
    context,
    tvFocusable: widget.tvFocusable,
    hovered: hovered,
    focused: _focused,
  );

  bool get _tvFocused =>
      playerChromeTvFocused(
        context,
        tvFocusable: widget.tvFocusable,
        focused: _focused,
      );

  Widget _buildChild(bool hovered) {
    final highlight = _highlightFor(hovered);
    final iconColor = playerChromeIconColor(
      enabled: true,
      active: widget.active,
      highlight: highlight,
      tvFocused: _tvFocused,
    );
    final size = playerChromeScale(context, widget.size);
    final iconSize = playerChromeScale(context, widget.iconSize);
    final labelFs = playerChromeTypeSize(context, 12);
    final padH = playerChromeScale(context, 8);
    final maxW = playerChromeScale(context, 148);
    final labelMaxW = playerChromeScale(context, 110);
    final radius = widget.label == null ? size / 2 : playerChromeScale(context, 8);
    final shape = playerChromeButtonShape(
      isCircle: widget.label == null,
      tvFocused: _tvFocused,
      borderRadius: radius,
    );
    final onTap = widget.onPressedWithContext != null
        ? () => widget.onPressedWithContext!(context)
        : widget.onPressed;
    return Material(
      color: playerChromeBackgroundColor(
        active: widget.active,
        highlight: highlight,
        tvFocused: _tvFocused,
      ),
      shape: shape,
      child: InkWell(
        // FocusableControl owns TV focus - InkWell must not take D-pad stops.
        canRequestFocus: false,
        onTap: widget.tvFocusable ? null : onTap,
        hoverColor: Colors.transparent,
        splashColor: Colors.white.withValues(alpha: 0.08),
        customBorder: shape,
        child: SizedBox(
          width: widget.label == null ? size : null,
          height: size,
          child: widget.label == null
              ? Icon(widget.icon, color: iconColor, size: iconSize)
              : ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: padH),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.icon,
                          color: iconColor,
                          size: iconSize - 2,
                        ),
                        SizedBox(width: playerChromeScale(context, 5)),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: labelMaxW),
                          child: Text(
                            widget.label!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: iconColor,
                              fontSize: labelFs,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onPressedWithContext != null
        ? () => widget.onPressedWithContext!(context)
        : widget.onPressed;
    final size = playerChromeScale(context, widget.size);
    final borderRadius = widget.label == null
        ? size / 2
        : playerChromeScale(context, 8);
    final painted = ListenableBuilder(
      listenable: _hoveredN,
      builder: (context, _) => _buildChild(_hoveredN.value),
    );
    final button = widget.tvFocusable
        ? FocusableControl(
            focusNode: widget.focusNode,
            onTap: onTap,
            borderRadius: borderRadius,
            scaleOnFocus: 1.0,
            onLeftEdge: widget.onLeftEdge,
            onRightEdge: widget.onRightEdge,
            onUpEdge: widget.onUpEdge,
            onDownEdge: widget.onDownEdge,
            onFocusChange: (focused) => setState(() => _focused = focused),
            onHoverChange: (hovered) {
              if (hovered) playerChromeCancelSeekScrubs();
              _setHovered(hovered);
            },
            child: painted,
          )
        : MouseRegion(
            onEnter: (_) {
              // Drop seek-bar scrub capture before Quality / Settings hover -
              // otherwise the thumb stays magnetized to the pointer over chrome.
              playerChromeCancelSeekScrubs();
              _setHovered(true);
            },
            onExit: (_) => _setHovered(false),
            cursor: SystemMouseCursors.click,
            child: painted,
          );
    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}

/// Unified stream source control - flat, matches other player icon buttons.
class PlayerStreamPickerButton extends StatefulWidget {
  const PlayerStreamPickerButton({
    super.key,
    required this.label,
    this.server,
    required this.onPressedWithContext,
    this.enabled = true,
    this.size = 40,
    this.iconSize = 20,
    this.tvFocusable = false,
    this.focusNode,
    this.onLeftEdge,
    this.onRightEdge,
    this.onUpEdge,
    this.onDownEdge,
  });

  final String label;
  /// Active mirror / server under [label] (e.g. Videasy → Yoru).
  final String? server;
  final ValueChanged<BuildContext>? onPressedWithContext;
  final bool enabled;
  final double size;
  final double iconSize;
  final bool tvFocusable;
  final FocusNode? focusNode;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;

  @override
  State<PlayerStreamPickerButton> createState() =>
      _PlayerStreamPickerButtonState();
}

class _PlayerStreamPickerButtonState extends State<PlayerStreamPickerButton> {
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

  bool _highlightFor(bool hovered) => playerChromeFocusActive(
    context,
    tvFocusable: widget.tvFocusable,
    hovered: hovered,
    focused: _focused,
  );

  bool get _tvFocused =>
      playerChromeTvFocused(
        context,
        tvFocusable: widget.tvFocusable,
        focused: _focused,
      );

  Widget _buildChild(bool hovered) {
    final highlight = _highlightFor(hovered);
    final fgAlpha = widget.enabled
        ? (_tvFocused
              ? 1.0
              : highlight
              ? 0.95
              : 0.88)
        : 0.4;
    final iconColor = _tvFocused
        ? ForjaShellColors.brandGreen
        : Colors.white.withValues(alpha: widget.enabled ? 0.92 : 0.4);
    final shape = playerChromeButtonShape(
      isCircle: false,
      tvFocused: _tvFocused,
      borderRadius: playerChromeScale(context, 8),
    );
    final onTap = widget.enabled && widget.onPressedWithContext != null
        ? () => widget.onPressedWithContext!(context)
        : null;
    final size = playerChromeScale(context, widget.size);
    final iconSize = playerChromeScale(context, widget.iconSize);
    final radius = playerChromeScale(context, 8);
    final padH = playerChromeScale(context, 6);
    final maxW = playerChromeScale(context, 148);
    return Material(
      color: playerChromeBackgroundColor(
        active: false,
        highlight: highlight,
        tvFocused: _tvFocused,
      ),
      shape: shape,
      child: InkWell(
        canRequestFocus: false,
        onTap: widget.tvFocusable ? null : onTap,
        customBorder: shape,
        borderRadius: BorderRadius.circular(radius),
        hoverColor: Colors.transparent,
        splashColor: Colors.white.withValues(alpha: 0.08),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: size, maxWidth: maxW),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padH),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.layers_outlined,
                  color: iconColor,
                  size: iconSize,
                ),
                SizedBox(width: playerChromeScale(context, 5)),
                _PlayerSourceButtonText(
                  label: widget.label,
                  server: widget.server,
                  color: _tvFocused
                      ? ForjaShellColors.brandGreen
                      : Colors.white.withValues(alpha: fgAlpha),
                  tvFocused: _tvFocused,
                  maxWidth: playerChromeScale(context, 88),
                ),
                Icon(
                  Icons.expand_more_rounded,
                  size: ShellPaintScope.iconOf(context, 16),
                  color: _tvFocused
                      ? ForjaShellColors.brandGreen
                      : Colors.white.withValues(
                          alpha: widget.enabled ? 0.45 : 0.25,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.enabled && widget.onPressedWithContext != null
        ? () => widget.onPressedWithContext!(context)
        : null;
    final painted = ListenableBuilder(
      listenable: _hoveredN,
      builder: (context, _) => _buildChild(_hoveredN.value),
    );
    final button = widget.tvFocusable
        ? FocusableControl(
            focusNode: widget.focusNode,
            onTap: onTap,
            borderRadius: playerChromeScale(context, 8),
            scaleOnFocus: 1.0,
            onLeftEdge: widget.onLeftEdge,
            onRightEdge: widget.onRightEdge,
            onUpEdge: widget.onUpEdge,
            onDownEdge: widget.onDownEdge,
            onFocusChange: (focused) => setState(() => _focused = focused),
            onHoverChange: (hovered) {
              if (hovered) playerChromeCancelSeekScrubs();
              _setHovered(hovered);
            },
            child: painted,
          )
        : MouseRegion(
            onEnter: (_) {
              playerChromeCancelSeekScrubs();
              _setHovered(true);
            },
            onExit: (_) => _setHovered(false),
            cursor: widget.enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: painted,
          );
    final server = widget.server?.trim();
    final tip = server != null && server.isNotEmpty
        ? 'Source: ${widget.label} · $server'
        : 'Source: ${widget.label}';
    return Tooltip(message: tip, child: button);
  }
}

/// Catalog Sources panel opener — link icon + active source name (no chevron).
class PlayerSourcesPanelButton extends StatefulWidget {
  const PlayerSourcesPanelButton({
    super.key,
    required this.label,
    this.server,
    this.offline = false,
    this.onPressed,
    this.onPressedWithContext,
    this.size = 40,
    this.iconSize = 20,
    this.tvFocusable = false,
    this.focusNode,
    this.onLeftEdge,
    this.onRightEdge,
    this.onUpEdge,
    this.onDownEdge,
  }) : assert(onPressed != null || onPressedWithContext != null);

  final String label;
  /// Active mirror / server under [label] (e.g. Videasy → Yoru).
  final String? server;
  /// Saved file on this device is what is playing.
  final bool offline;
  final VoidCallback? onPressed;
  final ValueChanged<BuildContext>? onPressedWithContext;
  final double size;
  final double iconSize;
  final bool tvFocusable;
  final FocusNode? focusNode;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;

  @override
  State<PlayerSourcesPanelButton> createState() =>
      _PlayerSourcesPanelButtonState();
}

class _PlayerSourcesPanelButtonState extends State<PlayerSourcesPanelButton> {
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

  bool _highlightFor(bool hovered) => playerChromeFocusActive(
    context,
    tvFocusable: widget.tvFocusable,
    hovered: hovered,
    focused: _focused,
  );

  bool get _tvFocused =>
      playerChromeTvFocused(
        context,
        tvFocusable: widget.tvFocusable,
        focused: _focused,
      );

  Widget _buildChild(bool hovered) {
    final highlight = _highlightFor(hovered);
    final fg = playerChromeIconColor(
      enabled: true,
      active: false,
      highlight: highlight,
      tvFocused: _tvFocused,
    );
    final shape = playerChromeButtonShape(
      isCircle: false,
      tvFocused: _tvFocused,
      borderRadius: playerChromeScale(context, 8),
    );
    final onTap = widget.onPressedWithContext != null
        ? () => widget.onPressedWithContext!(context)
        : widget.onPressed;
    final size = playerChromeScale(context, widget.size);
    final iconSize = playerChromeScale(context, widget.iconSize);
    final radius = playerChromeScale(context, 8);
    final padH = playerChromeScale(context, 8);
    final maxW = playerChromeScale(context, 148);
    return Material(
      color: playerChromeBackgroundColor(
        active: false,
        highlight: highlight,
        tvFocused: _tvFocused,
      ),
      shape: shape,
      child: InkWell(
        canRequestFocus: false,
        onTap: widget.tvFocusable ? null : onTap,
        customBorder: shape,
        borderRadius: BorderRadius.circular(radius),
        hoverColor: Colors.transparent,
        splashColor: Colors.white.withValues(alpha: 0.08),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: size, maxWidth: maxW),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padH),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Offline icon when the saved file is playing. Otherwise a
                // link icon only when provider-only — two-line provider/server
                // chrome is self-explanatory without it.
                if (widget.offline ||
                    widget.server?.trim().isNotEmpty != true) ...[
                  Icon(
                    widget.offline
                        ? Icons.download_done_rounded
                        : Icons.link_rounded,
                    color: fg,
                    size: iconSize,
                  ),
                  SizedBox(width: playerChromeScale(context, 5)),
                ],
                _PlayerSourceButtonText(
                  label: widget.label,
                  server: widget.server,
                  color: fg,
                  tvFocused: _tvFocused,
                  maxWidth: playerChromeScale(context, 100),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onPressedWithContext != null
        ? () => widget.onPressedWithContext!(context)
        : widget.onPressed;
    final painted = ListenableBuilder(
      listenable: _hoveredN,
      builder: (context, _) => _buildChild(_hoveredN.value),
    );
    final button = widget.tvFocusable
        ? FocusableControl(
            focusNode: widget.focusNode,
            onTap: onTap,
            borderRadius: playerChromeScale(context, 8),
            scaleOnFocus: 1.0,
            onLeftEdge: widget.onLeftEdge,
            onRightEdge: widget.onRightEdge,
            onUpEdge: widget.onUpEdge,
            onDownEdge: widget.onDownEdge,
            onFocusChange: (focused) => setState(() => _focused = focused),
            onHoverChange: (hovered) {
              if (hovered) playerChromeCancelSeekScrubs();
              _setHovered(hovered);
            },
            child: painted,
          )
        : MouseRegion(
            onEnter: (_) {
              playerChromeCancelSeekScrubs();
              _setHovered(true);
            },
            onExit: (_) => _setHovered(false),
            cursor: SystemMouseCursors.click,
            child: painted,
          );
    final server = widget.server?.trim();
    final base = server != null && server.isNotEmpty
        ? 'Sources: ${widget.label} · $server'
        : 'Sources: ${widget.label}';
    final tip = widget.offline ? '$base · Offline' : base;
    return Tooltip(message: tip, child: button);
  }
}

/// Provider on top, optional server underneath (Videasy / Yoru).
class _PlayerSourceButtonText extends StatelessWidget {
  const _PlayerSourceButtonText({
    required this.label,
    required this.color,
    required this.tvFocused,
    required this.maxWidth,
    this.server,
  });

  final String label;
  final String? server;
  final Color color;
  final bool tvFocused;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final serverLine = server?.trim();
    final hasServer = serverLine != null && serverLine.isNotEmpty;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: playerChromeTypeSize(
                context,
                hasServer ? 11.0 : 12.0,
              ),
              height: 1.1,
              fontWeight: tvFocused ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          if (hasServer)
            Text(
              serverLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color.withValues(alpha: 0.72),
                fontSize: playerChromeTypeSize(context, 10),
                height: 1.1,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

/// Floating skip / next-episode chip - flat shell chrome (mouse + TV D-pad).
class PlayerFloatingChip extends StatefulWidget {
  const PlayerFloatingChip({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.trailingIcon = Icons.skip_next_rounded,
    this.focusNode,
    this.tvFocusable = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData trailingIcon;
  final FocusNode? focusNode;
  final bool tvFocusable;

  @override
  State<PlayerFloatingChip> createState() => _PlayerFloatingChipState();
}

class _PlayerFloatingChipState extends State<PlayerFloatingChip> {
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

  bool get _tvFocused =>
      playerChromeTvFocused(
        context,
        tvFocusable: widget.tvFocusable,
        focused: _focused,
      );

  bool _highlightFor(bool hovered) => playerChromeFocusActive(
    context,
    tvFocusable: widget.tvFocusable,
    hovered: hovered,
    focused: _focused,
  );

  Widget _buildBody(bool hovered) {
    final highlight = _highlightFor(hovered);
    final borderColor = _tvFocused
        ? ForjaShellColors.brandGreen
        : ForjaShellColors.borderSubtle;
    final fill = _tvFocused
        ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: highlight ? 0.22 : 0.15);
    final fg = _tvFocused ? ForjaShellColors.brandGreen : Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: _tvFocused ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.loading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            else
              Text(
                widget.label,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (!widget.loading) ...[
              const SizedBox(width: 6),
              Icon(
                widget.trailingIcon,
                color: fg,
                size: ShellPaintScope.iconOf(context, 18),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final painted = ListenableBuilder(
      listenable: _hoveredN,
      builder: (context, _) => _buildBody(_hoveredN.value),
    );

    if (widget.tvFocusable) {
      return FocusableControl(
        focusNode: widget.focusNode,
        onTap: widget.onPressed,
        borderRadius: 8,
        scaleOnFocus: 1.0,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: painted,
      );
    }

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(8),
          hoverColor: ForjaShellColors.inkHover,
          splashColor: ForjaShellColors.inkSplash,
          child: painted,
        ),
      ),
    );
  }
}

class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({
    super.key,
    required this.title,
    this.season,
    this.episode,
    this.episodeLine,
    this.statusMessage,
    this.statusActions,
    required this.onBack,
    this.trailing,
    this.tvFocusable = false,
    this.backFocusNode,
    this.backOnRightEdge,
    this.backOnDownEdge,
  });

  final String title;
  final int? season;
  final int? episode;
  final String? episodeLine;
  final String? statusMessage;
  final Widget? statusActions;
  final VoidCallback onBack;
  final Widget? trailing;
  final bool tvFocusable;
  final FocusNode? backFocusNode;
  /// TV: D-pad → from Back (e.g. to Retry when stream failure actions show).
  final VoidCallback? backOnRightEdge;
  /// TV: D-pad ↓ from Back (seek bar or transport — geometry often fails).
  final VoidCallback? backOnDownEdge;

  String? get _episodeLine {
    if (episodeLine != null && episodeLine!.isNotEmpty) return episodeLine;
    if (episode == null) return null;
    if (season == null) return 'Episode $episode';
    return 'S$season E$episode';
  }

  static double topPadding(BuildContext context) {
    if (DesktopWindowChrome.isDesktop) {
      return DesktopWindowChrome.topInset(context) + 6;
    }
    return MediaQuery.paddingOf(context).top + 6;
  }

  static double totalHeight(
    BuildContext context, {
    bool hasStatusMessage = false,
    bool hasStatusActions = false,
  }) {
    final topBtn =
        playerChromeScale(context, ShellTokens.playerChromeTopBtnSize);
    var height = topPadding(context) + topBtn + playerChromeScale(context, 6);
    if (hasStatusMessage) height += playerChromeScale(context, 20);
    if (hasStatusActions) height += playerChromeScale(context, 30);
    return height;
  }

  bool get _hasStatusMessage =>
      statusMessage != null && statusMessage!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tv = ShellPaintScope.usesTvDensityOf(context);
        final titleInset = constraints.maxWidth >= 600
            ? (tv ? 96.0 : 152.0)
            : (tv ? 64.0 : 96.0);
        // Desktop baseline — [PlayerFlatIconButton] densifies via playerChromeScale.
        const topBtnDesktop = ShellTokens.playerChromeTopBtnSize;
        final topBtn = playerChromeScale(context, topBtnDesktop);
        final titleFs = tv
            ? ShellTokens.playerChromeTitleFontSizeTv
            : ShellTokens.playerChromeTitleFontSize;
        final metaFs = tv
            ? ShellTokens.playerChromeMetaFontSizeTv
            : ShellTokens.playerChromeMetaFontSize;
        final padH = playerChromeScale(context, 16);
        final padBottom = playerChromeScale(context, 6);
        // opaque:false — default MouseRegion eats the mac title-inset zone and
        // blocks [DragToMoveArea] / overlay drag strip underneath.
        return DesktopWindowChrome.wrapDragMove(
          MouseRegion(
          opaque: false,
          onEnter: (_) => playerChromeCancelSeekScrubs(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              padH,
              topPadding(context),
              padH,
              padBottom,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: topBtn),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: titleInset),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleFs,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_episodeLine != null) ...[
                            SizedBox(height: playerChromeScale(context, 2)),
                            Text(
                              _episodeLine!,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: ForjaShellColors.cinematic.textSecondary,
                                fontSize: metaFs,
                              ),
                            ),
                          ],
                          if (_hasStatusMessage) ...[
                            SizedBox(height: playerChromeScale(context, 6)),
                            Text(
                              statusMessage!,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: metaFs,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (statusActions != null) ...[
                            SizedBox(height: playerChromeScale(context, 8)),
                            statusActions!,
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      child: PlayerFlatIconButton(
                        icon: Icons.arrow_back_rounded,
                        onPressed: onBack,
                        size: topBtnDesktop,
                        iconSize: ShellTokens.playerChromeRoundIconSize,
                        tvFocusable: tvFocusable,
                        focusNode: backFocusNode,
                        onRightEdge: backOnRightEdge,
                        onDownEdge: backOnDownEdge,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: trailing ??
                          SizedBox(width: topBtn, height: topBtn),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        );
      },
    );
  }
}

class PlayerTopStatusActions extends StatelessWidget {
  const PlayerTopStatusActions({
    super.key,
    required this.onRetry,
    this.onStream,
    this.streamEnabled = true,
    this.tvFocusable = false,
    this.retryFocusNode,
    this.streamFocusNode,
    this.onRetryLeftEdge,
    this.onRetryRightEdge,
    this.onStreamLeftEdge,
    this.onStreamRightEdge,
  });

  final VoidCallback onRetry;
  final VoidCallback? onStream;
  final bool streamEnabled;
  final bool tvFocusable;
  final FocusNode? retryFocusNode;
  final FocusNode? streamFocusNode;
  final VoidCallback? onRetryLeftEdge;
  final VoidCallback? onRetryRightEdge;
  final VoidCallback? onStreamLeftEdge;
  final VoidCallback? onStreamRightEdge;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        _link(
          'Retry',
          onRetry,
          focusNode: retryFocusNode,
          onLeftEdge: onRetryLeftEdge,
          onRightEdge: onRetryRightEdge,
        ),
        if (onStream != null)
          _link(
            'Stream',
            streamEnabled ? onStream! : () {},
            focusNode: streamFocusNode,
            onLeftEdge: onStreamLeftEdge,
            onRightEdge: onStreamRightEdge,
          ),
      ],
    );
  }

  Widget _link(
    String label,
    VoidCallback onTap, {
    FocusNode? focusNode,
    VoidCallback? onLeftEdge,
    VoidCallback? onRightEdge,
  }) {
    return Builder(
      builder: (context) {
        final padH = playerChromeScale(context, 8);
        final padV = playerChromeScale(context, 2);
        final fs = playerChromeTypeSize(context, 12);
        final radius = playerChromeScale(context, 8);
        final button = TextButton(
          onPressed: tvFocusable ? null : onTap,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.75),
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: TextStyle(fontSize: fs, fontWeight: FontWeight.w600),
          ),
          child: Text(label),
        );
        if (!tvFocusable) return button;
        return shellFocusableTap(
          context: context,
          onTap: onTap,
          borderRadius: radius,
          showFocusBorder: true,
          focusNode: focusNode,
          onLeftEdge: onLeftEdge,
          onRightEdge: onRightEdge,
          child: button,
        );
      },
    );
  }
}

class PlayerTopBarActions extends StatelessWidget {
  const PlayerTopBarActions({
    super.key,
    this.onCast,
    this.showCast = false,
    this.onPip,
    this.showPip = false,
    this.pipActive = false,
    this.onInAppMini,
    this.showInAppMini = false,
    this.onPlayer,
    this.showPlayer = false,
    this.tvFocusable = false,
    this.playerFocusNode,
    this.playerOnLeftEdge,
    this.playerOnDownEdge,
  });

  final VoidCallback? onCast;
  final bool showCast;
  final VoidCallback? onPip;
  final bool showPip;
  final bool pipActive;
  final VoidCallback? onInAppMini;
  final bool showInAppMini;
  final ValueChanged<BuildContext>? onPlayer;
  final bool showPlayer;
  final bool tvFocusable;
  final FocusNode? playerFocusNode;
  final VoidCallback? playerOnLeftEdge;
  /// TV: D-pad ↓ from Player (seek / transport — spatial fails across title gap).
  final VoidCallback? playerOnDownEdge;

  @override
  Widget build(BuildContext context) {
    // Desktop baselines — [PlayerFlatIconButton] densifies for leanback.
    const size = ShellTokens.playerChromeTopBtnSize;
    const iconSize = ShellTokens.playerChromeRoundIconSize;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showPlayer && onPlayer != null)
          PlayerFlatIconButton(
            icon: Icons.smart_display_outlined,
            tooltip: 'Player',
            onPressedWithContext: onPlayer!,
            size: size,
            iconSize: iconSize,
            tvFocusable: tvFocusable,
            focusNode: playerFocusNode,
            onLeftEdge: playerOnLeftEdge,
            onDownEdge: playerOnDownEdge,
          ),
        if (showCast && onCast != null)
          PlayerFlatIconButton(
            icon: Icons.cast_rounded,
            tooltip: 'Cast',
            onPressed: onCast!,
            size: size,
            iconSize: iconSize,
            tvFocusable: tvFocusable,
          ),
        if (showInAppMini && onInAppMini != null)
          PlayerFlatIconButton(
            icon: Icons.branding_watermark_outlined,
            tooltip: 'In-app mini player',
            onPressed: onInAppMini!,
            size: size,
            iconSize: iconSize,
            tvFocusable: tvFocusable,
          ),
        if (showPip && onPip != null)
          PlayerFlatIconButton(
            icon: pipActive
                ? Icons.picture_in_picture_alt_rounded
                : Icons.picture_in_picture_rounded,
            tooltip: 'Picture in Picture',
            onPressed: onPip!,
            size: size,
            iconSize: iconSize,
            tvFocusable: tvFocusable,
          ),
      ],
    );
  }
}

void _showCastFeedback(
  BuildContext context, {
  PlayerStatusController? statusController,
  required String message,
  StatusRouletteKind kind = StatusRouletteKind.info,
}) {
  if (statusController != null) {
    statusController.upsert(
      'cast',
      message,
      kind: kind,
      dismissAfter: const Duration(seconds: 3),
    );
    return;
  }
  if (!context.mounted) return;
  final toastKind = switch (kind) {
    StatusRouletteKind.success => ForjaToastKind.success,
    StatusRouletteKind.failed => ForjaToastKind.error,
    StatusRouletteKind.loading => ForjaToastKind.info,
    StatusRouletteKind.info => ForjaToastKind.info,
  };
  ForjaToast.show(
    message,
    kind: toastKind,
    duration: const Duration(seconds: 3),
  );
}

String _castTargetLabel(CastTarget target) =>
    target == CastTarget.airplay ? 'AirPlay' : 'Chromecast';

Future<CastTarget?> _pickCastTarget(BuildContext context) async {
  final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
  if (!tv) {
    return showMenu<CastTarget>(
      context: context,
      position: const RelativeRect.fromLTRB(9999, 56, 16, 0),
      items: const [
        PopupMenuItem(value: CastTarget.airplay, child: Text('AirPlay')),
        PopupMenuItem(value: CastTarget.chromecast, child: Text('Chromecast')),
      ],
    );
  }

  CastTarget? picked;
  await PlayerPopupPanel.show(
    context: context,
    title: 'Cast to',
    leadingIcon: Icons.cast_rounded,
    centered: true,
    width: 280,
    maxHeight: 220,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerPopupListTile(
          label: 'AirPlay',
          onTap: () {
            picked = CastTarget.airplay;
            PlayerPopupPanel.dismiss();
          },
        ),
        PlayerPopupListTile(
          label: 'Chromecast',
          onTap: () {
            picked = CastTarget.chromecast;
            PlayerPopupPanel.dismiss();
          },
        ),
      ],
    ),
  );
  return picked;
}

Future<void> showPlayerCastPicker(
  BuildContext context, {
  required String? streamUrl,
  required String title,
  Map<String, String>? headers,
  PlayerStatusController? statusController,
}) async {
  final casting = CastingService.instance;
  final canCast = casting.isAirPlayAvailable || casting.isChromecastAvailable;
  if (!canCast) {
    _showCastFeedback(
      context,
      statusController: statusController,
      message: 'Casting is not supported on this device',
      kind: StatusRouletteKind.failed,
    );
    return;
  }

  if (streamUrl == null || streamUrl.isEmpty) {
    _showCastFeedback(
      context,
      statusController: statusController,
      message: 'No stream to cast',
      kind: StatusRouletteKind.failed,
    );
    return;
  }

  CastTarget? target;
  if (casting.isAirPlayAvailable && casting.isChromecastAvailable) {
    target = await _pickCastTarget(context);
    if (target == null || !context.mounted) return;
  } else if (casting.isAirPlayAvailable) {
    target = CastTarget.airplay;
  } else {
    target = CastTarget.chromecast;
  }

  final label = _castTargetLabel(target);
  _showCastFeedback(
    context,
    statusController: statusController,
    message: 'Starting $label…',
    kind: StatusRouletteKind.loading,
  );

  final started = await casting.castUrl(
    url: streamUrl,
    target: target,
    headers: headers,
    title: title,
  );

  if (!context.mounted) return;

  if (started) {
    _showCastFeedback(
      context,
      statusController: statusController,
      message: 'Casting to $label',
      kind: StatusRouletteKind.success,
    );
    return;
  }

  _showCastFeedback(
    context,
    statusController: statusController,
    message: '$label is not available yet',
    kind: StatusRouletteKind.failed,
  );
}

/// Inline volume control: mute button + horizontal slider in the player row (IPTV-style).
