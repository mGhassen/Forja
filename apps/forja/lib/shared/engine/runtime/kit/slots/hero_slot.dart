import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/pack_load_paint.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/runtime/kit/paint_artifact.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/cinematic_hero.dart';

/// Hub `hero` slot — pack `load` / `items` → [CinematicHero] slides from paint props.
class PackHeroSlot extends StatelessWidget {
  const PackHeroSlot({
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
      return PackLoadedPaint(
        pluginId: pluginId,
        packSourceUrl: packSourceUrl,
        tabId: tabId,
        action: load.action,
        params: load.params,
        fallbackSpec: spec,
        builder: _paint,
      );
    }
    return _paint(context, spec);
  }

  Widget _paint(BuildContext context, Map<String, dynamic> node) {
    final items = node['items'];
    if (items is! List || items.isEmpty) return const SizedBox.shrink();

    final slides = <CinematicHeroSlide>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final slide = _slideFromItem(
        context,
        Map<String, dynamic>.from(raw),
      );
      if (slide != null) slides.add(slide);
    }
    if (slides.isEmpty) return const SizedBox.shrink();

    final metrics = ShellScope.metricsOf(context);
    return CinematicHero(
      slides: slides,
      layout: CinematicHeroLayout(
        compact: MediaQuery.sizeOf(context).width <
            ShellTokens.heroDesktopMinBodyWidth,
        tvDensity: ShellScope.inputPolicyOf(context).useFocusableMoodChips,
        sectionHorizontalPadding: ShellTokens.homeSectionHorizontalPadding,
        heroMinTitleHeight: metrics.heroMinTitleHeight,
        heroActionUseFittedBox: metrics.heroActionUseFittedBox,
        heroCompactRightInset: metrics.heroCompactRightInset,
      ),
      actionRowBuilder: (context, slide, {required isActive}) {
        if (!isActive) return const SizedBox.shrink();
        return Button(
          variant: ButtonVariant.ghost,
          label: 'Play',
          icon: Icons.play_arrow_rounded,
          onPressed: slide.onDetails,
        );
      },
    );
  }

  CinematicHeroSlide? _slideFromItem(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    final props = PackPaintArtifact.propsOf(item);
    final title = (props['title'] ?? '').toString().trim();
    final backdrop = (props['backdropUrl'] ?? props['backgroundUrl'] ?? '')
        .toString()
        .trim();
    final poster =
        (props['posterUrl'] ?? props['imageUrl'] ?? '').toString().trim();
    if (title.isEmpty && backdrop.isEmpty && poster.isEmpty) return null;

    final open = item['open'] is Map
        ? Map<String, dynamic>.from(item['open'] as Map)
        : null;
    final meta = item['meta'] is Map
        ? Map<String, dynamic>.from(item['meta'] as Map)
        : null;
    final id = (open?['id'] ?? meta?['id'] ?? props['id'] ?? title).toString();
    final onDetails = PackPaintArtifact.openTap(
      context,
      pluginId: pluginId,
      props: {
        ...props,
        if (title.isNotEmpty) 'title': title,
        if (poster.isNotEmpty) 'posterUrl': poster,
        if (backdrop.isNotEmpty) 'backdropUrl': backdrop,
      },
      open: open,
      meta: meta,
    );

    final rating = props['rating'];
    return CinematicHeroSlide(
      id: id.isEmpty ? title : id,
      title: title.isEmpty ? 'Title' : title,
      backdropUrl: backdrop,
      posterUrl: poster.isEmpty ? null : poster,
      logoUrl: (props['logoUrl'] ?? props['logo'] ?? '').toString(),
      overview: (props['overview'] ?? props['description'] ?? '').toString(),
      rating: rating is num ? rating.toDouble() : null,
      year: props['year']?.toString(),
      badge: props['badge']?.toString(),
      genres: props['genres'] is List
          ? [
              for (final g in props['genres'] as List)
                if (g != null && g.toString().trim().isNotEmpty) g.toString(),
            ]
          : const [],
      onDetails: onDetails,
    );
  }
}
