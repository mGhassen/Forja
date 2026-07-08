import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/navigation/navigation_back_handler.dart';

/// Mouse back, Escape, macOS trackpad swipe-back, and interactive drag feedback
/// for screens without a visible back control.
class BackNavigationScope extends StatefulWidget {
  const BackNavigationScope({super.key, required this.child});

  final Widget child;

  @override
  State<BackNavigationScope> createState() => _BackNavigationScopeState();
}

class _BackNavigationScopeState extends State<BackNavigationScope> {
  double _dragOffset = 0;
  double _totalDx = 0;
  double _totalDy = 0;
  bool _tracking = false;

  static const double _popFraction = 0.28;
  static const double _minPopDx = 96;

  bool get _canPop => Navigator.canPop(context);

  @override
  void initState() {
    super.initState();
    NavigationBackHandler.push(_pop);
  }

  @override
  void dispose() {
    NavigationBackHandler.pop(_pop);
    super.dispose();
  }

  void _pop() {
    if (!_canPop || !mounted) return;
    Navigator.maybePop(context);
  }

  void _resetDrag() {
    if (!_tracking && _dragOffset == 0) return;
    setState(() {
      _tracking = false;
      _dragOffset = 0;
      _totalDx = 0;
      _totalDy = 0;
    });
  }

  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    if (!_canPop) return;
    setState(() {
      _tracking = true;
      _dragOffset = 0;
      _totalDx = 0;
      _totalDy = 0;
    });
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (!_tracking || !_canPop) return;

    final dx = event.panDelta.dx;
    final dy = event.panDelta.dy;
    _totalDx += dx;
    _totalDy += dy;

    // macOS back: two-finger swipe left (negative dx) moves the page right.
    if (_totalDx > -8 && dx >= 0 && _dragOffset <= 0) return;
    if (_totalDx.abs() < _totalDy.abs() * 1.1) {
      _resetDrag();
      return;
    }

    setState(() {
      if (dx < 0) {
        _dragOffset = (_dragOffset - dx).clamp(
          0.0,
          MediaQuery.sizeOf(context).width,
        );
      } else if (_dragOffset > 0) {
        _dragOffset = (_dragOffset + dx).clamp(0.0, double.infinity);
        if (_dragOffset > MediaQuery.sizeOf(context).width) {
          _dragOffset = MediaQuery.sizeOf(context).width;
        }
      }
    });
  }

  void _onPanZoomEnd(PointerPanZoomEndEvent event) {
    if (!_tracking) return;

    final width = MediaQuery.sizeOf(context).width;
    final horizontal =
        _totalDx.abs() > _totalDy.abs() * 1.1 && _totalDx < 0;
    final shouldPop = horizontal &&
        (_dragOffset > width * _popFraction || -_totalDx > _minPopDx);

    _tracking = false;
    if (shouldPop) {
      _dragOffset = 0;
      _pop();
      return;
    }
    _resetDrag();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): _PopIntent(),
      },
      child: Actions(
        actions: {
          _PopIntent: CallbackAction<_PopIntent>(
            onInvoke: (_) {
              _pop();
              return null;
            },
          ),
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if (event.buttons == kBackMouseButton) _pop();
          },
          onPointerPanZoomStart: _onPanZoomStart,
          onPointerPanZoomUpdate: _onPanZoomUpdate,
          onPointerPanZoomEnd: _onPanZoomEnd,
          child: Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _PopIntent extends Intent {
  const _PopIntent();
}
