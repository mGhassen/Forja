import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shared/engine/runtime/nav/vertical_filters.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Hold a nav tab [ShellTokens.navCompleteReloadHold] to remount hubs.
///
/// Click / short press never reloads. Loading cue starts at
/// [ShellTokens.navCompleteReloadHoldCue] while the press stays down.
class NavCompleteReloadHold {
  NavCompleteReloadHold({required this.onChanged});

  final VoidCallback onChanged;

  int? _pointer;
  bool _keyHeld = false;
  Timer? _cueTimer;
  Timer? _completeTimer;
  bool loading = false;
  bool _completed = false;

  bool get isHolding => _pointer != null || _keyHeld;

  /// True after the 4s hold fired and before [consumeCompleted].
  bool get didComplete => _completed;

  void pointerDown(PointerDownEvent event, {String? hideMenuTabId}) {
    // Primary button only — ignore right-click / stylus barrel.
    if (event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kPrimaryButton) == 0) {
      return;
    }
    if (_pointer != null || _keyHeld) return;
    _pointer = event.pointer;
    _beginHold(hideMenuTabId: hideMenuTabId);
  }

  void pointerUp(PointerEvent event) {
    if (_pointer != event.pointer) return;
    _pointer = null;
    _finishPointerOrKey();
  }

  void pointerCancel(PointerEvent event) {
    if (_pointer != event.pointer) return;
    _pointer = null;
    _completed = false;
    _finishPointerOrKey(forceClearCompleted: true);
  }

  /// Keyboard / TV OK hold — no pointer id.
  void activateDown({String? hideMenuTabId}) {
    if (_pointer != null || _keyHeld) return;
    _keyHeld = true;
    _beginHold(hideMenuTabId: hideMenuTabId);
  }

  void activateUp() {
    if (!_keyHeld) return;
    _keyHeld = false;
    _finishPointerOrKey();
  }

  /// True when the 4s hold already fired — skip tab select / tap.
  bool consumeCompleted() {
    if (!_completed) return false;
    _completed = false;
    return true;
  }

  void dispose() {
    _cueTimer?.cancel();
    _completeTimer?.cancel();
    _pointer = null;
    _keyHeld = false;
    _activeGen = null;
  }

  void _beginHold({String? hideMenuTabId}) {
    _completed = false;
    if (loading) {
      loading = false;
      onChanged();
    }
    _cueTimer?.cancel();
    _completeTimer?.cancel();
    final holdGen = Object();
    _activeGen = holdGen;
    _cueTimer = Timer(ShellTokens.navCompleteReloadHoldCue, () {
      if (!identical(_activeGen, holdGen) || !isHolding) return;
      loading = true;
      onChanged();
    });
    _completeTimer = Timer(ShellTokens.navCompleteReloadHold, () {
      if (!identical(_activeGen, holdGen) || !isHolding) return;
      _completed = true;
      loading = true;
      onChanged();
      if (hideMenuTabId != null) {
        VerticalFiltersRegistry.hideMenu(hideMenuTabId);
      }
      HapticFeedback.mediumImpact();
      ShellBus.requestCompleteNavbarReload();
    });
  }

  Object? _activeGen;

  void _finishPointerOrKey({bool forceClearCompleted = false}) {
    _activeGen = null;
    _cueTimer?.cancel();
    _cueTimer = null;
    _completeTimer?.cancel();
    _completeTimer = null;
    if (loading) {
      loading = false;
      onChanged();
    }
    if (forceClearCompleted) {
      _completed = false;
      return;
    }
    // After long-press, [onTap] may not run — drop the flag next microtask so
    // the following click still selects the tab. Same-gesture [onTap] runs
    // synchronously before that microtask and can still [consumeCompleted].
    if (_completed) {
      scheduleMicrotask(() {
        _completed = false;
      });
    }
  }
}

/// Dims [icon] and paints a spinner inside the glyph bounds while holding.
class NavReloadHoldIcon extends StatelessWidget {
  const NavReloadHoldIcon({
    super.key,
    required this.icon,
    required this.loading,
    required this.size,
  });

  final Widget icon;
  final bool loading;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!loading) return icon;
    final spinner = (size * ShellTokens.navCompleteReloadHoldSpinnerScale)
        .clamp(
          ShellTokens.navCompleteReloadHoldSpinnerMin,
          size,
        );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: ShellTokens.navCompleteReloadHoldIconDim,
            child: icon,
          ),
          SizedBox(
            width: spinner,
            height: spinner,
            child: CircularProgressIndicator(
              strokeWidth: ShellTokens.navCompleteReloadHoldSpinnerStroke,
              color: ForjaShellColors.brandGreen,
            ),
          ),
        ],
      ),
    );
  }
}
