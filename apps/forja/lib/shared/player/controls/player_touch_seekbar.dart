import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/player/utils.dart';

/// Touch-friendly seek bar for mobile / TV player chrome (no hover preview).
class PlayerTouchSeekBar extends StatefulWidget {
  const PlayerTouchSeekBar({
    super.key,
    required this.duration,
    required this.position,
    required this.bufferedPosition,
    required this.onSeek,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final Duration duration;
  final Duration position;
  final Duration bufferedPosition;
  final void Function(Duration) onSeek;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  @override
  State<PlayerTouchSeekBar> createState() => _PlayerTouchSeekBarState();
}

class _PlayerTouchSeekBarState extends State<PlayerTouchSeekBar> {
  bool _isDragging = false;
  double _dragFrac = 0.0;
  double _trackWidth = 0.0;

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

  Duration get _dragTime {
    final total = widget.duration.inMilliseconds.toDouble();
    return Duration(milliseconds: (_dragFrac * total).round());
  }

  double _fracFromLocal(double dx) => (dx / _trackWidth).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    playerChromeRegisterSeekScrubCancel(_cancelScrubFromOverlay);
  }

  @override
  void dispose() {
    playerChromeUnregisterSeekScrubCancel(_cancelScrubFromOverlay);
    super.dispose();
  }

  void _cancelScrubFromOverlay() {
    if (!mounted || !_isDragging) return;
    setState(() => _isDragging = false);
    widget.onDragEnd();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (d) {
        if (playerChromeOverlayBlocksSeek()) return;
        widget.onDragStart();
        setState(() {
          _isDragging = true;
          _dragFrac = _fracFromLocal(d.localPosition.dx);
        });
      },
      onHorizontalDragUpdate: (d) {
        if (!_isDragging) return;
        if (playerChromeOverlayBlocksSeek()) {
          _cancelScrubFromOverlay();
          return;
        }
        setState(() {
          _dragFrac = _fracFromLocal(d.localPosition.dx);
        });
      },
      onHorizontalDragEnd: (_) {
        if (!_isDragging) return;
        final total = widget.duration.inMilliseconds.toDouble();
        if (!playerChromeOverlayBlocksSeek()) {
          widget.onSeek(Duration(milliseconds: (_dragFrac * total).round()));
        }
        widget.onDragEnd();
        setState(() => _isDragging = false);
      },
      onTapUp: (d) {
        if (playerChromeOverlayBlocksSeek()) return;
        final total = widget.duration.inMilliseconds.toDouble();
        widget.onSeek(
          Duration(
            milliseconds: (_fracFromLocal(d.localPosition.dx) * total).round(),
          ),
        );
      },
      child: SizedBox(
        height: 32,
        child: Align(
          alignment: Alignment.center,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _trackWidth = constraints.maxWidth;

              final trackH = _isDragging ? 6.0 : 3.5;
              final thumbR = _isDragging ? 8.0 : 5.5;
              final playPx = (_playFrac * _trackWidth).clamp(0.0, _trackWidth);

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    height: trackH,
                    width: _trackWidth,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(trackH),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: trackH,
                    width: (_bufFrac * _trackWidth).clamp(0.0, _trackWidth),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.32),
                      borderRadius: BorderRadius.circular(trackH),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    curve: Curves.easeOut,
                    height: trackH,
                    width: playPx,
                    decoration: BoxDecoration(
                      color: ForjaShellColors.brandGreen,
                      borderRadius: BorderRadius.circular(trackH),
                    ),
                  ),
                  Positioned(
                    left: playPx - thumbR,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      curve: Curves.easeOut,
                      width: thumbR * 2,
                      height: thumbR * 2,
                      decoration: BoxDecoration(
                        color: ForjaShellColors.brandGreen,
                        shape: BoxShape.circle,
                        boxShadow: _isDragging
                            ? [
                                BoxShadow(
                                  color: ForjaShellColors.brandGreen
                                      .withValues(alpha: 0.35),
                                  blurRadius: 8,
                                ),
                              ]
                            : [],
                      ),
                    ),
                  ),
                  if (_isDragging && widget.duration.inMilliseconds > 0)
                    Positioned(
                      left: (playPx - 36).clamp(0.0, _trackWidth - 72),
                      top: -34,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E).withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: SizedBox(
                          width: 56,
                          child: Text(
                            formatDuration(_dragTime),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
