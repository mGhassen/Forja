import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/iptv/iptv/controller/iptv_controller.dart';

/// Live catalog favorite star - hidden until channel hover (or already favorited).
/// No splash/background; icon heartbeats (scale) while the pointer is on it.
class IptvLiveFavoriteButton extends StatefulWidget {
  const IptvLiveFavoriteButton({
    super.key,
    required this.streamId,
    required this.ctrl,
    required this.reveal,
    this.iconSize = 14,
  });

  final String streamId;
  final IptvController ctrl;
  final bool reveal;
  final double iconSize;

  @override
  State<IptvLiveFavoriteButton> createState() => _IptvLiveFavoriteButtonState();
}

class _IptvLiveFavoriteButtonState extends State<IptvLiveFavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat;
  late final Animation<double> _scale;
  bool _iconHovered = false;

  @override
  void initState() {
    super.initState();
    _beat = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.28).animate(
      CurvedAnimation(parent: _beat, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  void _setIconHovered(bool hovered) {
    if (_iconHovered == hovered) return;
    setState(() => _iconHovered = hovered);
    if (hovered) {
      unawaited(_beat.repeat(reverse: true));
    } else {
      _beat
        ..stop()
        ..value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.ctrl,
      builder: (_, _) {
        final fav = widget.ctrl.isLiveFavorite(widget.streamId);
        final show = widget.reveal || fav;
        return AnimatedOpacity(
          opacity: show ? 1 : 0,
          duration: const Duration(milliseconds: 120),
          child: IgnorePointer(
            ignoring: !show,
            child: MouseRegion(
              onEnter: (_) => _setIconHovered(true),
              onExit: (_) => _setIconHovered(false),
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    unawaited(widget.ctrl.toggleLiveFavorite(widget.streamId)),
                child: SizedBox(
                  width: widget.iconSize + 6,
                  height: widget.iconSize + 6,
                  child: Center(
                    child: ScaleTransition(
                      scale: _scale,
                      child: Icon(
                        fav ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: widget.iconSize,
                        color: fav
                            ? const Color(0xFFFBBF24)
                            : Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
