import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/shell_input_policy.dart';
import 'package:forja/shared/design/src/shell_scope.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:google_fonts/google_fonts.dart';

typedef ForjaInteractiveBuilder = Widget Function(bool hover, bool pressed);

class ForjaInteractive extends StatefulWidget {
  const ForjaInteractive({
    super.key,
    required this.builder,
    this.onTap,
    this.hoverScale = 1.06,
    this.pressScale = 0.94,
    this.scaleAlignment = Alignment.center,
    this.autoFocus = false,
    this.focusNode,
    this.onKeyEvent,
    this.tvMeta,
  });

  final ForjaInteractiveBuilder builder;
  final VoidCallback? onTap;
  final double hoverScale;
  final double pressScale;
  final Alignment scaleAlignment;
  final bool autoFocus;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  final ShellTvFocusMeta? tvMeta;

  @override
  State<ForjaInteractive> createState() => _ForjaInteractiveState();
}

class _ForjaInteractiveState extends State<ForjaInteractive> {
  bool _hover = false;
  bool _pressed = false;
  bool _focused = false;
  FocusNode? _ownedNode;

  FocusNode? _nodeFor(ForjaInteractive w) => w.focusNode ?? _ownedNode;

  FocusNode get _effectiveNode {
    final node = _nodeFor(widget);
    assert(
      node != null,
      'ForjaInteractive with onTap or focusNode must have a FocusNode',
    );
    return node!;
  }

  /// TV / keyboard: an explicit [focusNode] stays focusable even when [onTap]
  /// is null (e.g. Play disabled until episodes load).
  bool get _wantsFocus =>
      widget.onTap != null || widget.focusNode != null;

  ShellInputPolicy _policy(BuildContext context) =>
      ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;

  void _disposeOwnedNode() {
    final node = _ownedNode;
    if (node == null) return;
    _ownedNode = null;
    // Unfocus + defer dispose: FocusManager notifies in a microtask; sync
    // dispose while dirty → "FocusNode was used after being disposed".
    if (node.hasFocus) {
      node.unfocus();
      scheduleMicrotask(node.dispose);
    } else {
      node.dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    // Own a node only when focusable: external node, or onTap without one.
    if (widget.focusNode == null && widget.onTap != null) {
      _ownedNode = FocusNode(debugLabel: 'forja-interactive');
    }
    _registerTvItemNode();
  }

  void _ensureOwnedNodeForOnTap() {
    if (widget.focusNode != null) return;
    if (widget.onTap != null) {
      _ownedNode ??= FocusNode(debugLabel: 'forja-interactive');
    } else {
      _disposeOwnedNode();
    }
  }

  @override
  void didUpdateWidget(covariant ForjaInteractive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode &&
        oldWidget.onTap != widget.onTap) {
      _ensureOwnedNodeForOnTap();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      _unregisterTvItemNode(
        oldWidget.tvMeta,
        node: _nodeFor(oldWidget),
      );
      if (widget.focusNode == null) {
        // onTap:null + focusNode:null → no Focus widget (inactive hero slides).
        if (widget.onTap != null) {
          _ownedNode ??= FocusNode(debugLabel: 'forja-interactive');
        } else {
          _disposeOwnedNode();
        }
      } else {
        _disposeOwnedNode();
      }
      _registerTvItemNode();
    } else if (oldWidget.tvMeta?.rowId != widget.tvMeta?.rowId ||
        oldWidget.tvMeta?.itemIndex != widget.tvMeta?.itemIndex) {
      _unregisterTvItemNode(oldWidget.tvMeta, node: _nodeFor(oldWidget));
      _ensureOwnedNodeForOnTap();
      _registerTvItemNode();
    }
  }

  void _registerTvItemNode() {
    final meta = widget.tvMeta;
    if (meta == null) return;
    if (meta.zone != ShellTvZone.row && meta.zone != ShellTvZone.chipStrip) {
      return;
    }
    if (meta.rowId == null || meta.itemIndex == null) return;
    ShellTvFocusCoordinator.registerItemNode(
      tabId: meta.tabId,
      rowId: meta.rowId!,
      index: meta.itemIndex!,
      node: _effectiveNode,
    );
  }

