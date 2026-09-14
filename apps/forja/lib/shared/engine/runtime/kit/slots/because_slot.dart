import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/pack_load_paint.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/runtime/kit/paint_artifact.dart';
import 'package:forja/shared/engine/store/watch_history.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/because_section.dart';
import 'package:forja_foundation/widgets/catalog/poster_rail.dart';

/// Hub `because` slot — injects resume seeds into pack load → [BecauseSection].
class PackBecauseSlot extends StatelessWidget {
  const PackBecauseSlot({
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
    return ValueListenableBuilder<int>(
      valueListenable: WatchHistory.revision,
      builder: (context, _, _) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: catalogResumeSeeds(pluginId),
          builder: (context, snap) {
            final seeds = snap.data ?? const [];
            if (seeds.isEmpty) return const SizedBox.shrink();
            final load = packLoadSpec(spec['load']);
            if (load == null) return const SizedBox.shrink();
            return PackLoadedPaint(
              pluginId: pluginId,
              packSourceUrl: packSourceUrl,
              tabId: tabId,
              action: load.action,
              params: {
                ...load.params,
                'resumeSeeds': seeds,
              },
              fallbackSpec: spec,
              builder: _paint,
            );
          },
        );
      },
    );
  }

  Widget _paint(BuildContext context, Map<String, dynamic> node) {
    final items = node['items'];
    if (items is! List || items.isEmpty) return const SizedBox.shrink();

    final posterItems = <PosterItem>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final props = PackPaintArtifact.propsOf(item);
      final url =
          (props['imageUrl'] ?? props['posterUrl'] ?? '').toString().trim();
      final title = (props['title'] ?? '').toString();
      if (url.isEmpty && title.isEmpty) continue;
      final onTap = PackPaintArtifact.openTap(
        context,
        pluginId: pluginId,
        props: props,
        open: item['open'],
        meta: item['meta'],
      );
      posterItems.add(
        PosterItem(
          url: url,
          title: title.isEmpty ? null : title,
          onTap: onTap,
        ),
      );
    }
    if (posterItems.isEmpty) return const SizedBox.shrink();

    final heading = (node['heading'] ?? '').toString();
    final seedPoster = (node['seedPoster'] ?? '').toString();
    return BecauseSection(
      title: heading.isEmpty ? null : heading,
      seedPosterUrl: seedPoster.isEmpty ? null : seedPoster,
      items: posterItems,
      titlePadding: EdgeInsets.fromLTRB(
        ShellTokens.homeSectionHorizontalPadding,
        12,
        ShellTokens.homeSectionHorizontalPadding,
        8,
      ),
    );
  }
}
