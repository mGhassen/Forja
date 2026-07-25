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
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Server row: tap loads (empty) or expands/collapses (loaded). Reload icon
/// appears beside the name on hover (or TV focus).
class _ServerMenuHeader extends StatefulWidget {
  const _ServerMenuHeader({
    required this.label,
    required this.status,
    required this.isLoaded,
    required this.isPlaying,
    required this.isReloading,
    required this.showReload,
    required this.scoreScope,
    required this.providerId,
    this.subtitle,
    this.categoryBadge,
    this.hideCategoryBadge = false,
    this.onTap,
    this.onReload,
  });

  final String label;
  final String? subtitle;
  final PlayerSourceStatus status;
  final bool isLoaded;
  final bool isPlaying;
  final bool isReloading;
  final bool showReload;
  final String? categoryBadge;
  final ProviderScoreScope? scoreScope;
  final String providerId;
  final bool hideCategoryBadge;
  final VoidCallback? onTap;
  final VoidCallback? onReload;

  @override
  State<_ServerMenuHeader> createState() => _ServerMenuHeaderState();
}

class _ServerMenuHeaderState extends State<_ServerMenuHeader> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final showReloadGlyph =
        widget.showReload && (tvFocus ? _focused || _hovered : _hovered);
    final playingColor = PlayerPopupTokens.accent;

    final row = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // Outer FocusableControl owns TV focus - InkWell must not.
          canRequestFocus: false,
          onTap: tvFocus ? null : widget.onTap,
          hoverColor: ForjaShellColors.inkHover,
          splashColor: ForjaShellColors.inkSplash,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 5, 4, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                PlayerStreamMenu._statusGlyph(
                  status: widget.status,
                  isLoaded: widget.isLoaded,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: widget.isPlaying
                                    ? Colors.white
                                    : widget.status == PlayerSourceStatus.failed
                                        ? Colors.white.withValues(alpha: 0.42)
                                        : widget.isLoaded
                                            ? Colors.white
                                                .withValues(alpha: 0.92)
                                            : Colors.white
                                                .withValues(alpha: 0.62),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                                decoration:
                                    widget.status == PlayerSourceStatus.failed
                                        ? TextDecoration.lineThrough
                                        : null,
                                decorationColor: Colors.white38,
                              ),
                            ),
                          ),
                          if (widget.showReload) ...[
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: showReloadGlyph
                                  ? Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        canRequestFocus: false,
                                        onTap: widget.isReloading
                                            ? null
                                            : widget.onReload,
                                        borderRadius: BorderRadius.circular(4),
                                        hoverColor: Colors.white
                                            .withValues(alpha: 0.08),
                                        child: Center(
                                          child: Icon(
                                            Icons.refresh_rounded,
                                            size: 16,
                                            color: Colors.white.withValues(
                                              alpha: widget.isReloading
                                                  ? 0.28
                                                  : 0.55,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                      if (widget.subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            widget.subtitle!,
                            style: TextStyle(
                              color: widget.isPlaying
                                  ? playingColor
                                  : Colors.white.withValues(alpha: 0.42),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                PlayerStreamMenu._serverTrailingBadges(
                  categoryBadge: widget.categoryBadge,
                  scoreScope: widget.scoreScope,
                  providerId: widget.providerId,
                  hideCategoryBadge: widget.hideCategoryBadge,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!tvFocus || widget.onTap == null) return row;
    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 8,
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: row,
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
      // Green ✓ - tap to start this stream.
      trailingTap = widget.onPlay;
    }

    final trailingGlyph = showPlayOnUp
        ? Icon(
            Icons.play_arrow_rounded,
            size: 22,
            color: PlayerPopupTokens.accent,
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
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          onTap: tvFocus ? null : widget.onCheck,
          hoverColor: ForjaShellColors.inkHover,
          splashColor: ForjaShellColors.inkSplash,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
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
                            canRequestFocus: false,
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
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: row,
    );
  }
}
