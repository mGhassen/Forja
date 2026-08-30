import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/shell_card_play_overlay.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// Generic Continue Watching card — reads opaque [entry] maps only.
class CatalogContinueWatchingCard extends StatefulWidget {
  const CatalogContinueWatchingCard({
    super.key,
    required this.tabId,
    required this.entry,
    required this.onTap,
    required this.onRemove,
    required this.onInfo,
    required this.listIndex,
    this.isLoading = false,
  });

  final String tabId;
  final Map<String, dynamic> entry;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onInfo;
  final int listIndex;
  final bool isLoading;

  static double cardWidth(BuildContext context) =>
      shellContinueWatchingCardWidth(context);

  static double cardHeight(BuildContext context) =>
      shellContinueWatchingCardHeight(context);

  @override
  State<CatalogContinueWatchingCard> createState() =>
      _CatalogContinueWatchingCardState();
}

class _CatalogContinueWatchingCardState
    extends State<CatalogContinueWatchingCard> {
  bool _hovered = false;
  bool _focused = false;

  bool _activeFor(ShellInputPolicy policy) =>
      ShellInputPolicy.interactiveActive(
        policy,
        hovered: _hovered,
        focused: _focused,
        context: context,
      );

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final cover = (widget.entry['cover'] ?? widget.entry['poster'] ?? '')
        .toString();
    final title = (widget.entry['title'] ?? 'Title').toString();
    final ep = (widget.entry['episodeNumber'] as num?)?.toInt() ?? 1;
    final extras = widget.entry['extras'];
    final extraLabel = extras is Map
        ? (extras['category'] ?? extras['label'])?.toString()
        : null;
    final subtitle = extraLabel != null && extraLabel.isNotEmpty
        ? 'Ep $ep · ${extraLabel.toUpperCase()}'
        : 'Ep $ep';
    final position = (widget.entry['positionMs'] as num?)?.toInt() ?? 0;
    final duration = (widget.entry['durationMs'] as num?)?.toInt() ?? 0;
    final progress =
        duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;
    final remaining = duration > 0
        ? Duration(milliseconds: duration - position)
        : Duration.zero;
    final remainingText =
        remaining.inMinutes > 0 ? '${remaining.inMinutes}m left' : '';
    final cardWidth = CatalogContinueWatchingCard.cardWidth(context);
    final cardHeight = CatalogContinueWatchingCard.cardHeight(context);
    final radius = shellCardBorderRadius(context);

    return shellFocusableTap(
      context: context,
      onTap: widget.isLoading ? null : widget.onTap,
      listIndex: widget.listIndex,
      tvTabId: widget.tabId,
      tvRowId: 'continue-watching',
      tvItemIndex: widget.listIndex,
      borderRadius: radius,
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: (h) => setState(() => _hovered = h),
      child: AnimatedScale(
        scale: _activeFor(policy) ? ShellCardPlayOverlay.cardHoverScale : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: _activeFor(policy)
                  ? ForjaShellColors.chipSelectedBorder
                  : ForjaShellColors.cinematic.borderSubtle,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - 1.5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: AppTheme.bgDark,
                  child: cover.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          placeholder: (c, u) =>
                              ColoredBox(color: AppTheme.bgDark),
                        )
                      : const Icon(Icons.movie, color: Colors.white24, size: 40),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.85),
                        Colors.black.withValues(alpha: 0.95),
                      ],
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
                              ),
                            ),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                            if (remainingText.isNotEmpty)
                              Text(
                                remainingText,
                                style: TextStyle(
                                  color: ForjaShellColors.badgeLabel,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        color: ForjaShellColors.sectionAccent,
                        minHeight: 3,
                      ),
                    ],
                  ),
                ),
                if (widget.isLoading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.6),
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