  void _unregisterTvItemNode(ShellTvFocusMeta? meta, {FocusNode? node}) {
    if (meta == null) return;
    if (meta.zone != ShellTvZone.row && meta.zone != ShellTvZone.chipStrip) {
      return;
    }
    if (meta.rowId == null || meta.itemIndex == null) return;
    final effectiveNode = node ?? _nodeFor(widget);
    if (effectiveNode == null) return;
    ShellTvFocusCoordinator.unregisterItemNode(
      tabId: meta.tabId,
      rowId: meta.rowId!,
      index: meta.itemIndex!,
      node: effectiveNode,
    );
  }

  @override
  void dispose() {
    _unregisterTvItemNode(widget.tvMeta, node: _nodeFor(widget));
    _disposeOwnedNode();
    super.dispose();
  }

  double _scaleFor(BuildContext context, ShellInputPolicy policy) {
    if (_pressed) return widget.pressScale;
    if (ShellInputPolicy.interactiveActive(
      policy,
      hovered: _hover,
      focused: _focused,
      context: context,
    )) {
      return widget.hoverScale;
    }
    return 1.0;
  }

  bool _activeFor(BuildContext context, ShellInputPolicy policy) =>
      ShellInputPolicy.interactiveActive(
        policy,
        hovered: _hover,
        focused: _focused,
        context: context,
      );

  @override
  Widget build(BuildContext context) {
    final policy = _policy(context);
    final body = AnimatedScale(
      scale: _scaleFor(context, policy),
      alignment: widget.scaleAlignment,
      duration: policy.instantFocusChrome
          ? Duration.zero
          : const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: widget.builder(_activeFor(context, policy), _pressed),
    );

    Widget interactive = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      cursor: SystemMouseCursors.click,
      child: widget.onTap != null
          ? GestureDetector(
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: body,
            )
          : Listener(
              onPointerDown: (_) => setState(() => _pressed = true),
              onPointerUp: (_) => setState(() => _pressed = false),
              onPointerCancel: (_) => setState(() => _pressed = false),
              behavior: HitTestBehavior.translucent,
              child: body,
            ),
    );

    if (!_wantsFocus) return interactive;

    return Focus(
      focusNode: _effectiveNode,
      debugLabel: _effectiveNode.debugLabel ?? 'forja-interactive',
      autofocus: widget.autoFocus,
      onFocusChange: (focused) {
        setState(() => _focused = focused);
        if (focused) {
          widget.tvMeta?.notifyFocused(_effectiveNode);
        }
      },
      onKeyEvent: (node, event) {
        final custom = widget.onKeyEvent?.call(node, event);
        if (custom == KeyEventResult.handled) return KeyEventResult.handled;
        final arrow = shellTvHandleRowArrows(event: event, tvMeta: widget.tvMeta);
        if (arrow == KeyEventResult.handled) return arrow;
        // Opt-in linear only; default TV D-pad is spatial focusInDirection.
        final linearScope = ShellTvLinearFocusScope.activeOf(context) &&
            !ShellTvDisableLinearFocus.activeOf(context);
        if (linearScope) {
          final linear = shellTvLinearMenuArrows(context: context, event: event);
          if (linear == KeyEventResult.handled) return linear;
          if (shellTvIsNavigationKey(event)) {
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.arrowUp ||
                key == LogicalKeyboardKey.arrowDown ||
                key == LogicalKeyboardKey.arrowLeft ||
                key == LogicalKeyboardKey.arrowRight) {
              return KeyEventResult.handled;
            }
          }
        }
        // Same as FocusableControl: zone-only tvMeta (settings/overlays) must
        // still get spatial focusInDirection after row edges ignore the arrow.
        if (policy.useFocusableMoodChips && shellTvIsNavigationKey(event)) {
          final key = event.logicalKey;
          TraversalDirection? direction;
          if (key == LogicalKeyboardKey.arrowLeft) {
            direction = TraversalDirection.left;
          } else if (key == LogicalKeyboardKey.arrowRight) {
            direction = TraversalDirection.right;
          } else if (key == LogicalKeyboardKey.arrowUp) {
            direction = TraversalDirection.up;
          } else if (key == LogicalKeyboardKey.arrowDown) {
            direction = TraversalDirection.down;
          }
          if (direction != null && _effectiveNode.focusInDirection(direction)) {
            return KeyEventResult.handled;
          }
        }
        final trap = shellTvTrapRowGeometry(
          event: event,
          tvFocus: policy.useFocusableMoodChips,
          tvMeta: widget.tvMeta,
          trapHorizontal:
              policy.useFocusableMoodChips && widget.tvMeta?.rowId != null,
        );
        if (trap == KeyEventResult.handled) return trap;
        if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
        if (shellTvIsActivateKey(event)) {
          final tap = widget.onTap;
          if (tap == null) return KeyEventResult.handled;
          tap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: interactive,
    );
  }
}

