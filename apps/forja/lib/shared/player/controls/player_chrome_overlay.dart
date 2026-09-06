import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/casting/casting.dart';
import 'package:forja/shared/player/controls/player_status_roulette.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_seek_scrub_cancel.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:forja/shared/widgets/hero/hero_meta_line.dart';
import 'package:forja/shared/widgets/hero_overview_text.dart';
import 'package:forja/shared/widgets/hero/hero_title.dart';
import 'package:forja/shared/widgets/watch_progress_bar.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

part 'player_chrome_overlay_hero.dart';

/// D-pad / hover highlight for player chrome - works even without [ShellScope].
bool playerChromeFocusActive(
  BuildContext context, {
  required bool tvFocusable,
  required bool hovered,
  required bool focused,
}) {
  if (tvFocusable && focused) return true;
  final policy =
      ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
  return ShellInputPolicy.interactiveActive(
    policy,
    hovered: hovered,
    focused: focused,
    context: context,
  );
}

bool playerChromeTvFocused({
  required bool tvFocusable,
  required bool focused,
}) => tvFocusable && focused;

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
  bool _hovered = false;
  bool _focused = false;

  bool get _highlight => playerChromeFocusActive(
    context,
    tvFocusable: widget.tvFocusable,
    hovered: _hovered,
    focused: _focused,
  );

  bool get _tvFocused =>
      playerChromeTvFocused(tvFocusable: widget.tvFocusable, focused: _focused);

  Color get _iconColor => playerChromeIconColor(
    enabled: true,
    active: widget.active,
    highlight: _highlight,
    tvFocused: _tvFocused,
  );

  Color get _labelColor => _iconColor;

  Color get _backgroundColor => playerChromeBackgroundColor(
    active: widget.active,
    highlight: _highlight,
    tvFocused: _tvFocused,
  );

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onPressedWithContext != null
        ? () => widget.onPressedWithContext!(context)
        : widget.onPressed;
    final borderRadius = widget.label == null ? widget.size / 2 : 8.0;
    final shape = playerChromeButtonShape(
      isCircle: widget.label == null,
      tvFocused: _tvFocused,
    );
    final child = Material(
      color: _backgroundColor,
      shape: shape,
      child: InkWell(
        // FocusableControl owns TV focus - InkWell must not take D-pad stops.
        canRequestFocus: false,
        onTap: widget.tvFocusable ? null : onTap,
        hoverColor: Colors.transparent,
        splashColor: Colors.white.withValues(alpha: 0.08),
        customBorder: shape,
        child: SizedBox(
          width: widget.label == null ? widget.size : null,
          height: widget.size,
          child: widget.label == null
              ? Icon(widget.icon, color: _iconColor, size: widget.iconSize)
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 148),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.icon,
                          color: _iconColor,
                          size: widget.iconSize - 2,
                        ),
                        const SizedBox(width: 5),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 110),
                          child: Text(
                            widget.label!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _labelColor,
                              fontSize: 12,
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
              setState(() => _hovered = hovered);
            },
            child: child,
          )
        : MouseRegion(
            onEnter: (_) {
              // Drop seek-bar scrub capture before Quality / Settings hover -
              // otherwise the thumb stays magnetized to the pointer over chrome.
              playerChromeCancelSeekScrubs();
              setState(() => _hovered = true);
            },
            onExit: (_) => setState(() {
              _hovered = false;
            }),
            cursor: SystemMouseCursors.click,
            child: child,
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
  bool _hovered = false;
  bool _focused = false;

  bool get _highlight => playerChromeFocusActive(
    context,
    tvFocusable: widget.tvFocusable,
    hovered: _hovered,
    focused: _focused,
  );

  bool get _tvFocused =>
      playerChromeTvFocused(tvFocusable: widget.tvFocusable, focused: _focused);

  @override
  Widget build(BuildContext context) {
    final onTap = widget.enabled && widget.onPressedWithContext != null
        ? () => widget.onPressedWithContext!(context)
        : null;
    final fgAlpha = widget.enabled
        ? (_tvFocused
              ? 1.0
              : _highlight
              ? 0.95
              : 0.88)
        : 0.4;
    final iconColor = _tvFocused
        ? ForjaShellColors.brandGreen
        : Colors.white.withValues(alpha: widget.enabled ? 0.92 : 0.4);
    final shape = playerChromeButtonShape(
      isCircle: false,
      tvFocused: _tvFocused,
    );
    final child = Material(
      color: playerChromeBackgroundColor(
        active: false,
        highlight: _highlight,
        tvFocused: _tvFocused,
      ),
      shape: shape,
      child: InkWell(
        canRequestFocus: false,
        onTap: widget.tvFocusable ? null : onTap,
        customBorder: shape,
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.transparent,
        splashColor: Colors.white.withValues(alpha: 0.08),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: widget.size, maxWidth: 148),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.layers_outlined,
                  color: iconColor,
                  size: widget.iconSize,
                ),
                const SizedBox(width: 5),
                _PlayerSourceButtonText(
                  label: widget.label,
                  server: widget.server,
                  color: _tvFocused
                      ? ForjaShellColors.brandGreen
                      : Colors.white.withValues(alpha: fgAlpha),
                  tvFocused: _tvFocused,
                  maxWidth: 88,
                ),
                Icon(
                  Icons.expand_more_rounded,
                  size: 16,
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
    final button = widget.tvFocusable
        ? FocusableControl(
            focusNode: widget.focusNode,
            onTap: onTap,
            borderRadius: 8,
            scaleOnFocus: 1.0,
            onLeftEdge: widget.onLeftEdge,
            onRightEdge: widget.onRightEdge,
            onUpEdge: widget.onUpEdge,
            onDownEdge: widget.onDownEdge,
            onFocusChange: (focused) => setState(() => _focused = focused),
            onHoverChange: (hovered) {
              if (hovered) playerChromeCancelSeekScrubs();
              setState(() => _hovered = hovered);
            },
            child: child,
          )
        : MouseRegion(
            onEnter: (_) {
              playerChromeCancelSeekScrubs();
              setState(() => _hovered = true);
            },
            onExit: (_) => setState(() => _hovered = false),
            cursor: widget.enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: child,
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
  bool _hovered = false;
  bool _focused = false;

  bool get _highlight => playerChromeFocusActive(
    context,
    tvFocusable: widget.tvFocusable,
    hovered: _hovered,
    focused: _focused,
  );

  bool get _tvFocused =>
      playerChromeTvFocused(tvFocusable: widget.tvFocusable, focused: _focused);

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onPressedWithContext != null
        ? () => widget.onPressedWithContext!(context)
        : widget.onPressed;
    final fg = playerChromeIconColor(
      enabled: true,
      active: false,
      highlight: _highlight,
      tvFocused: _tvFocused,
    );
    final shape = playerChromeButtonShape(
      isCircle: false,
      tvFocused: _tvFocused,
    );
    final child = Material(
      color: playerChromeBackgroundColor(
        active: false,
        highlight: _highlight,
        tvFocused: _tvFocused,
      ),
      shape: shape,
      child: InkWell(
        canRequestFocus: false,
        onTap: widget.tvFocusable ? null : onTap,
        customBorder: shape,
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.transparent,
        splashColor: Colors.white.withValues(alpha: 0.08),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: widget.size, maxWidth: 148),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Link icon only when provider-only — two-line provider/server
                // chrome is self-explanatory without it.
                if (widget.server?.trim().isNotEmpty != true) ...[
                  Icon(
                    Icons.link_rounded,
                    color: fg,
                    size: widget.iconSize,
                  ),
                  const SizedBox(width: 5),
                ],
                _PlayerSourceButtonText(
                  label: widget.label,
                  server: widget.server,
                  color: fg,
                  tvFocused: _tvFocused,
                  maxWidth: 100,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final button = widget.tvFocusable
        ? FocusableControl(
            focusNode: widget.focusNode,
            onTap: onTap,
            borderRadius: 8,
            scaleOnFocus: 1.0,
            onLeftEdge: widget.onLeftEdge,
            onRightEdge: widget.onRightEdge,
            onUpEdge: widget.onUpEdge,
            onDownEdge: widget.onDownEdge,
            onFocusChange: (focused) => setState(() => _focused = focused),
            onHoverChange: (hovered) {
              if (hovered) playerChromeCancelSeekScrubs();
              setState(() => _hovered = hovered);
            },
            child: child,
          )
        : MouseRegion(
            onEnter: (_) {
              playerChromeCancelSeekScrubs();
              setState(() => _hovered = true);
            },
            onExit: (_) => setState(() => _hovered = false),
            cursor: SystemMouseCursors.click,
            child: child,
          );
    final server = widget.server?.trim();
    final tip = server != null && server.isNotEmpty
        ? 'Sources: ${widget.label} · $server'
        : 'Sources: ${widget.label}';
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
              fontSize: hasServer ? 11 : 12,
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
                fontSize: 10,
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
  bool _focused = false;
  bool _hovered = false;

  bool get _tvFocused =>
      playerChromeTvFocused(tvFocusable: widget.tvFocusable, focused: _focused);

  bool get _highlight => playerChromeFocusActive(
    context,
    tvFocusable: widget.tvFocusable,
    hovered: _hovered,
    focused: _focused,
  );

  @override
  Widget build(BuildContext context) {
    final borderColor = _tvFocused
        ? ForjaShellColors.brandGreen
        : ForjaShellColors.borderSubtle;
    final fill = _tvFocused
        ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: _highlight ? 0.22 : 0.15);
    final fg = _tvFocused ? ForjaShellColors.brandGreen : Colors.white;

    final body = DecoratedBox(
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
              Icon(widget.trailingIcon, color: fg, size: 18),
            ],
          ],
        ),
      ),
    );

    if (widget.tvFocusable) {
      return FocusableControl(
        focusNode: widget.focusNode,
        onTap: widget.onPressed,
        borderRadius: 8,
        scaleOnFocus: 1.0,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: body,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(8),
          hoverColor: ForjaShellColors.inkHover,
          splashColor: ForjaShellColors.inkSplash,
          child: body,
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
    var height = topPadding(context) + 44 + 6;
    if (hasStatusMessage) height += 20;
    if (hasStatusActions) height += 30;
    return height;
  }

  bool get _hasStatusMessage =>
      statusMessage != null && statusMessage!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleInset = constraints.maxWidth >= 600 ? 152.0 : 96.0;
        return MouseRegion(
          onEnter: (_) => playerChromeCancelSeekScrubs(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, topPadding(context), 16, 6),
            child: SizedBox(
              width: double.infinity,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_episodeLine != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _episodeLine!,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: ForjaShellColors.cinematic.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (_hasStatusMessage) ...[
                            const SizedBox(height: 6),
                            Text(
                              statusMessage!,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (statusActions != null) ...[
                            const SizedBox(height: 8),
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
                        size: 44,
                        tvFocusable: tvFocusable,
                        focusNode: backFocusNode,
                        onRightEdge: backOnRightEdge,
                        onDownEdge: backOnDownEdge,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: trailing ?? const SizedBox(width: 44, height: 44),
                    ),
                  ],
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
    final button = TextButton(
      onPressed: tvFocusable ? null : onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white.withValues(alpha: 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
    if (!tvFocusable) return button;
    return Builder(
      builder: (context) => shellFocusableTap(
        context: context,
        onTap: onTap,
        borderRadius: 8,
        showFocusBorder: true,
        focusNode: focusNode,
        onLeftEdge: onLeftEdge,
        onRightEdge: onRightEdge,
        child: button,
      ),
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

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showPlayer && onPlayer != null)
          PlayerFlatIconButton(
            icon: Icons.smart_display_outlined,
            tooltip: 'Player',
            onPressedWithContext: onPlayer!,
            size: 44,
            tvFocusable: tvFocusable,
            focusNode: playerFocusNode,
            onLeftEdge: playerOnLeftEdge,
          ),
        if (showCast && onCast != null)
          PlayerFlatIconButton(
            icon: Icons.cast_rounded,
            tooltip: 'Cast',
            onPressed: onCast!,
            size: 44,
            tvFocusable: tvFocusable,
          ),
        if (showInAppMini && onInAppMini != null)
          PlayerFlatIconButton(
            icon: Icons.branding_watermark_outlined,
            tooltip: 'In-app mini player',
            onPressed: onInAppMini!,
            size: 44,
            tvFocusable: tvFocusable,
          ),
        if (showPip && onPip != null)
          PlayerFlatIconButton(
            icon: pipActive
                ? Icons.picture_in_picture_alt_rounded
                : Icons.picture_in_picture_rounded,
            tooltip: 'Picture in Picture',
            onPressed: onPip!,
            size: 44,
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
