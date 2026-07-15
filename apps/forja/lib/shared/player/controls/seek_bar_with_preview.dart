import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/player/utils.dart';

typedef SeekFrameCapture = Future<Uint8List?> Function(Duration position);

class SeekBarWithPreview extends StatefulWidget {
  const SeekBarWithPreview({
    super.key,
    required this.duration,
    required this.position,
    required this.bufferedPosition,
    required this.onSeek,
    this.onDragStart,
    this.onDragEnd,
    this.captureFrame,
  });

  final Duration duration;
  final Duration position;
  final Duration bufferedPosition;
  final void Function(Duration) onSeek;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final SeekFrameCapture? captureFrame;

  @override
  State<SeekBarWithPreview> createState() => _SeekBarWithPreviewState();
}

class _SeekBarWithPreviewState extends State<SeekBarWithPreview> {
  bool _isDragging = false;
  bool _hovering = false;
  double _dragFrac = 0;
  double _hoverFrac = 0;
  double _trackWidth = 0;
  Uint8List? _previewBytes;
  Timer? _previewDebounce;
  int _previewToken = 0;
  int? _activePointer;
  Offset? _downGlobal;
  bool _movedEnoughToScrub = false;

  double get _playFrac {
    final total = widget.duration.inMilliseconds.toDouble();
    if (total <= 0) return 0;
    if (_isDragging) return _dragFrac;
    return (widget.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  double get _bufFrac {
    final total = widget.duration.inMilliseconds.toDouble();
    if (total <= 0) return 0;
    return (widget.bufferedPosition.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Duration get _hoverTime {
    final total = widget.duration.inMilliseconds.toDouble();
    return Duration(milliseconds: (_hoverFrac * total).round());
  }

  @override
  void initState() {
    super.initState();
    playerChromeRegisterSeekScrubCancel(_cancelScrubFromOverlay);
  }

  @override
  void dispose() {
    playerChromeUnregisterSeekScrubCancel(_cancelScrubFromOverlay);
    _detachGlobalPointerRoute();
    _previewDebounce?.cancel();
    super.dispose();
  }

  void _cancelScrubFromOverlay() {
    if (!mounted) return;
    if (!_isDragging && !_hovering && _activePointer == null) return;
    _endScrub(commit: false, clearHover: true);
  }

  void _schedulePreview() {
    _previewDebounce?.cancel();
    if (widget.captureFrame == null) return;
    final token = ++_previewToken;
    _previewDebounce = Timer(const Duration(milliseconds: 200), () async {
      final bytes = await widget.captureFrame!(_hoverTime);
      if (!mounted || token != _previewToken) return;
      setState(() => _previewBytes = bytes);
    });
  }

  double _fracFromLocal(double dx) {
    if (_trackWidth <= 0) return 0;
    return (dx / _trackWidth).clamp(0.0, 1.0);
  }

  double _fracFromGlobal(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return _dragFrac;
    return _fracFromLocal(box.globalToLocal(global).dx);
  }

  void _attachGlobalPointerRoute() {
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalPointer);
  }

  void _detachGlobalPointerRoute() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onGlobalPointer);
  }

  void _onGlobalPointer(PointerEvent event) {
    final pointer = _activePointer;
    if (pointer == null || event.pointer != pointer) return;

    // Source / Audio / etc. overlays steal the cursor — release scrub so the
    // thumb does not stay magnetized to the pointer over the menu.
    if (playerChromeOverlayBlocksSeek()) {
      _endScrub(commit: false, clearHover: true);
      return;
    }

    if (event is PointerMoveEvent) {
      final down = _downGlobal;
      if (!_movedEnoughToScrub && down != null) {
        final dist = (event.position - down).distance;
        if (dist < kTouchSlop) return;
        _movedEnoughToScrub = true;
        if (!_isDragging) {
          widget.onDragStart?.call();
          setState(() {
            _isDragging = true;
            _dragFrac = _fracFromGlobal(event.position);
            _hoverFrac = _dragFrac;
          });
          _schedulePreview();
        }
      }
      if (!_isDragging) return;
      setState(() {
        _dragFrac = _fracFromGlobal(event.position);
        _hoverFrac = _dragFrac;
      });
      _schedulePreview();
      return;
    }

    if (event is PointerUpEvent || event is PointerCancelEvent) {
      final commit = event is PointerUpEvent &&
          (_isDragging || !_movedEnoughToScrub);
      // Tap (no drag): seek to press position. Drag: seek to final frac.
      if (commit && !playerChromeOverlayBlocksSeek()) {
        final total = widget.duration.inMilliseconds.toDouble();
        final frac = _isDragging
            ? _dragFrac
            : _fracFromGlobal(event.position);
        widget.onSeek(Duration(milliseconds: (frac * total).round()));
      }
      _endScrub(commit: false, clearHover: false);
    }
  }

  void _endScrub({required bool commit, required bool clearHover}) {
    final wasDragging = _isDragging;
    _detachGlobalPointerRoute();
    _activePointer = null;
    _downGlobal = null;
    _movedEnoughToScrub = false;
    if (wasDragging) {
      if (commit && !playerChromeOverlayBlocksSeek()) {
        final total = widget.duration.inMilliseconds.toDouble();
        widget.onSeek(Duration(milliseconds: (_dragFrac * total).round()));
      }
      widget.onDragEnd?.call();
    }
    if (!mounted) return;
    setState(() {
      _isDragging = false;
      if (clearHover) {
        _hovering = false;
        _previewBytes = null;
      }
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    if (playerChromeOverlayBlocksSeek()) return;
    if (event.buttons != kPrimaryButton && event.buttons != 0) return;
    _detachGlobalPointerRoute();
    _activePointer = event.pointer;
    _downGlobal = event.position;
    _movedEnoughToScrub = false;
    _attachGlobalPointerRoute();
    setState(() {
      _hoverFrac = _fracFromLocal(event.localPosition.dx);
      _dragFrac = _hoverFrac;
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _hovering || _isDragging;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (e) {
        if (playerChromeOverlayBlocksSeek()) return;
        setState(() {
          _hovering = true;
          _hoverFrac = _fracFromLocal(e.localPosition.dx);
        });
        _schedulePreview();
      },
      onHover: (e) {
        if (playerChromeOverlayBlocksSeek() || _isDragging) return;
        setState(() => _hoverFrac = _fracFromLocal(e.localPosition.dx));
        _schedulePreview();
      },
      onExit: (_) {
        if (_isDragging) return;
        setState(() {
          _hovering = false;
          _previewBytes = null;
        });
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        // Fixed hit height — preview paints above via [clipBehavior: Clip.none]
        // and must not grow this box into the transport / Source button row.
        child: SizedBox(
          height: 28,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              if (active)
                Positioned(
                  bottom: 24,
                  left: (_hoverFrac * _trackWidth - 64)
                      .clamp(0.0, _trackWidth - 128),
                  child: IgnorePointer(
                    child: _PreviewBubble(
                      time: _hoverTime,
                      imageBytes: _previewBytes,
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: 20,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _trackWidth = constraints.maxWidth;
                      final trackH = active ? 6.0 : 3.0;
                      final thumbR = active ? 7.0 : 0.0;
                      final playPx =
                          (_playFrac * _trackWidth).clamp(0.0, _trackWidth);
                      final hoverPx =
                          (_hoverFrac * _trackWidth).clamp(0.0, _trackWidth);

                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: trackH,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(trackH),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: _bufFrac.clamp(0.001, 1.0),
                            child: Container(
                              height: trackH,
                              decoration: BoxDecoration(
                                color: Colors.white38,
                                borderRadius: BorderRadius.circular(trackH),
                              ),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: _playFrac.clamp(0.001, 1.0),
                            child: Container(
                              height: trackH,
                              decoration: BoxDecoration(
                                color: ForjaShellColors.brandGreen,
                                borderRadius: BorderRadius.circular(trackH),
                              ),
                            ),
                          ),
                          if (active)
                            Positioned(
                              left: hoverPx - 1,
                              child: Container(
                                width: 2,
                                height: 16,
                                color: ForjaShellColors.brandGreen
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          if (thumbR > 0)
                            Positioned(
                              left: playPx - thumbR,
                              child: Container(
                                width: thumbR * 2,
                                height: thumbR * 2,
                                decoration: const BoxDecoration(
                                  color: ForjaShellColors.brandGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewBubble extends StatelessWidget {
  const _PreviewBubble({required this.time, this.imageBytes});

  final Duration time;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (imageBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              imageBytes!,
              width: 128,
              height: 72,
              fit: BoxFit.cover,
            ),
          )
        else
          Container(
            width: 128,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              formatDuration(time),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          formatDuration(time),
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ],
    );
  }
}
