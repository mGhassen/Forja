import 'dart:async';
import 'dart:math' as math;

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

/// Dims [icon] and fills it bottom-up with a waving liquid while holding.
class NavReloadHoldIcon extends StatefulWidget {
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
  State<NavReloadHoldIcon> createState() => _NavReloadHoldIconState();
}

class _NavReloadHoldIconState extends State<NavReloadHoldIcon>
    with TickerProviderStateMixin {
  late final AnimationController _fill;
  late final AnimationController _wave;

  static Duration get _fillDuration =>
      ShellTokens.navCompleteReloadHold - ShellTokens.navCompleteReloadHoldCue;

  @override
  void initState() {
    super.initState();
    _fill = AnimationController(vsync: this, duration: _fillDuration);
    _wave = AnimationController(
      vsync: this,
      duration: ShellTokens.navCompleteReloadHoldWavePeriod,
    );
    if (widget.loading) {
      _fill.forward(from: 0);
      _wave.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant NavReloadHoldIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading && !oldWidget.loading) {
      _fill.duration = _fillDuration;
      _fill.forward(from: 0);
      _wave.repeat();
    } else if (!widget.loading && oldWidget.loading) {
      _fill.stop();
      _fill.value = 0;
      _wave.stop();
      _wave.value = 0;
    }
  }

  @override
  void dispose() {
    _fill.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.loading) return widget.icon;
    return AnimatedBuilder(
      animation: Listenable.merge([_fill, _wave]),
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: ShellTokens.navCompleteReloadHoldIconDim,
                child: widget.icon,
              ),
              ClipPath(
                clipper: _NavReloadWaveClipper(
                  fill: _fill.value,
                  phase: _wave.value,
                  amplitude: ShellTokens.navCompleteReloadHoldWaveAmplitude,
                  cycles: ShellTokens.navCompleteReloadHoldWaveCycles,
                ),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    ForjaShellColors.brandGreen,
                    BlendMode.srcIn,
                  ),
                  child: widget.icon,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Clips from the bottom with a sine crest so the fill reads as water rising.
class _NavReloadWaveClipper extends CustomClipper<Path> {
  const _NavReloadWaveClipper({
    required this.fill,
    required this.phase,
    required this.amplitude,
    required this.cycles,
  });

  final double fill;
  final double phase;
  final double amplitude;
  final double cycles;

  @override
  Path getClip(Size size) {
    final path = Path();
    if (fill <= 0) return path;
    if (fill >= 1) {
      return Path()..addRect(Offset.zero & size);
    }
    final amp = size.height * amplitude;
    // Keep the crest inside the icon as fill approaches full.
    final level = size.height * (1 - fill);
    final crest = level.clamp(amp, size.height - amp);
    path.moveTo(0, size.height);
    path.lineTo(0, crest);
    const steps = 24;
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final x = size.width * t;
      final y = crest +
          math.sin((t * cycles + phase) * math.pi * 2) * amp;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _NavReloadWaveClipper oldClipper) {
    return oldClipper.fill != fill ||
        oldClipper.phase != phase ||
        oldClipper.amplitude != amplitude ||
        oldClipper.cycles != cycles;
  }
}
