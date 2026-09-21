import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/continue_watching_card.dart';
import 'package:forja_foundation/widgets/catalog/poster_rail.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/chrome/shell_section_title.dart';
import 'package:forja_foundation/widgets/feedback/card_play_overlay.dart';

/// Continue-watching row — props only (RFC-106 Zone A).
///
/// Prefer [items] / [children] for generic posters, or [entries] for progress
/// cards ([ContinueWatchingCard]).
class ContinueSection extends StatelessWidget {
  const ContinueSection({
    super.key,
    required this.title,
    this.items,
    this.children,
    this.entries,
    this.rail,
    this.onSeeAll,
    this.showScrollArrows = false,
    this.scrollController,
    this.titlePadding,
    this.listPadding,
    this.cardWidth = ShellTokens.shellContinueWatchingCardWidthDesktop,
    this.cardHeight = ShellTokens.shellContinueWatchingCardHeightDesktop,
    this.cardGap = ShellTokens.posterCardRowGap,
    this.titleFontSize,
    this.cardTitleFontSize,
    this.cardSubtitleFontSize,
    this.cardRemainingFontSize,
    this.onResume,
    this.onRemove,
    this.onInfo,
    this.resumingMetaId,
  }) : assert(items != null || children != null || entries != null || rail != null);

  final String title;
  final List<PosterItem>? items;
  final List<Widget>? children;
  final List<ContinueEntry>? entries;
  /// Full rail (host cards with focus). Wins over [items]/[children]/[entries].
  final Widget? rail;
  final VoidCallback? onSeeAll;
  final bool showScrollArrows;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? listPadding;
  final double cardWidth;
  final double cardHeight;
  final double cardGap;
  final double? titleFontSize;
  final double? cardTitleFontSize;
  final double? cardSubtitleFontSize;
  final double? cardRemainingFontSize;
  final void Function(ContinueEntry entry)? onResume;
  final void Function(ContinueEntry entry)? onRemove;
  final void Function(ContinueEntry entry)? onInfo;
  final String? resumingMetaId;