/// Text-only CTA - no border, no filled background.
class ForjaGhostButton extends StatelessWidget {
  const ForjaGhostButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.autoFocus = false,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool autoFocus;
  final FocusNode? focusNode;

  Color get _color => ForjaShellColors.textPrimary;

  @override
  Widget build(BuildContext context) {
    return ForjaInteractive(
      onTap: onTap,
      autoFocus: autoFocus,
      focusNode: focusNode,
      hoverScale: 1.04,
      pressScale: 0.96,
      builder: (hover, pressed) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: _color),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: _color,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bare icon action - soft circular fill on hover/press/focus, no border.
class ForjaPlainIcon extends StatefulWidget {
  const ForjaPlainIcon({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.color,
    this.size = 24,
    this.hitSize,
    this.hoverScale = 1.08,
    this.pressScale = 0.94,
    this.child,
    this.focusNode,
    this.onKeyEvent,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? color;
  final double size;
  final double? hitSize;
  final double hoverScale;
  final double pressScale;
  final Widget? child;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  @override
  State<ForjaPlainIcon> createState() => _ForjaPlainIconState();
}

class _ForjaPlainIconState extends State<ForjaPlainIcon> {
  bool _hover = false;
  bool _pressed = false;
  bool _focused = false;

  double get _resolvedHitSize => widget.hitSize ?? widget.size + 12;

  ShellInputPolicy _policy(BuildContext context) =>
      ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;

  bool _activeFor(BuildContext context, ShellInputPolicy policy) =>
      ShellInputPolicy.interactiveActive(
        policy,
        hovered: _hover,
        focused: _focused,
        context: context,
      );

  Color _resolveIconColor(BuildContext context, ShellInputPolicy policy) {
    if (widget.color != null) {
      return _activeFor(context, policy)
          ? ForjaShellColors.iconHover
          : widget.color!;
    }
    return _activeFor(context, policy)
        ? ForjaShellColors.iconHover
        : ForjaShellColors.iconMuted;
  }

  Color _resolveFillColor() {
    final fillAlpha = _pressed ? 0.14 : 0.10;
    return Colors.white.withValues(alpha: fillAlpha);
  }

  double _scaleFor(BuildContext context, ShellInputPolicy policy) {
    if (_pressed) return widget.pressScale;
    if (_activeFor(context, policy)) return widget.hoverScale;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final policy = _policy(context);
    final showFill = _activeFor(context, policy) || _pressed;

    Widget button = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: widget.onTap != null
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: widget.onTap != null
            ? (_) => setState(() => _pressed = false)
            : null,
        onTapCancel:
            widget.onTap != null ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _scaleFor(context, policy),
          duration: policy.instantFocusChrome
              ? Duration.zero
              : const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: _resolvedHitSize,
            height: _resolvedHitSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: showFill ? _resolveFillColor() : Colors.transparent,
              ),
              child: Center(
                child: widget.child ??
                    Icon(
                      widget.icon,
                      size: widget.size,
                      color: _resolveIconColor(context, policy),
                    ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.onTap != null) {
      button = Focus(
        focusNode: widget.focusNode,
        debugLabel: widget.focusNode?.debugLabel ?? 'forja-plain-icon',
        onFocusChange: (focused) => setState(() => _focused = focused),
        onKeyEvent: (node, event) {
          final custom = widget.onKeyEvent?.call(node, event);
          if (custom == KeyEventResult.handled) return KeyEventResult.handled;
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select) {
            widget.onTap!();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: button,
      );
    }

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}

/// Top-bar action icon that matches the shell menu tabs (Films / TV Shows …):
/// idles at [ForjaShellColors.textSecondary] and animates to white on
/// hover/focus with **no** background fill - same color language as the tabs.
class ForjaTopBarIcon extends StatefulWidget {
  const ForjaTopBarIcon({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 24,
    this.hitSize,
    this.focusNode,
    this.onFocusChange,
    this.manageFocus = true,
    this.highlighted,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double? hitSize;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;

  /// When false, skip owning a [Focus] (parent already focuses, e.g. TV tap).
  final bool manageFocus;

  /// External highlight (TV focus from parent). Combined with hover/focus.
  final bool? highlighted;

  @override
  State<ForjaTopBarIcon> createState() => _ForjaTopBarIconState();
}

class _ForjaTopBarIconState extends State<ForjaTopBarIcon> {
  static const _animDuration = Duration(milliseconds: 280);
  static const _animCurve = Curves.easeInOutCubic;

  bool _hover = false;
  bool _focused = false;

  double get _resolvedHitSize => widget.hitSize ?? widget.size + 12;

  @override
  Widget build(BuildContext context) {
    final active = _hover || _focused || (widget.highlighted == true);
    final idle = ForjaShellColors.cinematic.textSecondary;

    Widget button = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: _resolvedHitSize,
          height: _resolvedHitSize,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: active ? 1 : 0),
              duration: _animDuration,
              curve: _animCurve,
              builder: (context, t, _) {
                return Icon(
                  widget.icon,
                  size: widget.size,
                  color: Color.lerp(idle, Colors.white, t),
                );
              },
            ),
          ),
        ),
      ),
    );

    if (widget.onTap != null && widget.manageFocus) {
      button = Focus(
        focusNode: widget.focusNode,
        debugLabel: widget.focusNode?.debugLabel ?? 'forja-top-bar-icon',
        onFocusChange: (focused) {
          setState(() => _focused = focused);
          widget.onFocusChange?.call(focused);
        },
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select) {
            widget.onTap!();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: button,
      );
    }

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}

/// Borderless dismiss control - soft circular fill on hover, no outline.
class ForjaCloseButton extends StatelessWidget {
  const ForjaCloseButton({
    super.key,
    this.onTap,
    this.tooltip = 'Close',
    this.color,
    this.size = 20,
    this.hitSize = 36,
    this.compact = false,
    this.focusNode,
    this.onKeyEvent,
  });

  const ForjaCloseButton.compact({
    super.key,
    this.onTap,
    this.tooltip = 'Close',
    this.color,
    this.size = 18,
    this.hitSize = 32,
    this.focusNode,
    this.onKeyEvent,
  }) : compact = true;

  final VoidCallback? onTap;
  final String? tooltip;
  final Color? color;
  final double size;
  final double hitSize;
  final bool compact;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  @override
  Widget build(BuildContext context) {
    return ForjaPlainIcon(
      icon: Icons.close_rounded,
      tooltip: tooltip,
      color: color,
      size: size,
      hitSize: hitSize,
      onTap: onTap,
      focusNode: focusNode,
      onKeyEvent: onKeyEvent,
    );
  }
}

/// Bordered square icon - use sparingly; prefer [ForjaPlainIcon] in hero chrome.
class ForjaIconButton extends StatelessWidget {
  const ForjaIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = ShellTokens.shellButtonHeight,
    this.tooltip,
    this.child,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    const borderColor = ForjaShellColors.ghostBorder;
    const iconColor = ForjaShellColors.textPrimary;

    final button = ForjaInteractive(
      onTap: onTap,
      hoverScale: 1.08,
      pressScale: 0.95,
      builder: (hover, pressed) {
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ShellTokens.shellButtonRadius),
            border: Border.all(
              color: hover ? iconColor.withValues(alpha: 0.5) : borderColor,
            ),
          ),
          child: child ?? Icon(icon, size: 20, color: iconColor),
        );
      },
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
