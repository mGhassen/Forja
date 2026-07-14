part of 'mobile_player_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MOBILE SEEKBAR  — touch-friendly, no tooltip (no hover on mobile)
// ─────────────────────────────────────────────────────────────────────────────

class _MobileSeekbar extends StatefulWidget {
  final Duration duration;
  final Duration position;
  final Duration bufferedPosition;
  final void Function(Duration) onSeek;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  const _MobileSeekbar({
    required this.duration,
    required this.position,
    required this.bufferedPosition,
    required this.onSeek,
    required this.onDragStart,
    required this.onDragEnd,
  });

  @override
  State<_MobileSeekbar> createState() => _MobileSeekbarState();
}

class _MobileSeekbarState extends State<_MobileSeekbar> {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (d) {
        widget.onDragStart();
        setState(() {
          _isDragging = true;
          _dragFrac = _fracFromLocal(d.localPosition.dx);
        });
      },
      onHorizontalDragUpdate: (d) => setState(() {
        _dragFrac = _fracFromLocal(d.localPosition.dx);
      }),
      onHorizontalDragEnd: (_) {
        final total = widget.duration.inMilliseconds.toDouble();
        widget.onSeek(Duration(milliseconds: (_dragFrac * total).round()));
        widget.onDragEnd();
        setState(() => _isDragging = false);
      },
      onTapUp: (d) {
        final total = widget.duration.inMilliseconds.toDouble();
        widget.onSeek(
          Duration(
            milliseconds: (_fracFromLocal(d.localPosition.dx) * total).round(),
          ),
        );
      },
      // 32px tall hit area — much easier to grab on touch
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
                  // Background
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
                  // Buffered
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: trackH,
                    width: (_bufFrac * _trackWidth).clamp(0.0, _trackWidth),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.32),
                      borderRadius: BorderRadius.circular(trackH),
                    ),
                  ),
                  // Played
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    curve: Curves.easeOut,
                    height: trackH,
                    width: playPx,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(trackH),
                    ),
                  ),
                  // Thumb dot
                  Positioned(
                    left: playPx - thumbR,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      curve: Curves.easeOut,
                      width: thumbR * 2,
                      height: thumbR * 2,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: _isDragging
                            ? [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                ),
                              ]
                            : [],
                      ),
                    ),
                  ),
                  // Drag time label — floats above thumb while dragging
                  if (_isDragging && widget.duration.inMilliseconds > 0)
                    Positioned(
                      left: (playPx - 36).clamp(0.0, _trackWidth - 72),
                      top: -34,
                      child: _PlayerChromeSurface(
                        radius: 8,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: SizedBox(
                          width: 56,
                          child: Text(
                            formatDuration(_dragTime),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
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

// ─────────────────────────────────────────────────────────────────────────────
//  SIDE INDICATOR  (volume / brightness vertical pill)
// ─────────────────────────────────────────────────────────────────────────────

/// Replaces VolumeBrightnessIndicator from shared_widgets — self-contained.
class _SideIndicator extends StatelessWidget {
  final IconData icon;
  final double value; // 0.0 – 1.0

  const _SideIndicator({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return _PlayerChromeSurface(
      radius: 20,
      child: SizedBox(
        width: 44,
        height: 160,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 14,
                ),
                child: RotatedBox(
                  quarterTurns: -1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: value.clamp(0.0, 1.0),
                      backgroundColor: Colors.white24,
                      color: Colors.white,
                      minHeight: 4,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${(value * 100).round()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
