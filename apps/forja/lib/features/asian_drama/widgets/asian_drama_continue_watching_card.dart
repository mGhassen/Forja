// Asian Drama continue-watching card - extracted from asian_drama_screen.dart.

import 'package:forja/features/asian_drama/widgets/asian_drama_widget_imports.dart';

class AsianDramaContinueWatchingCard extends StatefulWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onInfo;
  final int listIndex;
  final bool isLoading;

  const AsianDramaContinueWatchingCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onRemove,
    required this.onInfo,
    required this.listIndex,
    this.isLoading = false,
  });

  static double cardWidth(BuildContext context) =>
      shellContinueWatchingCardWidth(context);

  static double cardHeight(BuildContext context) =>
      shellContinueWatchingCardHeight(context);

  @override
  State<AsianDramaContinueWatchingCard> createState() =>
      _AsianDramaContinueWatchingCardState();
}

class _AsianDramaContinueWatchingCardState
    extends State<AsianDramaContinueWatchingCard> {
  bool _hovered = false;
  bool _focused = false;

  bool _activeFor(ShellInputPolicy policy) =>
      ShellInputPolicy.interactiveActive(
        policy,
        hovered: _hovered,
        focused: _focused,
      );

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final cover = widget.entry['cover'] as String?;
    final title = widget.entry['title'] as String? ?? '';
    final epNum = (widget.entry['episodeNumber'] as num?)?.toDouble() ?? 1.0;
    final totalEps = (widget.entry['totalEpisodes'] as num?)?.toInt() ?? 0;
    final position = (widget.entry['positionMs'] as num?)?.toInt() ?? 0;
    final duration = (widget.entry['durationMs'] as num?)?.toInt() ?? 0;
    final progress =
        duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;
    final remaining = duration > 0
        ? Duration(milliseconds: duration - position)
        : Duration.zero;
    final remainingText =
        remaining.inMinutes > 0 ? '${remaining.inMinutes}m left' : '';
    final epLabel = epNum == epNum.truncateToDouble()
        ? epNum.toInt().toString()
        : epNum.toString();
    final subtitle =
        totalEps > 0 ? 'Ep $epLabel / $totalEps' : 'Ep $epLabel';
    final cardWidth = AsianDramaContinueWatchingCard.cardWidth(context);
    final cardHeight = AsianDramaContinueWatchingCard.cardHeight(context);

    return shellFocusableTap(
      context: context,
      onTap: widget.isLoading ? null : widget.onTap,
      listIndex: widget.listIndex,
      tvTabId: 'asian_drama',
      tvRowId: 'continue-watching',
      tvItemIndex: widget.listIndex,
      borderRadius: 14,
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: AnimatedScale(
        scale: _activeFor(policy) ? ShellCardPlayOverlay.cardHoverScale : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: AppTheme.bgDark,
                  child: cover != null && cover.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          placeholder: (c, u) =>
                              ColoredBox(color: AppTheme.bgDark),
                        )
                      : const Icon(
                          Icons.movie,
                          color: Colors.white24,
                          size: 40,
                        ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.85),
                        Colors.black.withValues(alpha: 0.95),
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: ExcludeFocus(
                    excluding: !policy.scaleOnHover,
                    child: Column(
                      children: [
                        ForjaCloseButton(
                          size: 14,
                          hitSize: 28,
                          color: Colors.white70,
                          onTap: widget.onRemove,
                        ),
                        const SizedBox(height: 4),
                        Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            hoverColor: ForjaShellColors.inkHover,
                            splashColor: ForjaShellColors.inkSplash,
                            highlightColor: ForjaShellColors.inkSplash,
                            onTap: widget.onInfo,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.info_outline_rounded,
                                color: Colors.white70,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                height: 1.2,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (remainingText.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  remainingText,
                                  style: TextStyle(
                                    color: ForjaShellColors.badgeLabel,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(14),
                        ),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.1),
                          color: ForjaShellColors.sectionAccent,
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ),
                ),
                ShellCardPlayOverlay(
                  active: _activeFor(policy),
                  visible: _activeFor(policy) && !widget.isLoading,
                ),
                if (widget.isLoading)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: ForjaShellColors.sectionAccent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
