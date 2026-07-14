part of 'player_stream_menu.dart';

/// Indented stream list with a vertical branch line under its server.
class _ServerStreamBranch extends StatelessWidget {
  const _ServerStreamBranch({
    required this.child,
  });

  final Widget child;

  static const _padLeft = 4.0;
  static const _gapAfterLine = 8.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: _padLeft, bottom: 2),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, right: _gapAfterLine),
              child: Container(
                width: 1,
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _FlatMenuRow extends StatefulWidget {
  const _FlatMenuRow({
    required this.label,
    this.meta,
    this.selected = false,
    this.isPlaying = false,
    this.status,
    this.onCheck,
    this.onPlay,
    this.onTogglePlayPause,
    this.mediaPlaying = false,
  });

  final String label;
  final String? meta;
  final bool selected;
  final bool isPlaying;
  final bool mediaPlaying;
  final PlayerSourceStatus? status;
  final VoidCallback? onCheck;
  final VoidCallback? onPlay;
  final VoidCallback? onTogglePlayPause;

  @override
  State<_FlatMenuRow> createState() => _FlatMenuRowState();
}

class _FlatMenuRowState extends State<_FlatMenuRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final failed = widget.status == PlayerSourceStatus.failed;
    final isUp = widget.status == PlayerSourceStatus.ready ||
        widget.status == PlayerSourceStatus.active;
    final canPlay = widget.onPlay != null && !widget.isPlaying && isUp;
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    // Up rows: idle ✓, hover/focus → play arrow (same trailing slot).
    final showPlayOnUp =
        canPlay && (_hovered || (tvFocus && _focused));

    VoidCallback? trailingTap;
    if (widget.isPlaying && widget.onTogglePlayPause != null) {
      trailingTap = widget.onTogglePlayPause;
    } else if (showPlayOnUp) {
      trailingTap = widget.onPlay;
    } else if (canPlay) {
      // Green ✓ — tap to start this stream.
      trailingTap = widget.onPlay;
    }

    final trailingGlyph = showPlayOnUp
        ? Icon(
            Icons.play_arrow_rounded,
            size: 22,
            color: playerSourceStatusColor(PlayerSourceStatus.ready),
          )
        : PlayerStreamMenu._streamTrailingGlyph(
            status: widget.status,
            isPlaying: widget.isPlaying,
            mediaPlaying: widget.mediaPlaying,
          );

    final row = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: widget.selected && !widget.isPlaying
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.transparent,
        child: InkWell(
          onTap: tvFocus ? null : widget.onCheck,
          hoverColor: ForjaShellColors.inkHover,
          splashColor: ForjaShellColors.inkSplash,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 9),
            child: Row(
              children: [
                if (widget.meta != null) ...[
                  SizedBox(
                    width: 34,
                    child: Text(
                      widget.meta!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ] else
                  const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: failed
                          ? Colors.white.withValues(alpha: 0.38)
                          : widget.isPlaying
                              ? Colors.white
                              : widget.selected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.82),
                      fontSize: 13,
                      fontWeight: widget.isPlaying || widget.selected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      decoration: failed ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.white38,
                    ),
                  ),
                ),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: trailingTap != null
                      ? Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: trailingTap,
                            borderRadius: BorderRadius.circular(4),
                            hoverColor: Colors.white.withValues(alpha: 0.08),
                            child: Center(child: trailingGlyph),
                          ),
                        )
                      : Center(child: trailingGlyph),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!tvFocus) return row;
    return shellFocusableTap(
      context: context,
      onTap: () {
        if (widget.isPlaying && widget.onTogglePlayPause != null) {
          widget.onTogglePlayPause!();
        } else if (canPlay && widget.onPlay != null) {
          widget.onPlay!();
        } else {
          widget.onCheck?.call();
        }
      },
      borderRadius: 8,
      showFocusBorder: true,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: row,
    );
  }
}
