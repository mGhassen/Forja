import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/services/pip_service.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop PiP chrome — Safari/system-style controls on hover:
/// expand · Minimize · Close · ±15 · play/pause · scrubber.
class DesktopPipOverlay extends StatelessWidget {
  const DesktopPipOverlay({
    super.key,
    required this.hovering,
    required this.onHoverChanged,
    required this.playing,
    required this.onTogglePlay,
    this.onRestore,
    this.onMinimize,
    this.onClose,
    this.onSeekBack,
    this.onSeekForward,
    this.positionListenable,
    this.durationListenable,
    this.position,
    this.duration,
    this.onSeekTo,
  });

  final bool hovering;
  final ValueChanged<bool> onHoverChanged;
  final bool playing;
  final VoidCallback onTogglePlay;
  final VoidCallback? onRestore;
  final VoidCallback? onMinimize;
  final VoidCallback? onClose;
  final VoidCallback? onSeekBack;
  final VoidCallback? onSeekForward;
  final ValueListenable<Duration>? positionListenable;
  final ValueListenable<Duration>? durationListenable;
  final Duration? position;
  final Duration? duration;
  final ValueChanged<Duration>? onSeekTo;

  bool get _showSeek => onSeekBack != null && onSeekForward != null;
  bool get _showScrubber =>
      onSeekTo != null &&
      (positionListenable != null || position != null) &&
      (durationListenable != null || duration != null);

  Future<void> _restore() async {
    if (onRestore != null) {
      onRestore!();
    } else {
      await PipService.instance.leave();
    }
  }

  Future<void> _minimize() async {
    if (onMinimize != null) {
      onMinimize!();
      return;
    }
    try {
      await windowManager.minimize();
    } catch (e) {
      debugPrint('[DesktopPipOverlay] minimize failed: $e');
    }
  }

  Future<void> _close() async {
    if (onClose != null) {
      onClose!();
      return;
    }
    await PipService.instance.leave();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      opaque: false,
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) {
                unawaited(windowManager.startDragging());
              },
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: _fade(
              child: Row(
                children: [
                  _PipIconChip(
                    icon: Icons.open_in_full_rounded,
                    tooltip: 'Expand',
                    onTap: () => unawaited(_restore()),
                  ),
                  const Spacer(),
                  _PipLabelChip(
                    icon: Icons.remove_rounded,
                    label: 'Minimize',
                    onTap: () => unawaited(_minimize()),
                  ),
                  const SizedBox(width: 8),
                  _PipLabelChip(
                    icon: Icons.close_rounded,
                    label: 'Close',
                    onTap: () => unawaited(_close()),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: _fade(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_showSeek) ...[
                    _PipTransportButton(
                      onTap: onSeekBack!,
                      child: const _SkipGlyph(forward: false),
                    ),
                    const SizedBox(width: 28),
                  ],
                  _PipTransportButton(
                    onTap: onTogglePlay,
                    child: Icon(
                      playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                  if (_showSeek) ...[
                    const SizedBox(width: 28),
                    _PipTransportButton(
                      onTap: onSeekForward!,
                      child: const _SkipGlyph(forward: true),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_showScrubber)
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: _fade(
                child: _PipScrubber(
                  positionListenable: positionListenable,
                  durationListenable: durationListenable,
                  position: position,
                  duration: duration,
                  onSeekTo: onSeekTo!,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fade({required Widget child}) {
    return AnimatedOpacity(
      opacity: hovering ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 160),
      child: IgnorePointer(
        ignoring: !hovering,
        child: child,
      ),
    );
  }
}

class _PipIconChip extends StatelessWidget {
  const _PipIconChip({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final chip = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: _pipChromeDecoration(radius: 10),
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
    if (tooltip == null) return chip;
    return Tooltip(message: tooltip!, child: chip);
  }
}

class _PipLabelChip extends StatelessWidget {
  const _PipLabelChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: _pipChromeDecoration(radius: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PipTransportButton extends StatefulWidget {
  const _PipTransportButton({
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PipTransportButton> createState() => _PipTransportButtonState();
}

class _PipTransportButtonState extends State<_PipTransportButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 90),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Circular skip glyph with "15" — Material has 10/30 only.
class _SkipGlyph extends StatelessWidget {
  const _SkipGlyph({required this.forward});

  final bool forward;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.flip(
            flipX: forward,
            child: const Icon(
              Icons.replay_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const Text(
            '15',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PipScrubber extends StatefulWidget {
  const _PipScrubber({
    required this.onSeekTo,
    this.positionListenable,
    this.durationListenable,
    this.position,
    this.duration,
  });

  final ValueListenable<Duration>? positionListenable;
  final ValueListenable<Duration>? durationListenable;
  final Duration? position;
  final Duration? duration;
  final ValueChanged<Duration> onSeekTo;

  @override
  State<_PipScrubber> createState() => _PipScrubberState();
}

class _PipScrubberState extends State<_PipScrubber> {
  double? _dragFraction;

  Duration _pos() =>
      widget.positionListenable?.value ?? widget.position ?? Duration.zero;

  Duration _dur() =>
      widget.durationListenable?.value ?? widget.duration ?? Duration.zero;

  void _seekFraction(double fraction, {required bool commit}) {
    final dur = _dur();
    if (dur <= Duration.zero) return;
    final clamped = fraction.clamp(0.0, 1.0);
    if (commit) {
      widget.onSeekTo(
        Duration(milliseconds: (dur.inMilliseconds * clamped).round()),
      );
      setState(() => _dragFraction = null);
    } else {
      setState(() => _dragFraction = clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget bar({
      required Duration position,
      required Duration duration,
    }) {
      final liveFrac = duration.inMilliseconds <= 0
          ? 0.0
          : (position.inMilliseconds / duration.inMilliseconds)
              .clamp(0.0, 1.0);
      final frac = _dragFraction ?? liveFrac;

      return LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              _seekFraction(d.localPosition.dx / w, commit: true);
            },
            onHorizontalDragStart: (d) {
              _seekFraction(d.localPosition.dx / w, commit: false);
            },
            onHorizontalDragUpdate: (d) {
              _seekFraction(d.localPosition.dx / w, commit: false);
            },
            onHorizontalDragEnd: (_) {
              final f = _dragFraction;
              if (f != null) _seekFraction(f, commit: true);
            },
            child: SizedBox(
              height: 18,
              child: Center(
                child: SizedBox(
                  height: 5,
                  width: w,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: frac,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    final posL = widget.positionListenable;
    final durL = widget.durationListenable;
    if (posL != null && durL != null) {
      return AnimatedBuilder(
        animation: Listenable.merge([posL, durL]),
        builder: (context, _) => bar(
          position: posL.value,
          duration: durL.value,
        ),
      );
    }
    return bar(position: _pos(), duration: _dur());
  }
}

BoxDecoration _pipChromeDecoration({required double radius}) {
  return BoxDecoration(
    color: Colors.black.withValues(alpha: 0.48),
    borderRadius: BorderRadius.circular(radius),
  );
}
