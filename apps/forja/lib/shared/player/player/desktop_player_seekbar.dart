part of 'desktop_player_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  GLASSY SEEKBAR  — hover tooltip + preview line + smooth thumb
// ─────────────────────────────────────────────────────────────────────────────

class _GlassSeekbar extends StatefulWidget {
  final Duration duration;
  final Duration position;
  final Duration bufferedPosition;
  final void Function(Duration) onSeek;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  const _GlassSeekbar({
    required this.duration,
    required this.position,
    required this.bufferedPosition,
    required this.onSeek,
    required this.onDragStart,
    required this.onDragEnd,
  });

  @override
  State<_GlassSeekbar> createState() => _GlassSeekbarState();
}

class _GlassSeekbarState extends State<_GlassSeekbar> {
  bool _isDragging = false;
  bool _hovering = false;
  double _dragFrac = 0.0; // 0..1 fraction while dragging
  double _hoverFrac = 0.0; // 0..1 fraction of cursor position
  double _trackWidth = 0.0; // cached from LayoutBuilder

  // ── Fractions ───────────────────────────────────────────────────────────
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

  // ── Time at hover position ───────────────────────────────────────────────
  Duration get _hoverTime {
    final total = widget.duration.inMilliseconds.toDouble();
    return Duration(milliseconds: (_hoverFrac * total).round());
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  double _fracFromLocal(double dx) => (dx / _trackWidth).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final active = _hovering || _isDragging;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (e) => setState(() {
        _hovering = true;
        _hoverFrac = _fracFromLocal(e.localPosition.dx);
      }),
      onHover: (e) => setState(() {
        _hoverFrac = _fracFromLocal(e.localPosition.dx);
      }),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) {
          widget.onDragStart();
          setState(() {
            _isDragging = true;
            _dragFrac = _fracFromLocal(d.localPosition.dx);
            _hoverFrac = _dragFrac;
          });
        },
        onHorizontalDragUpdate: (d) => setState(() {
          _dragFrac = _fracFromLocal(d.localPosition.dx);
          _hoverFrac = _dragFrac;
        }),
        onHorizontalDragEnd: (_) {
          final total = widget.duration.inMilliseconds.toDouble();
          widget.onSeek(Duration(milliseconds: (_dragFrac * total).round()));
          widget.onDragEnd();
          setState(() => _isDragging = false);
        },
        onTapUp: (d) {
          final total = widget.duration.inMilliseconds.toDouble();
          final frac = _fracFromLocal(d.localPosition.dx);
          widget.onSeek(Duration(milliseconds: (frac * total).round()));
        },
        // Extra vertical hit area so the thin bar is easy to grab
        child: SizedBox(
          height: 28,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 20,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _trackWidth = constraints.maxWidth;

                  // ── track height animates from 3 → 6 on active ────────────
                  final trackH = active ? 6.0 : 3.0;
                  // ── thumb radius: 0 → 7 on active, centred on playhead ────
                  final thumbR = active ? 7.0 : 0.0;
                  // ── playhead + hover pixel positions ─────────────────────
                  final playPx = (_playFrac * _trackWidth).clamp(
                    0.0,
                    _trackWidth,
                  );
                  final hoverPx = (_hoverFrac * _trackWidth).clamp(
                    0.0,
                    _trackWidth,
                  );

                  // ── Tooltip horizontal clamp so it never overflows ─────────
                  const tipW = 72.0;
                  final tipLeft = (hoverPx - tipW / 2).clamp(
                    0.0,
                    _trackWidth - tipW,
                  );

                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      // ── Background track ────────────────────────────────
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                        height: trackH,
                        width: _trackWidth,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(trackH),
                        ),
                      ),

                      // ── Buffered ─────────────────────────────────────────
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                        height: trackH,
                        width: (_bufFrac * _trackWidth).clamp(0.0, _trackWidth),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.30),
                          borderRadius: BorderRadius.circular(trackH),
                        ),
                      ),

                      // ── Played ───────────────────────────────────────────
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

                      // ── Hover preview line (ghosted, thin) ───────────────
                      if (active)
                        Positioned(
                          left: hoverPx - 1,
                          child: AnimatedOpacity(
                            opacity: active ? 0.45 : 0.0,
                            duration: const Duration(milliseconds: 120),
                            child: Container(
                              width: 1.5,
                              height: trackH + 4,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        ),

                      // ── Playhead thumb dot ───────────────────────────────
                      Positioned(
                        left: playPx - thumbR,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOut,
                          width: thumbR * 2,
                          height: thumbR * 2,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : [],
                          ),
                        ),
                      ),

                      // ── Hover tooltip: glassy pill above cursor ──────────
                      if (active && widget.duration.inMilliseconds > 0)
                        Positioned(
                          top: -38,
                          left: tipLeft,
                          child: AnimatedOpacity(
                            opacity: active ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 120),
                            child: Container(
                              width: tipW,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF1C1C1E,
                                ).withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  width: 0.6,
                                ),
                              ),
                              child: Text(
                                formatDuration(_hoverTime),
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
        ),
      ),
    );
  }
}
