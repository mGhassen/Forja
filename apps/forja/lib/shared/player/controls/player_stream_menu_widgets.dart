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
    // Play arrow only when status is up — not while unchecked, checking, or failed.
    final canPlay = widget.onPlay != null && !widget.isPlaying && isUp;
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final showPlayArrow = canPlay && (_hovered || (tvFocus && _focused));
    final showTransport = widget.onTogglePlayPause != null && widget.isPlaying;
    final activeColor = playerSourceStatusColor(PlayerSourceStatus.active);

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
                SizedBox(
                  width: PlayerStreamMenu._statusSlot,
                  child: Center(
                    child: PlayerStreamMenu._streamStatusGlyph(
                      status: widget.status,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
                  child: showTransport
                      ? Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onTogglePlayPause,
                            borderRadius: BorderRadius.circular(4),
                            hoverColor: Colors.white.withValues(alpha: 0.08),
                            child: Icon(
                              widget.mediaPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 22,
                              color: activeColor,
                            ),
                          ),
                        )
                      : showPlayArrow
                          ? Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: widget.onPlay,
                                borderRadius: BorderRadius.circular(4),
                                hoverColor:
                                    Colors.white.withValues(alpha: 0.08),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  size: 22,
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                            )
                          : null,
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
        if (canPlay && widget.onPlay != null) {
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
