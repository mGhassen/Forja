import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/catalog/continue_watching_card.dart';
import 'package:forja_foundation/widgets/catalog/poster_rail.dart';
import 'package:forja_foundation/widgets/chrome/shell_section_title.dart';
import 'package:forja_foundation/widgets/feedback/card_play_overlay.dart';

/// Continue-watching row — props only (RFC-106 Zone A).
///
/// Prefer [items] / [children] for generic posters, or [entries] for progress
/// cards ([ContinueWatchingCard]).
class ContinueSection extends StatelessWidget {
  const ContinueSection({
    super.key,
    this.title = 'Continue Watching',
    this.items,
    this.children,
    this.entries,
    this.rail,
    this.onSeeAll,
    this.showScrollArrows = false,
    this.scrollController,
    this.titlePadding,
    this.listPadding,
    this.cardWidth = 280,
    this.cardHeight = 158,
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
                  const EdgeInsets.symmetric(horizontal: 24),
              itemCount: entryList.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                final entry = entryList[i];
                return _ContinueHoverCard(
                  entry: entry,
                  width: cardWidth,
                  height: cardHeight,
                  isLoading: resumingMetaId != null &&
                      entry.metaId == resumingMetaId,
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
          trailing: _trailingList(context),
        ),
        PosterRail(
          items: children == null ? items : null,
          children: children,
          itemWidth: cardWidth,
          itemHeight: cardHeight,
          height: cardHeight,
          padding: listPadding,
        ),
      ],
    );
  }

  List<Widget>? _trailingList(BuildContext context) {
    if (onSeeAll != null) {
      return [
        GestureDetector(
          onTap: onSeeAll,
          child: Text(
            'See all',
            style: TextStyle(
              color: ForjaShellColors.textSecondary,
              fontSize: 13,
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
    this.onResume,
    this.onRemove,
    this.onInfo,
  });

  final ContinueEntry entry;
  final double width;
  final double height;
  final bool isLoading;
  final void Function(ContinueEntry entry)? onResume;
  final void Function(ContinueEntry entry)? onRemove;
  final void Function(ContinueEntry entry)? onInfo;

  @override
  State<_ContinueHoverCard> createState() => _ContinueHoverCardState();
}

class _ContinueHoverCardState extends State<_ContinueHoverCard> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return MouseRegion(
      onEnter: (_) => setState(() => _active = true),
      onExit: (_) => setState(() => _active = false),
      child: Focus(
        onFocusChange: (f) => setState(() => _active = f),
        child: ContinueWatchingCard(
          title: entry.title,
          coverUrl: entry.coverUrl,
          subtitle: entry.subtitle,
          progress: entry.progress,
          remainingText: entry.remainingText,
          width: widget.width,
          height: widget.height,
          isLoading: widget.isLoading,
          active: _active,
          onTap: widget.onResume == null ? null : () => widget.onResume!(entry),
          onRemove:
              widget.onRemove == null ? null : () => widget.onRemove!(entry),
          onInfo: widget.onInfo == null ? null : () => widget.onInfo!(entry),
          playOverlay: ShellCardPlayOverlay(
            active: false,
            visible: _active && !widget.isLoading,
            onTap:
                widget.onResume == null ? null : () => widget.onResume!(entry),
          ),
        ),
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
