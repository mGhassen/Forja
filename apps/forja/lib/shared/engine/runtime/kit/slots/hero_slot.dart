import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/pack_load_paint.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/runtime/kit/paint_artifact.dart';
import 'package:forja/shared/engine/store/list_follow.dart';
import 'package:forja/shared/engine/runtime/details/hero_pill_buttons.dart';
import 'package:forja/shared/engine/runtime/details/kit_details_play_row.dart';
import 'package:forja/shared/engine/runtime/details/kit_list_status_hero.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/desktop/desktop_selectable_title.dart';
import 'package:forja/shell/tv/media_details_tv_scope.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/cinematic_hero.dart';

/// Hub `hero` — [CinematicHero] + host action row (View details + list pin).
///
/// Optional [pageBottomChild] is the bleed rail (Featured under spotlight).
class PackHeroSlot extends StatelessWidget {
  const PackHeroSlot({
    super.key,
    required this.spec,
    required this.pluginId,
    this.packSourceUrl,
    this.tabId,
    this.pageBottomChild,
    this.bleedRowId,
  });

  final Map<String, dynamic> spec;
  final String pluginId;
  final String? packSourceUrl;
  final String? tabId;
  final Widget? pageBottomChild;
  final String? bleedRowId;

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
    final listById = <String, ListFollowTarget>{};
    for (final raw in items) {
      if (raw is! Map) continue;
      if (slides.length >= 5) break;
      final item = Map<String, dynamic>.from(raw);
      final slide = _slideFromItem(context, item);
      if (slide == null) continue;
      slides.add(slide);
      final target = _listTarget(item);
      if (target != null) listById[slide.id] = target;
    }
    if (slides.isEmpty) return const SizedBox.shrink();

    final compact = MediaQuery.sizeOf(context).width <
        ShellTokens.heroDesktopMinBodyWidth;
    final layout = _layoutOf(context, compact: compact);

    return _HeroHost(
      slides: slides,
      layout: layout,
      pluginId: pluginId,
      tabId: tabId,
      pageBottomChild: pageBottomChild,
      bleedRowId: bleedRowId,
      listById: listById,
    );
  }

  CinematicHeroLayout _layoutOf(
    BuildContext context, {
    required bool compact,
  }) {
    final metrics = ShellScope.metricsOf(context);
    final policy = ShellScope.inputPolicyOf(context);
    return CinematicHeroLayout(
      compact: compact,
      tvDensity: metrics.usesTvDensity,
      kenBurns: policy.kenBurnsBackdrop,
      plainTitle: policy.useFocusableMoodChips,
      selectableTitle: shellDesktopTextSelect(context),
      heroMinTitleHeight: metrics.heroMinTitleHeight,
      heroActionUseFittedBox: metrics.heroActionUseFittedBox,
      heroCompactRightInset: metrics.heroCompactRightInset,
      sectionHorizontalPadding: ShellTokens.homeSectionHorizontalPadding,
    );
  }

  CinematicHeroSlide? _slideFromItem(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    final props = PackPaintArtifact.propsOf(item);
    final meta = item['meta'] is Map
        ? MetaItem.fromJson(Map<String, dynamic>.from(item['meta'] as Map))
        : null;
    final open = item['open'] is Map
        ? MetaOpen.fromJson(Map<String, dynamic>.from(item['open'] as Map))
        : meta?.open;

    final title = (props['title'] ?? meta?.name ?? '').toString().trim();
    final backdrop = (props['backdropUrl'] ??
            props['backgroundUrl'] ??
            meta?.background ??
            '')
        .toString()
        .trim();
    final poster = (props['posterUrl'] ??
            props['imageUrl'] ??
            meta?.poster ??
            '')
        .toString()
        .trim();
    if (title.isEmpty && backdrop.isEmpty && poster.isEmpty) return null;

    final id = (open?.id ?? meta?.id ?? props['id'] ?? title).toString();
    final onDetails = PackPaintArtifact.openTap(
      context,
      pluginId: pluginId,
      props: {
        ...props,
        if (title.isNotEmpty) 'title': title,
        if (poster.isNotEmpty) 'posterUrl': poster,
        if (backdrop.isNotEmpty) 'backdropUrl': backdrop,
      },
      open: open?.toJson(),
      meta: meta?.toJson(),
    );

    final rating = props['rating'] ?? meta?.rating;
    final yearRaw = (props['year'] ?? meta?.releaseInfo ?? '').toString();
    final year = yearRaw.isEmpty ? null : yearRaw.split(' • ').first;
    final logo = (props['logoUrl'] ?? props['logo'] ?? meta?.logo ?? '')
        .toString()
        .trim();
    final overview =
        (props['overview'] ?? props['description'] ?? meta?.description ?? '')
            .toString();
    final genres = props['genres'] is List
        ? [
            for (final g in props['genres'] as List)
              if (g != null && g.toString().trim().isNotEmpty) g.toString(),
          ]
        : (meta?.genres ?? const <String>[]);

    return CinematicHeroSlide(
      id: id.isEmpty ? title : id,
      title: title.isEmpty ? 'Title' : title,
      backdropUrl: backdrop.isNotEmpty ? backdrop : poster,
      posterUrl: poster.isEmpty ? null : poster,
      logoUrl: logo,
      overview: overview,
      rating: rating is num ? rating.toDouble() : null,
      year: year,
      badge: (props['badge'] ?? meta?.badge)?.toString(),
      genres: genres,
      onDetails: onDetails,
    );
  }

  ListFollowTarget? _listTarget(Map<String, dynamic> item) {
    final meta = item['meta'] is Map
        ? MetaItem.fromJson(Map<String, dynamic>.from(item['meta'] as Map))
        : null;
    if (meta != null) {
      return ListFollowTarget.fromMeta(pluginId: pluginId, meta: meta);
    }
    final open = item['open'] is Map
        ? MetaOpen.fromJson(Map<String, dynamic>.from(item['open'] as Map))
        : null;
    if (open == null) return null;
    final props = PackPaintArtifact.propsOf(item);
    return ListFollowTarget(
      pluginId: pluginId,
      open: open,
      title: (props['title'] ?? '').toString(),
      posterPath: (props['posterUrl'] ?? props['imageUrl'] ?? '').toString(),
      voteAverage: props['rating'] is num ? (props['rating'] as num).toDouble() : 0,
      mediaType: open.surface,
      tmdbId: open.surface == 'tmdb' ? open.idInt : null,
      tmdbMediaType: open.surface == 'tmdb' ? null : null,
    );
  }
}

