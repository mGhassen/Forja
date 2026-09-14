import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/paint_artifact.dart';
import 'package:forja/shell/core/forja_shell_layout.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';

/// Hub `kit.list` — paint-ready `items[]` in a scrollable grid/list (expand-safe).
///
/// Never mounts a tall [Column] inside [Expanded] — that overflows millions of px.
class PackListSlot extends StatelessWidget {
  const PackListSlot({
    super.key,
    required this.spec,
    required this.pluginId,
  });

  final Map<String, dynamic> spec;
  final String pluginId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Parent not laid out yet / unbounded expand miss → skip hit targets.
        if (!constraints.hasBoundedWidth ||
            !constraints.hasBoundedHeight ||
            constraints.maxWidth < 1 ||
            constraints.maxHeight < 1) {
          return const SizedBox.shrink();
        }

        final raw = spec['items'];
        if (raw is! List || raw.isEmpty) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: const Center(
              child: Text(
                'Nothing here yet.',
                style: TextStyle(color: ForjaShellColors.textSecondary),
              ),
            ),
          );
        }

        final items = <Map<String, dynamic>>[
          for (final e in raw)
            if (e is Map) Map<String, dynamic>.from(e),
        ];
        final kindMenu = (spec['kindMenu'] ?? '').toString().trim();
        final kindFilter = kindMenu.isEmpty
            ? (spec['kind'] ?? '').toString().trim()
            : (LayoutScope.maybeOf(context)?.selectedId(kindMenu) ?? '').trim();
        final filtered = kindFilter.isEmpty
            ? items
            : [
                for (final e in items)
                  if (_itemKind(e) == kindFilter) e,
              ];
        if (filtered.isEmpty) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: const Center(
              child: Text(
                'Nothing here yet.',
                style: TextStyle(color: ForjaShellColors.textSecondary),
              ),
            ),
          );
        }

        var style = (spec['style'] ?? 'grid').toString().trim().toLowerCase();
        if (style == 'epg' || style == 'guide') style = 'timeline';
        final pad = shellHomeSectionHorizontalPadding(context);
        final body = style == 'list' || style == 'timeline'
            ? _list(context, filtered, pad, constraints.maxWidth)
            : _grid(
                context,
                filtered,
                pad,
                constraints.maxWidth,
                cards: style == 'cards',
              );

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: body,
        );
      },
    );
  }

  String _itemKind(Map<String, dynamic> item) {
    final props = PackPaintArtifact.propsOf(item);
    final fromProps = (props['kind'] ?? '').toString().trim();
    if (fromProps.isNotEmpty) return fromProps;
    final direct = (item['kind'] ?? item['type'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    final meta = item['meta'];
    if (meta is Map) {
      return (meta['type'] ?? meta['kind'] ?? '').toString().trim();
    }
    return '';
  }

  Widget _list(
    BuildContext context,
    List<Map<String, dynamic>> items,
    double pad,
    double maxWidth,
  ) {
    final tileW = (maxWidth - pad * 2).clamp(120.0, maxWidth);
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _tile(
        context,
        items[i],
        i,
        width: tileW,
        height: 124,
      ),
    );
  }

  Widget _grid(
    BuildContext context,
    List<Map<String, dynamic>> items,
    double pad,
    double maxW, {
    required bool cards,
  }) {
    final extent = cards ? 240.0 : 190.0;
    final cols = (maxW / (extent + 12)).floor().clamp(2, 8);
    final gap = 12.0;
    final cardW = ((maxW - pad * 2 - gap * (cols - 1)) / cols).clamp(80.0, 400.0);
    final cardH = cards ? cardW * 0.62 : cardW * 1.5;

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: gap,
        mainAxisSpacing: gap,
        childAspectRatio: cardW / (cardH + 28),
      ),
      itemCount: items.length,
      itemBuilder: (context, i) =>
          _tile(context, items[i], i, width: cardW, height: cardH),
    );
  }

  Widget _tile(
    BuildContext context,
    Map<String, dynamic> item,
    int index, {
    double? width,
    double? height,
  }) {
    final paint = item['paint'];
    if (paint is Map) {
      final map = Map<String, dynamic>.from(paint);
      final props = map['props'];
      if (props is Map && (width != null || height != null)) {
        final p = Map<String, dynamic>.from(props);
        if (width != null) p['width'] = width;
        if (height != null) p['height'] = height;
        map['props'] = p;
      }
      return PackPaintArtifact.fromPaint(
        context,
        pluginId: pluginId,
        paint: map,
        open: item['open'] ?? paint['open'],
        meta: item['meta'] ?? paint['meta'],
        listIndex: index,
      );
    }
    return PackPaintArtifact.fromPaint(
      context,
      pluginId: pluginId,
      paint: {
        'type': 'posterCard',
        'props': {
          ...PackPaintArtifact.propsOf(item),
          if (width != null) 'width': width,
          if (height != null) 'height': height,
        },
      },
      open: item['open'],
      meta: item['meta'],
      listIndex: index,
    );
  }
}