  @override
  Widget build(BuildContext context) {
    if (rail != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShellSectionTitle(
            title: title,
            padding: titlePadding ?? ShellSectionTitle.defaultPadding(context),
            fontSize: titleFontSize,
            trailing: _trailingList(context),
          ),
          rail!,
        ],
      );
    }

    final entryList = entries;
    if (entryList != null) {
      if (entryList.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShellSectionTitle(
            title: title,
            padding: titlePadding ?? ShellSectionTitle.defaultPadding(context),
            fontSize: titleFontSize,
            trailing: _trailingList(context),
          ),
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.none,
              padding: listPadding ??
                  EdgeInsets.symmetric(
                    horizontal: ShellPaintScope.usesTvDensityOf(context)
                        ? ShellTokens.tvHomeSectionHorizontalPadding
                        : ShellTokens.homeSectionHorizontalPadding,
                  ),
              itemCount: entryList.length,
              separatorBuilder: (_, _) => SizedBox(width: cardGap),
              itemBuilder: (_, i) {
                final entry = entryList[i];
                return _ContinueHoverCard(
                  entry: entry,
                  width: cardWidth,
                  height: cardHeight,
                  isLoading: resumingMetaId != null &&
                      entry.metaId == resumingMetaId,
                  listIndex: i,
                  titleFontSize: cardTitleFontSize,
                  subtitleFontSize: cardSubtitleFontSize,
                  remainingFontSize: cardRemainingFontSize,
                  onResume: onResume,
                  onRemove: onRemove,
                  onInfo: onInfo,
                );
              },
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShellSectionTitle(
          title: title,
          padding: titlePadding ?? ShellSectionTitle.defaultPadding(context),
          fontSize: titleFontSize,
          trailing: _trailingList(context),
        ),
        PosterRail(
          items: children == null ? items : null,
          itemWidth: cardWidth,
          itemHeight: cardHeight,
          height: cardHeight,
          padding: listPadding,
          children: children,
        ),
      ],
    );
  }

  List<Widget>? _trailingList(BuildContext context) {
    if (onSeeAll != null) {
      final seeAllFontSize = ShellPaintScope.usesTvDensityOf(context)
          ? ShellTokens.tvBodyFontSize
          : 13.0;
      return [
        GestureDetector(
          onTap: onSeeAll,
          child: Text(
            'See all',
            style: TextStyle(
              color: ForjaShellColors.textSecondary,
              fontSize: seeAllFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ];
    }
    if (!showScrollArrows || scrollController == null) return null;
    return [
      _Arrow(
        icon: Icons.arrow_back_ios_new_rounded,
        delta: -400,
        controller: scrollController!,
      ),
      const SizedBox(width: 6),
      _Arrow(
        icon: Icons.arrow_forward_ios_rounded,
        delta: 400,
        controller: scrollController!,
      ),
    ];
  }
}

class _ContinueHoverCard extends StatefulWidget {
  const _ContinueHoverCard({
    required this.entry,
    required this.width,
    required this.height,
    required this.isLoading,
    this.listIndex,
    this.titleFontSize,
    this.subtitleFontSize,
    this.remainingFontSize,
    this.onResume,
    this.onRemove,
    this.onInfo,
  });

  final ContinueEntry entry;
  final double width;
  final double height;
  final bool isLoading;
  final int? listIndex;
  final double? titleFontSize;
  final double? subtitleFontSize;
  final double? remainingFontSize;
  final void Function(ContinueEntry entry)? onResume;
  final void Function(ContinueEntry entry)? onRemove;
  final void Function(ContinueEntry entry)? onInfo;

  @override
  State<_ContinueHoverCard> createState() => _ContinueHoverCardState();
}

class _ContinueHoverCardState extends State<_ContinueHoverCard> {
  final ValueNotifier<bool> _activeN = ValueNotifier(false);

  @override
  void dispose() {
    _activeN.dispose();
    super.dispose();
  }

  void _setActive(bool active) {
    if (_activeN.value == active) return;
    _activeN.value = active;
  }

  Widget _buildCard(bool active) {
    final entry = widget.entry;
    return ContinueWatchingCard(
      title: entry.title,
      coverUrl: entry.coverUrl,
      subtitle: entry.subtitle,
      progress: entry.progress,
      remainingText: entry.remainingText,
      width: widget.width,
      height: widget.height,
      isLoading: widget.isLoading,
      active: active,
      titleFontSize: widget.titleFontSize,
      subtitleFontSize: widget.subtitleFontSize,
      remainingFontSize: widget.remainingFontSize,
      onTap: widget.onResume == null ? null : () => widget.onResume!(entry),
      onRemove:
          widget.onRemove == null ? null : () => widget.onRemove!(entry),
      onInfo: widget.onInfo == null ? null : () => widget.onInfo!(entry),
      playOverlay: ShellCardPlayOverlay(
        active: false,
        visible: active && !widget.isLoading,
        onTap:
            widget.onResume == null ? null : () => widget.onResume!(entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final painted = ListenableBuilder(
      listenable: _activeN,
      builder: (context, _) => _buildCard(_activeN.value),
    );
    if (widget.listIndex != null &&
        ShellPaintScope.useTvFocusOf(context) &&
        ShellPaintTvRowScope.maybeOf(context) != null) {
      return ShellPaintScope.focusableTap(
        context: context,
        onTap: widget.onResume == null
            ? null
            : () => widget.onResume!(widget.entry),
        borderRadius: 12,
        motion: ForjaMotionPreset.fillOnly,
        listIndex: widget.listIndex,
        tvItemIndex: widget.listIndex,
        tvZone: ShellPaintTvZone.row,
        onFocusChange: _setActive,
        onHoverChange: _setActive,
        child: painted,
      );
    }
    return MouseRegion(
      onEnter: (_) => _setActive(true),
      onExit: (_) => _setActive(false),
      child: Focus(
        onFocusChange: (f) => _setActive(f),
        child: painted,
      ),
    );
  }
}

/// Opaque continue-watching entry for [ContinueSection] / [ContinueWatchingCard].
class ContinueEntry {
  const ContinueEntry({
    required this.metaId,
    required this.title,
    required this.coverUrl,
    this.subtitle = '',
    this.progress = 0,
    this.remainingText = '',
  });

  final String metaId;
  final String title;
  final String coverUrl;
  final String subtitle;
  final double progress;
  final String remainingText;

  factory ContinueEntry.fromMap(Map<String, dynamic> entry) {
    final cover = (entry['cover'] ?? entry['poster'] ?? '').toString();
    final title = (entry['title'] ?? 'Title').toString();
    final ep = (entry['episodeNumber'] as num?)?.toInt() ?? 1;
    final extras = entry['extras'];
    final extraLabel = extras is Map
        ? (extras['category'] ?? extras['label'])?.toString()
        : null;
    final subtitle = extraLabel != null && extraLabel.isNotEmpty
        ? 'Ep $ep · ${extraLabel.toUpperCase()}'
        : 'Ep $ep';
    final position = (entry['positionMs'] as num?)?.toInt() ?? 0;
    final duration = (entry['durationMs'] as num?)?.toInt() ?? 0;
    final progress =
        duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;
    final remaining = duration > 0
        ? Duration(milliseconds: duration - position)
        : Duration.zero;
    final remainingText =
        remaining.inMinutes > 0 ? '${remaining.inMinutes}m left' : '';
    return ContinueEntry(
      metaId: (entry['metaId'] ?? '').toString(),
      title: title,
      coverUrl: cover,
      subtitle: subtitle,
      progress: progress,
      remainingText: remainingText,
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.icon,
    required this.delta,
    required this.controller,
  });

  final IconData icon;
  final double delta;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!controller.hasClients) return;
        controller.animateTo(
          (controller.offset + delta)
              .clamp(0.0, controller.position.maxScrollExtent),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 14),
      ),
    );
  }
}