class _HeroHost extends StatefulWidget {
  const _HeroHost({
    required this.slides,
    required this.layout,
    required this.pluginId,
    required this.listById,
    this.tabId,
    this.pageBottomChild,
    this.bleedRowId,
  });

  final List<CinematicHeroSlide> slides;
  final CinematicHeroLayout layout;
  final String pluginId;
  final String? tabId;
  final Widget? pageBottomChild;
  final String? bleedRowId;
  final Map<String, ListFollowTarget> listById;

  @override
  State<_HeroHost> createState() => _HeroHostState();
}

class _HeroHostState extends State<_HeroHost> {
  final FocusNode _tvHeroPlayFocus = FocusNode(debugLabel: 'hero-play');
  final GlobalKey _heroKey = GlobalKey();

  @override
  void dispose() {
    _tvHeroPlayFocus.dispose();
    super.dispose();
  }

  void _reportHeight(double h) {
    final tab = widget.tabId?.trim();
    if (tab == null || tab.isEmpty) return;
    final n = ShellBus.hubHeroHeightFor(tab);
    if ((n.value - h).abs() > 0.5) n.value = h;
  }

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final metrics = ShellScope.metricsOf(context);
    final tvNav = policy.useFocusableMoodChips;
    final tabId = widget.tabId;

    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final box = _heroKey.currentContext?.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize) _reportHeight(box.size.height);
        });
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: KeyedSubtree(
          key: _heroKey,
          child: CinematicHero(
            slides: widget.slides,
            layout: widget.layout,
            pageBottomChild: widget.pageBottomChild,
            actionRowBuilder: (context, slide, {required isActive}) {
              if (!isActive) return const SizedBox.shrink();
              final listTarget = widget.listById[slide.id];
              final details = HeroPillPlayButton(
                label: 'View details',
                icon: Icons.info_outline_rounded,
                primary: false,
                alwaysShowLabel: true,
                focusNode: policy.heroPlayAutoFocus ? _tvHeroPlayFocus : null,
                tvTabId: tvNav ? tabId : null,
                tvRowId: tvNav ? MediaDetailsTv.heroRowId : null,
                tvItemIndex: tvNav ? 0 : null,
                onTap: slide.onDetails,
              );
              final listAction = listTarget == null
                  ? null
                  : KitListStatusHero(
                      target: listTarget,
                      tvTabId: tvNav ? tabId : null,
                      tvItemIndexStart: tvNav ? 1 : 0,
                      enabled: true,
                    );
              final row = HeroPillActionRow(
                children: [
                  details,
                  if (listAction != null) ...[
                    const SizedBox(width: 10),
                    listAction,
                  ],
                ],
              );
              final body = metrics.heroActionUseFittedBox
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: row,
                    )
                  : row;
              if (!tvNav || tabId == null || tabId.isEmpty) return body;
              return DetailsHeroTvActionScope(
                tabId: tabId,
                itemCount: listAction != null ? 2 : 1,
                child: body,
              );
            },
          ),
        ),
      ),
    );
  }
}
