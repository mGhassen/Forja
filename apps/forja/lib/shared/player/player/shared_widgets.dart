import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/seek_bar_zones.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'utils.dart'; // Ensure formatDuration is available

class PlayerIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color backgroundColor;
  final Color iconColor;

  const PlayerIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44.0,
    this.iconSize = 22.0,
    this.backgroundColor = const Color(0xA61A1A1A), // 0xFF1A1A1A with 0.65 opacity
    this.iconColor = const Color(0xEBEBEBEB), // White with 0.92 opacity
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

class PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPressed;
  final bool isBuffering;

  const PlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.onPressed,
    this.isBuffering = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xA61A1A1A),
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Center(
            child: isBuffering
                ? const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 32,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
          ),
        ),
      ),
    );
  }
}

class CustomSeekbar extends StatefulWidget {
  final Duration duration;
  final Duration position;
  final Duration bufferedPosition;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<Duration>? onSeekPreview;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final List<SeekBarZone> zones;
  final bool tvFocusable;
  final FocusNode? focusNode;
  final FocusNode? tvFocusUpNode;
  final VoidCallback? onTvFocusUp;
  final VoidCallback? onTvFocusDown;
  final VoidCallback? onTvFocusLeft;
  final VoidCallback? onTvFocusRight;
  final Duration tvSeekStep;

  const CustomSeekbar({
    super.key,
    required this.duration,
    required this.position,
    this.bufferedPosition = Duration.zero,
    this.onSeek,
    this.onSeekPreview,
    this.onDragStart,
    this.onDragEnd,
    this.zones = const [],
    this.tvFocusable = false,
    this.focusNode,
    this.tvFocusUpNode,
    this.onTvFocusUp,
    this.onTvFocusDown,
    this.onTvFocusLeft,
    this.onTvFocusRight,
    this.tvSeekStep = const Duration(seconds: 10),
  });

  @override
  State<CustomSeekbar> createState() => _CustomSeekbarState();
}

class _CustomSeekbarState extends State<CustomSeekbar> {
  bool _isDragging = false;
  double _dragValue = 0.0; // In milliseconds
  bool _tvFocused = false;
  Timer? _seekPreviewDebounce;
  /// TV: OK arms thumb scrub; then L/R nudge preview; OK commits; Back cancels.
  /// Unarmed L/R leave focus to left/right chrome (not seek).
  bool _tvScrubArmed = false;
  DateTime? _tvHoldStartedAt;
  LogicalKeyboardKey? _tvHoldKey;
  int _tvHoldStride = 1;

  // Hover state for Desktop
  bool _isHovering = false;
  double _hoverValue = 0.0; // In milliseconds

  late final FocusNode _ownedFocusNode = FocusNode(debugLabel: 'player-seekbar');

  FocusNode get _focusNode => widget.focusNode ?? _ownedFocusNode;

  @override
  void initState() {
    super.initState();
    playerChromeRegisterSeekScrubCancel(_cancelScrubFromOverlay);
  }

  @override
  void dispose() {
    _seekPreviewDebounce?.cancel();
    playerChromeUnregisterSeekScrubCancel(_cancelScrubFromOverlay);
    if (widget.focusNode == null) {
      _ownedFocusNode.dispose();
    }
    super.dispose();
  }

  void _cancelScrubFromOverlay() {
    if (!mounted) return;
    if (!_isDragging && !_isHovering && !_tvScrubArmed) return;
    final wasDragging = _isDragging;
    setState(() {
      _isDragging = false;
      _isHovering = false;
      _tvScrubArmed = false;
      _resetTvScrubHold();
    });
    if (wasDragging) widget.onDragEnd?.call();
  }

  void _resetTvScrubHold() {
    _tvHoldStartedAt = null;
    _tvHoldKey = null;
    _tvHoldStride = 1;
  }

