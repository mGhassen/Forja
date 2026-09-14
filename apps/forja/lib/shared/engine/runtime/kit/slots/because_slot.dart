import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/pack_load_paint.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/runtime/kit/paint_artifact.dart';
import 'package:forja/shared/engine/store/watch_history.dart';
import 'package:forja/shell/core/forja_shell_layout.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/catalog/because_section.dart';
import 'package:forja_foundation/widgets/catalog/poster_rail.dart';

/// Hub `because` slot — resume seeds + optional shuffle into pack load.
class PackBecauseSlot extends StatefulWidget {
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
  State<PackBecauseSlot> createState() => _PackBecauseSlotState();
}

class _PackBecauseSlotState extends State<PackBecauseSlot> {
  int _shuffleKey = 0;
  bool _shuffleHovered = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: WatchHistory.revision,
      builder: (context, _, _) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: catalogResumeSeeds(widget.pluginId),
          builder: (context, snap) {
            final seeds = snap.data ?? const [];
            if (seeds.isEmpty) return const SizedBox.shrink();
            final load = packLoadSpec(widget.spec['load']);
            if (load == null) return const SizedBox.shrink();
            return PackLoadedPaint(
              key: ValueKey('because-$_shuffleKey'),
              pluginId: widget.pluginId,
              packSourceUrl: widget.packSourceUrl,
              tabId: widget.tabId,
              action: load.action,
              params: {
                ...load.params,
                'resumeSeeds': seeds,
                'shuffleKey': _shuffleKey,
              },
              fallbackSpec: widget.spec,
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
        pluginId: widget.pluginId,
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
    final canShuffle = node['canShuffle'] == true;
    final pad = shellHomeSectionHorizontalPadding(context);
    final showHover = ShellScope.inputPolicyOf(context).scaleOnHover;

    Widget? shuffle;
    if (canShuffle) {
      final active = _shuffleHovered;
      shuffle = MouseRegion(
        onEnter: showHover ? (_) => setState(() => _shuffleHovered = true) : null,
        onExit: showHover ? (_) => setState(() => _shuffleHovered = false) : null,
        child: GestureDetector(
          onTap: () => setState(() => _shuffleKey++),
          child: AnimatedScale(
            scale: active ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: SizedBox(
              width: 36,
              height: 36,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.transparent,
                ),
                child: Icon(
                  Icons.shuffle_rounded,
                  size: 24,
                  color: active ? Colors.white : ForjaShellColors.iconMuted,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return BecauseSection(
      title: heading.isEmpty ? null : heading,
      seedPosterUrl: seedPoster.isEmpty ? null : seedPoster,
      items: posterItems,
      trailing: shuffle,
      titlePadding: EdgeInsets.fromLTRB(
        pad,
        shellHomeSectionTitleTop(context),
        pad,
        shellHomeSectionBottomGap(context),
      ),
    );
  }
}
