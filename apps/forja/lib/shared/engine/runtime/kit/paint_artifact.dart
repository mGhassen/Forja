import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/open/catalog_open.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/event_card.dart';
import 'package:forja_foundation/widgets/catalog/interactive_poster_card.dart';
import 'package:forja_foundation/widgets/chrome/shell_section_title.dart';

/// Shared pack-item → foundation card paint. Single path for rails + slots.
abstract final class PackPaintArtifact {
  PackPaintArtifact._();

  static Map<String, dynamic> propsOf(Map<String, dynamic> item) {
    final paint = item['paint'];
    if (paint is Map) {
      final props = paint['props'];
      if (props is Map) return Map<String, dynamic>.from(props);
    }
    final props = item['props'];
    if (props is Map) return Map<String, dynamic>.from(props);
    return const {};
  }

  static VoidCallback? openTap(
    BuildContext context, {
    required String pluginId,
    required Map<String, dynamic> props,
    Object? open,
    Object? meta,
  }) {
    final openMap = open is Map ? Map<String, dynamic>.from(open) : null;
    final metaMap = meta is Map ? Map<String, dynamic>.from(meta) : null;
    if (openMap == null && metaMap == null) return null;
    return () {
      final item = metaMap != null
          ? MetaItem.fromJson(metaMap)
          : MetaItem(
              id: (openMap?['id'] ?? '').toString(),
              type: (openMap?['surface'] ?? '').toString(),
              name: (props['title'] ?? '').toString(),
              poster:
                  (props['imageUrl'] ?? props['posterUrl'] ?? '').toString(),
              background:
                  (props['backdropUrl'] ?? props['backgroundUrl'] ?? '')
                      .toString(),
              open: openMap != null ? MetaOpen.fromJson(openMap) : null,
            );
      if (item.id.isEmpty && item.open == null) return;
      openMetaItem(context, pluginId: pluginId, item: item);
    };
  }

  /// Mount a single `paint: { type, props }` artifact.
  static Widget fromPaint(
    BuildContext context, {
    required String pluginId,
    required Map<String, dynamic> paint,
    Object? open,
    Object? meta,
    int? listIndex,
    int? fallbackRank,
    String? fallbackAspect,
  }) {
    final type = (paint['type'] ?? '').toString().trim();
    final propsRaw = paint['props'];
    final props = propsRaw is Map
        ? Map<String, dynamic>.from(propsRaw)
        : <String, dynamic>{};
    final onTap = openTap(
      context,
      pluginId: pluginId,
      props: props,
      open: open ?? props['open'],
      meta: meta ?? props['meta'],
    );

    switch (type) {
      case 'posterCard':
      case 'poster':
        final rank = props['rank'] is num
            ? (props['rank'] as num).toInt()
            : fallbackRank;
        final aspectRaw =
            (props['aspect'] ?? fallbackAspect ?? '').toString();
        return InteractivePosterCard(
          imageUrl: (props['imageUrl'] ?? props['posterUrl'] ?? '').toString(),
          title: (props['title'] ?? '').toString(),
          subtitle: props['subtitle']?.toString(),
          rating: props['rating'] is num
              ? (props['rating'] as num).toDouble()
              : null,
          rank: rank,
          badge: props['badge']?.toString(),
          listIndex: listIndex,
          onTap: onTap ?? () {},
          aspect: aspectRaw == 'landscape'
              ? PosterAspect.landscape
              : PosterAspect.portrait,
        );
      case 'eventCard':
      case 'event':
        final w = (props['width'] is num)
            ? (props['width'] as num).toDouble()
            : 220.0;
        final h = (props['height'] is num)
            ? (props['height'] as num).toDouble()
            : 124.0;
        return EventCard(
          title: (props['title'] ?? '').toString(),
          posterUrl: (props['posterUrl'] ?? props['imageUrl'] ?? '').toString(),
          homeTeam: props['homeTeam']?.toString(),
          awayTeam: props['awayTeam']?.toString(),
          homeBadgeUrl: (props['homeBadgeUrl'] ?? '').toString(),
          awayBadgeUrl: (props['awayBadgeUrl'] ?? '').toString(),
          categoryLabel: (props['categoryLabel'] ?? '').toString(),
          scheduleLabel: (props['scheduleLabel'] ?? '').toString(),
          timeLabel: (props['timeLabel'] ?? '').toString(),
          viewers:
              props['viewers'] is num ? (props['viewers'] as num).toInt() : 0,
          live: props['live'] == true,
          width: w,
          height: h,
          onTap: onTap,
          tvDensity: ShellScope.inputPolicyOf(context).useFocusableMoodChips,
        );
      default:
        if (props.isEmpty) return const SizedBox.shrink();
        final label = (props['title'] ?? type).toString();
        if (label.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            label,
            style: TextStyle(color: ForjaShellColors.textSecondary),
          ),
        );
    }
  }

  /// Horizontal rail/ranked row from paint-ready `items[]`.
  static Widget posterRow(
    BuildContext context, {
    required Map<String, dynamic> node,
    required String pluginId,
  }) {
    final title = (node['title'] ?? node['label'] ?? '').toString();
    final ranked = (node['type'] ?? '').toString() == 'ranked' ||
        (node['style'] ?? '').toString() == 'numbered';
    final aspectFallback = (node['aspect'] ?? '').toString();
    final items = node['items'];
    if (items is! List || items.isEmpty) {
      if (title.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ShellTokens.homeSectionHorizontalPadding,
          vertical: 8,
        ),
        child: ShellSectionTitle(title: title),
      );
    }

    final cards = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final raw = items[i];
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final paint = item['paint'];
      if (paint is Map) {
        cards.add(
          fromPaint(
            context,
            pluginId: pluginId,
            paint: Map<String, dynamic>.from(paint),
            open: item['open'] ?? paint['open'],
            meta: item['meta'] ?? paint['meta'],
            listIndex: i,
            fallbackRank: ranked ? i + 1 : null,
            fallbackAspect: aspectFallback,
          ),
        );
        continue;
      }
      // No paint envelope — still mount posterCard from props map if present.
      cards.add(
        fromPaint(
          context,
          pluginId: pluginId,
          paint: {
            'type': 'posterCard',
            'props': propsOf(item),
          },
          open: item['open'],
          meta: item['meta'],
          listIndex: i,
          fallbackRank: ranked ? i + 1 : null,
          fallbackAspect: aspectFallback,
        ),
      );
    }
    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              ShellTokens.homeSectionHorizontalPadding,
              12,
              ShellTokens.homeSectionHorizontalPadding,
              8,
            ),
            child: ShellSectionTitle(title: title),
          ),
        SizedBox(
          height: InteractivePosterCard.cardHeight(context) + 28,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: ShellTokens.homeSectionHorizontalPadding,
            ),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => cards[i],
          ),
        ),
      ],
    );
  }
}
