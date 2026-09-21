import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/focus/shell_hover_focus.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';

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
    this.suppressActive = false,
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

  /// Force idle chrome (open menus, overlays) — ignores hover/focus paint.
  final bool suppressActive;

  @override
  State<ForjaInteractive> createState() => _ForjaInteractiveState();
}

class _ForjaInteractiveState extends State<ForjaInteractive> {
  final ValueNotifier<bool> _hoverN = ValueNotifier(false);
  final ValueNotifier<bool> _pressedN = ValueNotifier(false);
  static _ForjaInteractiveState? _hoverOwner;
  late final void Function() _hoverClaim = _requestHoverFocus;
  bool _focused = false;
  FocusNode? _ownedNode;

  void _requestHoverFocus() {
    if (!mounted || !_wantsFocus) return;
    final node = _effectiveNode;
    if (node.hasFocus || !node.canRequestFocus) return;
    node.requestFocus();
  }

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
  bool get _wantsFocus => widget.onTap != null || widget.focusNode != null;

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
    if (widget.suppressActive && !oldWidget.suppressActive) {
      _hoverN.value = false;
      _pressedN.value = false;
      _focused = false;
      final node = _nodeFor(widget);
      if (node != null && node.hasFocus) {
        node.unfocus();
      }
    }
    if (oldWidget.focusNode == widget.focusNode &&
        oldWidget.onTap != widget.onTap) {
      _unregisterTvItemNode(oldWidget.tvMeta, node: _nodeFor(oldWidget));
      _ensureOwnedNodeForOnTap();
      _registerTvItemNode();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      _unregisterTvItemNode(
        oldWidget.tvMeta,
        node: _nodeFor(oldWidget),
      );
      if (widget.focusNode == null) {
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
    final node = _nodeFor(widget);
    if (node == null) return;
    ShellTvFocusCoordinator.registerItemNode(
      tabId: meta.tabId,
      rowId: meta.rowId!,
      index: meta.itemIndex!,
      node: node,
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
    if (_hoverOwner == this) _hoverOwner = null;
    ShellHoverFocus.release(_hoverClaim);
    _unregisterTvItemNode(widget.tvMeta, node: _nodeFor(widget));
    _disposeOwnedNode();
    _hoverN.dispose();
    _pressedN.dispose();
    super.dispose();
  }

  void _setHover(bool hovered) {
    if (widget.suppressActive && hovered) return;
    if (hovered) {
      final prev = _hoverOwner;
      if (prev != null && prev != this && prev.mounted) {
        prev._hoverN.value = false;
        prev._pressedN.value = false;
      }
      _hoverOwner = this;
      ShellHoverFocus.claim(_hoverClaim);
      if (_hoverN.value) return;
      _hoverN.value = true;
      return;
    }
    if (_hoverOwner == this) _hoverOwner = null;
    ShellHoverFocus.release(_hoverClaim);
    if (!_hoverN.value && !_pressedN.value) return;
    _hoverN.value = false;
    _pressedN.value = false;
  }

  double _scaleFor(
    BuildContext context,
    ShellInputPolicy policy, {
    required bool hover,
    required bool pressed,
  }) {
    if (widget.suppressActive) return 1.0;
    if (pressed) return widget.pressScale;
    if (ShellInputPolicy.interactiveActive(
      policy,
      hovered: hover,
      focused: _focused,
      context: context,
    )) {
      return widget.hoverScale;
    }
    return 1.0;
  }

  bool _activeFor(
    BuildContext context,
    ShellInputPolicy policy, {
    required bool hover,
  }) {
    if (widget.suppressActive) return false;
    return ShellInputPolicy.interactiveActive(
      policy,
      hovered: hover,
      focused: _focused,
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_wantsFocus) _ensureOwnedNodeForOnTap();
    final policy = _policy(context);
    final body = ListenableBuilder(
      listenable: Listenable.merge([_hoverN, _pressedN]),
      builder: (context, _) {
        final hover = _hoverN.value;
        final pressed = _pressedN.value;
        return AnimatedScale(
          scale: _scaleFor(context, policy, hover: hover, pressed: pressed),
          alignment: widget.scaleAlignment,
          duration: policy.instantFocusChrome
              ? Duration.zero
              : const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: widget.builder(_activeFor(context, policy, hover: hover), pressed),
        );
      },
    );

    Widget interactive = MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      cursor: SystemMouseCursors.click,
      child: widget.onTap != null
          ? GestureDetector(
              onTapDown: (_) {
                if (widget.suppressActive) return;
                _pressedN.value = true;
              },
              onTapUp: (_) => _pressedN.value = false,
              onTapCancel: () => _pressedN.value = false,
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: body,
            )
          : Listener(
              onPointerDown: (_) {
                if (widget.suppressActive) return;
                _pressedN.value = true;
              },
              onPointerUp: (_) => _pressedN.value = false,
              onPointerCancel: (_) => _pressedN.value = false,
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
        if (widget.suppressActive) {
          if (focused) {
            _effectiveNode.unfocus();
          }
          if (_focused || _hoverN.value || _pressedN.value) {
            setState(() {
              _focused = false;
              _hoverN.value = false;
              _pressedN.value = false;
            });
          }
          return;
        }
        setState(() => _focused = focused);
        if (focused) {
          widget.tvMeta?.notifyFocused(_effectiveNode);
        }
      },
      onKeyEvent: (node, event) {
        final custom = widget.onKeyEvent?.call(node, event);
        if (custom == KeyEventResult.handled) return KeyEventResult.handled;
        final arrow = shellTvHandleRowArrows(
          event: event,
          tvMeta: widget.tvMeta,
          containDpad: ShellTvContainDpad.activeOf(context),
        );
        if (arrow == KeyEventResult.handled) return arrow;
        final pageBack =
            shellTvSettingsBackwardEdge(context: context, event: event);
        if (pageBack == KeyEventResult.handled) return pageBack;
        final linearScope = ShellTvLinearFocusScope.activeOf(context) &&
            !ShellTvDisableLinearFocus.activeOf(context);
        if (linearScope) {
          final linear =
              shellTvLinearMenuArrows(context: context, event: event);
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
