import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Live channel favorite star — hidden until [reveal] (or already favorited).
class LiveFavoriteStar extends StatefulWidget {
  const LiveFavoriteStar({
    super.key,
    required this.favorited,
    required this.onToggle,
    required this.reveal,
    this.iconSize = ShellTokens.favStarIconSize,
  });

  final bool favorited;
  final VoidCallback onToggle;
  final bool reveal;
  final double iconSize;

  @override
  State<LiveFavoriteStar> createState() => _LiveFavoriteStarState();
}

class _LiveFavoriteStarState extends State<LiveFavoriteStar>
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
    final show = widget.reveal || widget.favorited;
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
            onTap: widget.onToggle,
            child: SizedBox(
              width: widget.iconSize + 6,
              height: widget.iconSize + 6,
              child: Center(
                child: ScaleTransition(
                  scale: _scale,
                  child: Icon(
                    widget.favorited
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: widget.iconSize,
                    color: widget.favorited
                        ? const Color(0xFFFBBF24)
                        : ForjaShellColors.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