  void _scheduleSeekPreview(Duration position) {
    final cb = widget.onSeekPreview;
    if (cb == null) return;
    _seekPreviewDebounce?.cancel();
    _seekPreviewDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      cb(position);
    });
  }

  String? get _tvScrubSpeedLabel {
    if (!_tvScrubArmed || _tvHoldKey == null) return null;
    final left = _tvHoldKey == LogicalKeyboardKey.arrowLeft;
    return switch (_tvHoldStride) {
      5 => left ? '<x' : 'x>',
      3 => left ? '<<<' : '>>>',
      2 => left ? '<<' : '>>',
      _ => left ? '<' : '>',
    };
  }

  int _tvScrubStride(KeyEvent event) {
    final key = event.logicalKey;
    if (event is KeyDownEvent) {
      _tvHoldStartedAt = DateTime.now();
      _tvHoldKey = key;
      _tvHoldStride = 1;
      return 1;
    }
    if (event is KeyRepeatEvent &&
        _tvHoldKey == key &&
        _tvHoldStartedAt != null) {
      _tvHoldStride = ShellTvHoldAccel.seekStepForHoldMs(
        DateTime.now().difference(_tvHoldStartedAt!).inMilliseconds,
      );
      return _tvHoldStride;
    }
    return 1;
  }

  void _nudgeTvScrub(int direction, {int stride = 1}) {
    final total = widget.duration;
    if (total <= Duration.zero) return;
    final steps = stride < 1 ? 1 : stride;
    final base = Duration(milliseconds: _dragValue.toInt());
    var next = base + widget.tvSeekStep * (direction * steps);
    if (next < Duration.zero) next = Duration.zero;
    if (next > total) next = total;
    setState(() {
      _dragValue = next.inMilliseconds.toDouble();
    });
    _scheduleSeekPreview(next);
  }

  void _commitTvScrub() {
    if (!_tvScrubArmed) return;
    final seekTo = Duration(milliseconds: _dragValue.toInt());
    setState(() {
      _tvScrubArmed = false;
      _isDragging = false;
      _resetTvScrubHold();
    });
    if (!playerChromeOverlayBlocksSeek()) {
      widget.onSeek?.call(seekTo);
    }
    widget.onDragEnd?.call();
  }

  void _cancelTvScrub() {
    if (!_tvScrubArmed) return;
    setState(() {
      _tvScrubArmed = false;
      _isDragging = false;
      _resetTvScrubHold();
    });
    widget.onDragEnd?.call();
  }

  KeyEventResult _onTvKey(FocusNode node, KeyEvent event) {
    if (!widget.tvFocusable || !shellTvIsNavigationKey(event)) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (shellTvIsActivateKey(event)) {
      if (_tvScrubArmed) {
        _commitTvScrub();
      } else {
        setState(() {
          _tvScrubArmed = true;
          _isDragging = true;
          _dragValue = widget.position.inMilliseconds.toDouble();
        });
        widget.onDragStart?.call();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      if (_tvScrubArmed) {
        _cancelTvScrub();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    // Scrub only after OK arms the thumb. Unarmed ←/→ leave the bar to
    // left/right chrome (Play / Sources), same as ↑/↓.
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_tvScrubArmed) {
        _nudgeTvScrub(-1, stride: _tvScrubStride(event));
        return KeyEventResult.handled;
      }
      if (widget.onTvFocusLeft != null) {
        widget.onTvFocusLeft!();
        return KeyEventResult.handled;
      }
      if (node.focusInDirection(TraversalDirection.left)) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (_tvScrubArmed) {
        _nudgeTvScrub(1, stride: _tvScrubStride(event));
        return KeyEventResult.handled;
      }
      if (widget.onTvFocusRight != null) {
        widget.onTvFocusRight!();
        return KeyEventResult.handled;
      }
      if (node.focusInDirection(TraversalDirection.right)) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_tvScrubArmed) {
        _cancelTvScrub();
      }
      if (widget.onTvFocusUp != null) {
        widget.onTvFocusUp!();
        return KeyEventResult.handled;
      }
      final upNode = widget.tvFocusUpNode;
      if (upNode != null && upNode.canRequestFocus) {
        upNode.requestFocus();
        return KeyEventResult.handled;
      }
      // Focused seek node — not FocusScope (full-screen chrome finds no neighbors).
      if (node.focusInDirection(TraversalDirection.up)) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_tvScrubArmed) return KeyEventResult.handled;
      if (widget.onTvFocusDown != null) {
        widget.onTvFocusDown!();
        return KeyEventResult.handled;
      }
      if (node.focusInDirection(TraversalDirection.down)) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final totalMilliseconds = widget.duration.inMilliseconds.toDouble();
    final currentMilliseconds = widget.position.inMilliseconds.toDouble();
    final bufferedMilliseconds = widget.bufferedPosition.inMilliseconds.toDouble();

    // Avoid division by zero
    final double safeTotal = totalMilliseconds > 0 ? totalMilliseconds : 1.0;

    double relativePosition = (_isDragging ? _dragValue : currentMilliseconds) / safeTotal;
    
    // Clamp
    relativePosition = relativePosition.clamp(0.0, 1.0);

    double bufferedRelative = bufferedMilliseconds / safeTotal;
    bufferedRelative = bufferedRelative.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final thumbR =
            (_isDragging || _tvFocused || _tvScrubArmed) ? 8.0 : 6.0;
        final playPx = relativePosition * constraints.maxWidth;
        final thumbLeft = (playPx - thumbR).clamp(
          0.0,
          (constraints.maxWidth - thumbR * 2).clamp(0.0, double.infinity),
        );
        final track = MouseRegion(
          onEnter: (_) {
            if (playerChromeOverlayBlocksSeek()) return;
            setState(() => _isHovering = true);
          },
          onExit: (_) => setState(() => _isHovering = false),
          onHover: (details) {
            if (playerChromeOverlayBlocksSeek() || _isDragging) return;
            setState(() {
              double dx = details.localPosition.dx.clamp(0.0, constraints.maxWidth);
              _hoverValue = (dx / constraints.maxWidth) * safeTotal;
            });
            _scheduleSeekPreview(
              Duration(milliseconds: _hoverValue.toInt()),
            );
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (details) {
              if (playerChromeOverlayBlocksSeek()) return;
              setState(() {
                _isDragging = true;
                double dx = details.localPosition.dx.clamp(0.0, constraints.maxWidth);
                _dragValue = (dx / constraints.maxWidth) * safeTotal;
              });
              widget.onDragStart?.call();
            },
            onHorizontalDragUpdate: (details) {
              if (!_isDragging) return;
              if (playerChromeOverlayBlocksSeek()) {
                _cancelScrubFromOverlay();
                return;
              }
              setState(() {
                double dx = details.localPosition.dx.clamp(0.0, constraints.maxWidth);
                _dragValue = (dx / constraints.maxWidth) * safeTotal;
              });
              _scheduleSeekPreview(
                Duration(milliseconds: _dragValue.toInt()),
              );
            },
            onHorizontalDragEnd: (details) {
              if (!_isDragging) return;
              final seekTo = Duration(milliseconds: _dragValue.toInt());
              setState(() {
                _isDragging = false;
              });
              if (!playerChromeOverlayBlocksSeek()) {
                widget.onSeek?.call(seekTo);
              }
              widget.onDragEnd?.call();
            },
            onTapUp: (details) {
               if (playerChromeOverlayBlocksSeek()) return;
               final dx = details.localPosition.dx.clamp(0.0, constraints.maxWidth);
               final value = (dx / constraints.maxWidth) * safeTotal;
               widget.onSeek?.call(Duration(milliseconds: value.toInt()));
            },
            child: SizedBox(
              height: 30, // Touch target height
              child: Stack(
                alignment: Alignment.centerLeft,
                clipBehavior: Clip.none, // Allow tooltip to overflow upwards
                children: [
                  // Background Track
                  Container(
                    height: _tvFocused ? 4.0 : 3.0,
                    width: double.infinity,
                    color: Colors.white.withValues(alpha: _tvFocused ? 0.40 : 0.30),
                  ),
                  // Buffered Track
                  FractionallySizedBox(
                    widthFactor: bufferedRelative,
                    child: Container(
                      height: _tvFocused ? 4.0 : 3.0,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  if (widget.zones.isNotEmpty)
                    SeekBarZoneLayer(
                      zones: widget.zones,
                      width: constraints.maxWidth,
                      height: _tvFocused ? 4.0 : 3.0,
                    ),
                  // Played Track
                  FractionallySizedBox(
                    widthFactor: relativePosition,
                    child: Container(
                      height: _tvFocused ? 4.0 : 3.0,
                      color: ForjaShellColors.brandGreen,
                    ),
                  ),
                  // Thumb — inset so 0%/100% keep a full circle (not half-clipped)
                  Positioned(
                    left: thumbLeft,
                    child: Container(
                      width: thumbR * 2,
                      height: thumbR * 2,
                      decoration: BoxDecoration(
                        color: ForjaShellColors.brandGreen,
                        shape: BoxShape.circle,
                        border: _tvScrubArmed
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Tooltip (Hover on Windows, Drag on Mobile/Windows, TV focus)
                  if (_isDragging || _isHovering || _tvFocused)
                    Positioned(
                      left: (_isDragging 
                          ? (relativePosition * constraints.maxWidth) 
                          : _isHovering
                              ? (_hoverValue / safeTotal * constraints.maxWidth)
                              : (relativePosition * constraints.maxWidth)) - 24,
                      top: _tvScrubSpeedLabel != null ? -52 : -35,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              formatDuration(Duration(
                                milliseconds: _isDragging
                                    ? _dragValue.toInt()
                                    : _isHovering
                                        ? _hoverValue.toInt()
                                        : widget.position.inMilliseconds,
                              )),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_tvScrubSpeedLabel case final speed?)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                speed,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

        if (!widget.tvFocusable) return track;

        return Focus(
          focusNode: _focusNode,
          onFocusChange: (focused) {
            setState(() {
              _tvFocused = focused;
              if (!focused && _tvScrubArmed) {
                _tvScrubArmed = false;
                _isDragging = false;
                _resetTvScrubHold();
              }
            });
          },
          onKeyEvent: _onTvKey,
          child: track,
        );
      },
    );
  }
}

class OverlayGradient extends StatelessWidget {
  final bool isTop;

  const OverlayGradient({super.key, this.isTop = true});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: isTop ? 140 : 140, // Height for gradient area
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: isTop ? 0.75 : 0.80),
              Colors.transparent,
            ],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

class VolumeBrightnessIndicator extends StatelessWidget {
  final bool isBrightness;
  final double value; // 0.0 to 1.0

  const VolumeBrightnessIndicator({
    super.key,
    required this.isBrightness,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            isBrightness ? Icons.brightness_6_outlined : Icons.volume_up_outlined,
            color: Colors.white,
            size: 20,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: RotatedBox(
                quarterTurns: -1,
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Text(
            "${(value * 100).toInt()}%",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class PillButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const PillButton({
    super.key,
    required this.text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xA61A1A1A),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
