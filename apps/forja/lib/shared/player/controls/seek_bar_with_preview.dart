import 'dart:async';

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
  bool _hovering = false;
  double _hoverFrac = 0;
  double _trackWidth = 0;
  Uint8List? _previewBytes;
  Timer? _previewDebounce;
  int _previewToken = 0;

  double get _playFrac {
    final total = widget.duration.inMilliseconds.toDouble();
    if (total <= 0) return 0;
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
    playerChromeRegisterSeekScrubCancel(_clearHover);
  }

  @override
  void dispose() {
    _previewToken++;
    _previewDebounce?.cancel();
    _previewDebounce = null;
    playerChromeUnregisterSeekScrubCancel(_clearHover);
    super.dispose();
  }

  void _clearHover() {
    _previewDebounce?.cancel();
    _previewDebounce = null;
    _previewToken++;
    if (!mounted) return;
    if (!_hovering && _previewBytes == null) return;
    setState(() {
      _hovering = false;
      _previewBytes = null;
    });
  }

  void _schedulePreview() {
    _previewDebounce?.cancel();
    if (widget.captureFrame == null) return;
    final token = ++_previewToken;
    _previewDebounce = Timer(const Duration(milliseconds: 200), () async {
      if (!mounted || token != _previewToken || !_hovering) return;
      final bytes = await widget.captureFrame!(_hoverTime);
      if (!mounted || token != _previewToken || !_hovering) return;
      setState(() => _previewBytes = bytes);
    });
  }

  double _fracFromLocal(double dx) {
    if (_trackWidth <= 0) return 0;
    return (dx / _trackWidth).clamp(0.0, 1.0);
  }

  void _seekAtLocalDx(double dx) {
    if (playerChromeOverlayBlocksSeek()) return;
    final total = widget.duration.inMilliseconds.toDouble();
    if (total <= 0) return;
    final frac = _fracFromLocal(dx);
    widget.onDragStart?.call();
    widget.onSeek(Duration(milliseconds: (frac * total).round()));
    widget.onDragEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
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
        if (playerChromeOverlayBlocksSeek()) return;
        setState(() => _hoverFrac = _fracFromLocal(e.localPosition.dx));
        _schedulePreview();
      },
      onExit: (_) => _clearHover(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _seekAtLocalDx(details.localPosition.dx),
        child: SizedBox(
          height: 28,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              if (_hovering)
                Positioned(
                  bottom: 24,
                  left: (_hoverFrac * _trackWidth - 64)
                      .clamp(0.0, (_trackWidth - 128).clamp(0.0, double.infinity)),
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
                      final trackH = _hovering ? 6.0 : 3.0;
                      final thumbR = 6.0;
                      final playPx =
                          (_playFrac * _trackWidth).clamp(0.0, _trackWidth);
                      final hoverPx =
                          (_hoverFrac * _trackWidth).clamp(0.0, _trackWidth);
                      // Keep the full circle inside the track — at 0%/100%
                      // `playPx - thumbR` would sit half outside and get clipped
                      // by the chrome margin / Stack hardEdge.
                      final thumbLeft = (playPx - thumbR).clamp(
                        0.0,
                        (_trackWidth - thumbR * 2).clamp(0.0, double.infinity),
                      );

                      return Stack(
                        clipBehavior: Clip.none,
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
                          if (_hovering)
                            Positioned(
                              left: hoverPx - 1,
                              child: Container(
                                width: 2,
                                height: 16,
                                color: ForjaShellColors.brandGreen
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          Positioned(
                            left: thumbLeft,
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
