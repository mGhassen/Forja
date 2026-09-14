import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/runtime/open/catalog_open.dart';
import 'package:forja/shared/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/protocol/layout_types.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/event_card.dart';
import 'package:forja_foundation/widgets/catalog/interactive_poster_card.dart';
import 'package:forja_foundation/widgets/chrome/layout_stack.dart';
import 'package:forja_foundation/widgets/chrome/shell_section_title.dart';

/// Recursive validate+paint: pack node → foundation widget from props maps.
///
/// Never invents product fields. Nodes may declare opaque [load]; results must
/// carry paint-ready `items[]` / `widgets[]` / `paint` props.
class PackPaintTree extends StatelessWidget {
  const PackPaintTree({
    super.key,
    required this.spec,
    required this.pluginId,
    this.packSourceUrl,
    this.tabId,
  });

  final Map<String, dynamic> spec;
  final String pluginId;
  final String? packSourceUrl;
  final String? tabId;

  @override
  Widget build(BuildContext context) {
    final load = packLoadSpec(spec['load']);
    if (load != null) {
      return _LoadedPaint(
        pluginId: pluginId,
        packSourceUrl: packSourceUrl,
        tabId: tabId,
        action: load.action,
        params: load.params,
        fallbackSpec: spec,
      );
    }
    return _paintNode(context, spec);
  }

  Widget _paintNode(BuildContext context, Map<String, dynamic> node) {
    final type = LayoutTypes.normalize(
      (node['type'] ?? '').toString(),
      node,
    );

    if (LayoutTypes.isStack(type) || type == LayoutTypes.stack) {
      return LayoutStack(
        spec: node,
        childBuilder: (child, _) => PackPaintTree(
          spec: child,
          pluginId: pluginId,
          packSourceUrl: packSourceUrl,
          tabId: tabId,
        ),
      );
    }

    final paint = node['paint'];
    if (paint is Map) {
      return _paintArtifact(
        context,
        Map<String, dynamic>.from(paint),
        open: node['open'] ?? paint['open'],
        meta: node['meta'] ?? paint['meta'],
      );
    }

    if (type == LayoutTypes.row || type == 'rail' || type == 'ranked') {
      return _paintRow(context, node);
    }

    final children = node['children'] ?? node['widgets'] ?? node['items'];
    if (children is List && children.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in children)
            if (c is Map)
              PackPaintTree(
                spec: Map<String, dynamic>.from(c),
                pluginId: pluginId,
                packSourceUrl: packSourceUrl,
                tabId: tabId,
              ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _paintRow(BuildContext context, Map<String, dynamic> node) {
    final title = (node['title'] ?? node['label'] ?? '').toString();
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
      final child = paint is Map
          ? _paintArtifact(
              context,
              Map<String, dynamic>.from(paint),
              open: item['open'] ?? paint['open'],
              meta: item['meta'] ?? paint['meta'],
              listIndex: i,
            )
          : _paintArtifact(
              context,
              {
                'type': 'posterCard',
                'props': item['props'] is Map
                    ? Map<String, dynamic>.from(item['props'] as Map)
                    : <String, dynamic>{},
              },
              open: item['open'],
              meta: item['meta'],
              listIndex: i,
            );
      cards.add(child);
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

  Widget _paintArtifact(
    BuildContext context,
    Map<String, dynamic> paint, {
    Object? open,
    Object? meta,
    int? listIndex,
  }) {
    final type = (paint['type'] ?? '').toString().trim();
    final propsRaw = paint['props'];
    final props = propsRaw is Map
        ? Map<String, dynamic>.from(propsRaw)
        : <String, dynamic>{};

    VoidCallback? onTap;
    final openMap = open is Map
        ? Map<String, dynamic>.from(open)
        : (props['open'] is Map
            ? Map<String, dynamic>.from(props['open'] as Map)
            : null);
    final metaMap = meta is Map
        ? Map<String, dynamic>.from(meta)
        : (props['meta'] is Map
            ? Map<String, dynamic>.from(props['meta'] as Map)
            : null);
    if (openMap != null || metaMap != null) {
      onTap = () {
        final item = metaMap != null
            ? MetaItem.fromJson(metaMap)
            : MetaItem(
                id: (openMap?['id'] ?? '').toString(),
                type: (openMap?['surface'] ?? '').toString(),
                name: (props['title'] ?? '').toString(),
                poster: (props['imageUrl'] ?? props['posterUrl'] ?? '')
                    .toString(),
                open: openMap != null ? MetaOpen.fromJson(openMap) : null,
              );
        if (item.id.isEmpty && item.open == null) return;
        openMetaItem(context, pluginId: pluginId, item: item);
      };
    }

    switch (type) {
      case 'posterCard':
      case 'poster':
        return InteractivePosterCard(
          imageUrl: (props['imageUrl'] ?? props['posterUrl'] ?? '').toString(),
          title: (props['title'] ?? '').toString(),
          subtitle: props['subtitle']?.toString(),
          rating: props['rating'] is num
              ? (props['rating'] as num).toDouble()
              : null,
          rank: props['rank'] is num ? (props['rank'] as num).toInt() : null,
          badge: props['badge']?.toString(),
          listIndex: listIndex,
          onTap: onTap ?? () {},
          aspect: (props['aspect'] ?? '').toString() == 'landscape'
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
          viewers: props['viewers'] is num ? (props['viewers'] as num).toInt() : 0,
          live: props['live'] == true,
          width: w,
          height: h,
          onTap: onTap,
          tvDensity: ShellScope.inputPolicyOf(context).useFocusableMoodChips,
        );
      default:
        if (props.isEmpty) return const SizedBox.shrink();
        // Unknown paint type with title — show muted label (schema miss).
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
}

class _LoadedPaint extends StatefulWidget {
  const _LoadedPaint({
    required this.pluginId,
    required this.action,
    required this.params,
    required this.fallbackSpec,
    this.packSourceUrl,
    this.tabId,
  });

  final String pluginId;
  final String? packSourceUrl;
  final String? tabId;
  final String action;
  final Map<String, dynamic> params;
  final Map<String, dynamic> fallbackSpec;

  @override
  State<_LoadedPaint> createState() => _LoadedPaintState();
}

class _LoadedPaintState extends State<_LoadedPaint> {
  late final Future<MetaEnvelope> _future = packOpaqueRun(
    pluginId: widget.pluginId,
    action: widget.action,
    params: widget.params,
    packSourceUrl: widget.packSourceUrl,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MetaEnvelope>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final env = snap.data;
        if (env == null || !env.ok || env.data == null) {
          return const SizedBox.shrink();
        }
        final data = env.data!;
        final merged = Map<String, dynamic>.from(widget.fallbackSpec);
        if (data['items'] is List) merged['items'] = data['items'];
        if (data['widgets'] is List) merged['widgets'] = data['widgets'];
        if (data['paint'] is Map) merged['paint'] = data['paint'];
        // Drop load so we paint the resolved tree (no reload loop).
        merged.remove('load');
        return PackPaintTree(
          spec: merged,
          pluginId: widget.pluginId,
          packSourceUrl: widget.packSourceUrl,
          tabId: widget.tabId,
        );
      },
    );
  }
}
