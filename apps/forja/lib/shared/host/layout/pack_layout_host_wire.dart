/// PackLayoutHost MetaItem / Riverpod wire — residual composers after RFC-109 A28.
///
/// Paint twins live in `forja_foundation`. This file is host-only fetch/open wiring
/// colocated with PackLayoutHost (not a product folder).
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/runtime/open/catalog_open.dart';
import 'package:forja/shared/engine/runtime/nav/chrome_filters.dart';
import 'package:forja/shared/engine/runtime/nav/feed_chrome.dart';
import 'package:forja/shared/host/layout/list/host_list_registry.dart';
import 'package:forja/shared/host/layout/list/kit_list_paint.dart';
import 'package:forja/shared/host/layout/list/list_event_query.dart';
import 'package:forja/shared/host/layout/list/list_open_mode.dart';
import 'package:forja/shared/host/layout/list/list_source.dart';
import 'package:forja/shared/engine/runtime/open/meta_movie.dart';
import 'package:forja/shared/engine/runtime/nav/open_catalog_search.dart';
import 'package:forja/shared/engine/runtime/nav/pack_filters.dart';
import 'package:forja/shared/host/layout/list/panel_host.dart';
import 'package:forja/shared/engine/runtime/meta/plugin_actions.dart';
import 'package:forja/shared/host/layout/list/plugin_feed_source.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja_foundation/kit/row_prefetch.dart';
import 'package:forja/shared/engine/runtime/nav/top_menu_registry.dart';
import 'package:forja/shared/engine/store/list_follow.dart';
import 'package:forja/shared/host/layout/top_bar_host_hooks.dart';
import 'package:forja/shared/host/watch/watch_history.dart';
import 'package:forja/shared/playback/open/history_playback_resume.dart';
import 'package:forja/shared/playback/play_resolve.dart';
import 'package:forja/shared/player/details/hero_pill_buttons.dart';
import 'package:forja/shared/player/details/kit_details_play.dart';
import 'package:forja/shared/player/details/kit_details_play_row.dart';
import 'package:forja/shared/player/details/kit_entry_details.dart';
import 'package:forja/shared/player/details/kit_list_status_button.dart';
import 'package:forja/shared/player/details/kit_list_status_hero.dart';
import 'package:forja/shared/player/sources/kit_sources_panel.dart';
import 'package:forja/shared/shell/chrome/vertical_filters.dart';
import 'package:forja/shared/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shared/shell/core/forja_shell_layout.dart';
import 'package:forja/shared/shell/core/forja_shell_profile.dart';
import 'package:forja/shared/shell/core/forja_shell_scope.dart';
import 'package:forja/shared/shell/desktop/desktop_selectable_title.dart';
import 'package:forja/shared/shell/feedback/forja_toast.dart';
import 'package:forja/shared/shell/focus/focus_edge.dart';
import 'package:forja/shared/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shared/shell/tv/media_details_tv_scope.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/shell/tv/shell_tv_focus.dart';
import 'package:forja/shared/shell/tv/tv_browse_text_field.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';
import 'package:forja/shared/sync/providers/settings_revision_providers.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shell/chrome/kit_chrome_top_bar.dart';
import 'package:forja_foundation/protocol/filter.dart';
import 'package:forja_foundation/protocol/layout_types.dart';
import 'package:forja_foundation/protocol/pack_capabilities.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/utils/cover_urls.dart';
import 'package:forja_foundation/widgets/catalog/because_section.dart' as ds;
import 'package:forja_foundation/widgets/catalog/category_circle_meta.dart';
import 'package:forja_foundation/widgets/catalog/cinematic_hero.dart';
import 'package:forja_foundation/widgets/catalog/continue_section.dart';
import 'package:forja_foundation/widgets/catalog/continue_watching_card.dart';
import 'package:forja_foundation/widgets/catalog/event_card.dart';
import 'package:forja_foundation/widgets/catalog/event_dense_tile.dart';
import 'package:forja_foundation/widgets/catalog/home_loading_skeleton.dart' as skeleton_ds;
import 'package:forja_foundation/widgets/catalog/interactive_poster_card.dart';
import 'package:forja_foundation/widgets/catalog/poster_card.dart';
import 'package:forja_foundation/widgets/catalog/shell_mood_circle.dart';
import 'package:forja_foundation/widgets/chrome/action_chip.dart';
import 'package:forja_foundation/widgets/chrome/catalog_dense_list.dart';
import 'package:forja_foundation/widgets/chrome/catalog_list.dart';
import 'package:forja_foundation/widgets/chrome/catalog_menu.dart';
import 'package:forja_foundation/widgets/chrome/catalog_poster_grid.dart';
import 'package:forja_foundation/widgets/chrome/catalog_section.dart';
import 'package:forja_foundation/widgets/chrome/catalog_tabs.dart';
import 'package:forja_foundation/widgets/chrome/chip_row.dart';
import 'package:forja_foundation/widgets/chrome/filter_sheet_option.dart';
import 'package:forja_foundation/widgets/chrome/horizontal_scroller.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/chrome/shell_section_title.dart';
import 'package:forja_foundation/widgets/chrome/top_bar.dart';
import 'package:forja_foundation/widgets/chrome/top_bar_actions.dart';
import 'package:forja_foundation/widgets/feedback/card_play_overlay.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rust/rust.dart' show Movie;
import 'package:rust/rust.dart';
import 'package:visibility_detector/visibility_detector.dart';

export 'package:forja_foundation/widgets/catalog/cinematic_hero.dart';
export 'package:forja_foundation/widgets/catalog/continue_section.dart';
export 'package:forja_foundation/widgets/catalog/continue_watching_card.dart';
export 'package:forja_foundation/widgets/catalog/event_card.dart' show EventCard;
export 'package:forja_foundation/widgets/catalog/event_dense_tile.dart';
export 'package:forja_foundation/widgets/catalog/home_loading_skeleton.dart';
export 'package:forja_foundation/widgets/catalog/interactive_poster_card.dart';
export 'package:forja_foundation/widgets/catalog/poster_card.dart';
export 'package:forja_foundation/widgets/chrome/catalog_section.dart';
export 'package:forja_foundation/widgets/chrome/category_bar.dart';
export 'package:forja_foundation/widgets/chrome/event_list_search.dart';
export 'package:forja_foundation/widgets/chrome/filter_sheet_option.dart';
export 'package:forja_foundation/widgets/chrome/top_bar.dart' show TopBar;
export 'package:forja_foundation/widgets/chrome/top_bar_actions.dart';

typedef HomeHubLoadingRowSpec = skeleton_ds.HomeHubLoadingRowSpec;

// ===== movie_poster_card.dart =====

typedef MovieRatingBadge = RatingBadge;

class MoviePosterCard extends StatelessWidget {
  const MoviePosterCard({
    super.key,
    required this.movie,
    required this.onTap,
    this.rank,
    this.listIndex,
    this.onLeftEdge,
    this.onUpEdge,
    this.tvTabId,
    this.tvRowId,
  });

  final Movie movie;
  final VoidCallback onTap;
  final int? rank;
  final int? listIndex;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onUpEdge;
  final String? tvTabId;
  final String? tvRowId;

  static double cardWidth(BuildContext context) => shellPosterCardWidth(context);

  static double cardHeight(BuildContext context) =>
      shellPosterCardHeight(context);

  static String imageUrlFor(Movie movie) {
    if (movie.posterPath.isEmpty) return '';
    return resolveAbsoluteCoverUrl(movie.posterPath);
  }

  static String metaLine(Movie movie) {
    final parts = <String>[];
    if (movie.releaseDate.isNotEmpty) {
      parts.add(movie.releaseDate.split('-').first);
    }
    if (movie.mediaType == 'tv' || movie.mediaType == 'movie') {
      parts.add(movie.mediaType == 'tv' ? 'TV' : 'FILM');
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final w = MoviePosterCard.cardWidth(context);
    final h = MoviePosterCard.cardHeight(context);
    final radius = shellCardBorderRadius(context);
    final inset = shellScaled(context, 10).clamp(4.0, 10.0);
    final compact = w < 85;
    final pin = !compact
        ? KitListStatusButton.movie(
            movie: movie,
            excludeFromTvTraversal: true,
            iconSize: shellScaled(context, 18).clamp(12.0, 18.0),
          )
        : null;

    return shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: radius,
      showFocusBorder: true,
      listIndex: listIndex,
      onLeftEdge: onLeftEdge,
      onUpEdge: onUpEdge,
      tvTabId: tvTabId,
      tvRowId: tvRowId,
      tvItemIndex: listIndex,
      child: PosterCard(
        imageUrl: imageUrlFor(movie),
        title: movie.title,
        subtitle: metaLine(movie),
        rating: movie.voteAverage > 0 ? movie.voteAverage : null,
        rank: rank,
        listPin: pin,
        width: w,
        height: h,
        borderRadius: radius,
        titleFontSize: shellHubCardTitleFontSize(context),
        metaFontSize: shellScaled(context, 11).clamp(7.0, 11.0),
        inset: inset,
      ),
    );
  }
}

// ===== poster_card.dart =====

enum KitPosterAspect { portrait, landscape }

class KitPosterCard extends StatelessWidget {
  const KitPosterCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.onTap,
    this.onLongPress,
    this.longPressDuration = const Duration(milliseconds: 2000),
    this.subtitle,
    this.rating,
    this.rank,
    this.badge,
    this.listTarget,
    this.listPin,
    this.listIndex,
    this.gridIndex,
    this.gridColumns,
    this.tvTabId,
    this.tvRowId,
    this.onUpEdge,
    this.onLeftEdge,
    this.onRightEdge,
    this.aspect = KitPosterAspect.portrait,
  });

  final String imageUrl;
  final String title;
  final String? subtitle;
  final double? rating;
  final int? rank;
  final String? badge;
  final ListFollowTarget? listTarget;
  final Widget? listPin;
  final int? listIndex;
  final int? gridIndex;
  final int? gridColumns;
  final String? tvTabId;
  final String? tvRowId;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Duration longPressDuration;
  final KitPosterAspect aspect;

  static double cardWidth(
    BuildContext context, {
    KitPosterAspect aspect = KitPosterAspect.portrait,
  }) {
    return InteractivePosterCard.cardWidth(
      context,
      aspect: aspect == KitPosterAspect.landscape
          ? PosterAspect.landscape
          : PosterAspect.portrait,
    );
  }

  static double cardHeight(
    BuildContext context, {
    KitPosterAspect aspect = KitPosterAspect.portrait,
  }) {
    return InteractivePosterCard.cardHeight(
      context,
      aspect: aspect == KitPosterAspect.landscape
          ? PosterAspect.landscape
          : PosterAspect.portrait,
    );
  }

  @override
  Widget build(BuildContext context) {
    final posterAspect = aspect == KitPosterAspect.landscape
        ? PosterAspect.landscape
        : PosterAspect.portrait;
    final w = cardWidth(context, aspect: aspect);
    final compact = w < 85;
    final pin = listPin ??
        ((!compact && listTarget != null)
            ? KitListStatusButton.follow(
                followTarget: listTarget!,
                excludeFromTvTraversal: true,
                iconSize: shellScaled(context, 18).clamp(12.0, 18.0),
              )
            : null);

    return InteractivePosterCard(
      imageUrl: imageUrl,
      title: title,
      subtitle: subtitle,
      rating: rating,
      rank: rank,
      badge: badge,
      listPin: pin,
      listIndex: listIndex,
      gridIndex: gridIndex,
      gridColumns: gridColumns,
      tvTabId: tvTabId,
      tvRowId: tvRowId,
      onUpEdge: onUpEdge,
      onLeftEdge: onLeftEdge,
      onRightEdge: onRightEdge,
      onTap: onTap,
      onLongPress: onLongPress,
      longPressDuration: longPressDuration,
      aspect: posterAspect,
    );
  }
}

// ===== event_dense_tile.dart =====

class KitEventDenseTile extends StatefulWidget {
  const KitEventDenseTile({
    super.key,
    required this.title,
    required this.meta,
    required this.airing,
    required this.viewers,
    required this.selected,
    required this.index,
    required this.onTap,
    this.playable = true,
    this.tvTabId,
    this.tvRowId,
    this.onUpEdge,
    this.onLeftEdge,
    this.onRightEdge,
  });

  final String title;
  final String meta;
  final bool airing;
  final int viewers;
  final bool selected;
  final int index;
  final bool playable;
  final VoidCallback? onTap;
  final String? tvTabId;
  final String? tvRowId;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  @override
  State<KitEventDenseTile> createState() => _KitEventDenseTileState();
}

class _KitEventDenseTileState extends State<KitEventDenseTile> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tv = widget.tvTabId != null && widget.tvRowId != null;
    final paint = EventDenseTile(
      title: widget.title,
      meta: widget.meta,
      airing: widget.airing,
      viewers: widget.viewers,
      selected: widget.selected,
      playable: widget.playable,
      focused: _focused,
      hovered: _hovered,
    );

    return ShellPaintScope.focusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 0,
      scaleOnFocus: 1.0,
      showFocusFill: false,
      showFocusBorder: false,
      showFocusRail: false,
      suppressInkHover: true,
      listIndex: widget.index,
      gridIndex: tv ? widget.index : null,
      gridColumns: tv ? 1 : null,
      tvTabId: tv ? widget.tvTabId : null,
      tvRowId: tv ? widget.tvRowId : null,
      tvZone: tv ? ShellPaintTvZone.grid : null,
      tvItemIndex: tv ? widget.index : null,
      ensureVisibleMode: ShellPaintEnsureVisible.item,
      onUpEdge: widget.onUpEdge,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: (h) => setState(() => _hovered = h),
      child: paint,
    );
  }
}

String kitEventDenseMetaLine({
  required bool airing,
  String? startsAt,
  String? badge,
  List<String> genres = const [],
}) =>
    eventDenseMetaLine(
      airing: airing,
      startsAt: startsAt,
      badge: badge,
      genres: genres,
    );

// ===== event_card.dart =====
class KitEventCard extends StatefulWidget {
  const KitEventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.gridIndex,
    this.gridColumns,
    this.onUpEdge,
    this.onLeftEdge,
    this.onRightEdge,
    this.selected = false,
    this.tvTabId = 'kit_cards',
    this.tvRowId = 'schedule',
    this.tvZone = ShellPaintTvZone.grid,
    this.viewersOverride,
    this.width,
    this.height,
  });

  final KitListPaint event;
  final VoidCallback onTap;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final bool selected;
  final String tvTabId;
  final String tvRowId;
  final ShellPaintTvZone tvZone;
  final int? viewersOverride;
  final double? width;
  final double? height;

  static const widthScale = 1.15;
  static const heightScale = 1.32;

  static double tvCaptionBand(BuildContext context) =>
      shellScaled(context, 40).clamp(32.0, 48.0);

  static double cardWidth(BuildContext context) {
    if (ShellScope.metricsOf(context).usesTvDensity) {
      return shellContinueWatchingCardWidth(context);
    }
    return shellContinueWatchingCardWidth(context) * widthScale;
  }

  static double cardHeight(BuildContext context) {
    if (ShellScope.metricsOf(context).usesTvDensity) {
      return shellContinueWatchingCardHeight(context) + tvCaptionBand(context);
    }
    final height = shellContinueWatchingCardHeight(context) * heightScale;
    return height.clamp(190.0, 230.0);
  }

  static double gridGap(BuildContext context) =>
      shellPosterCardRowGap(context).clamp(8.0, 12.0);

  @override
  State<KitEventCard> createState() => _KitEventCardState();
}

class _KitEventCardState extends State<KitEventCard> {
  bool _hovered = false;
  bool _focused = false;

  int get _viewers => widget.viewersOverride ?? widget.event.viewers;

  @override
  Widget build(BuildContext context) {
    final m = widget.event;
    final live = m.isLive;
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final active = ShellPaintScope.interactiveActive(
          context,
          hovered: _hovered,
          focused: _focused,
        ) ||
        widget.selected;
    final w = widget.width ?? KitEventCard.cardWidth(context);
    final h = widget.height ?? KitEventCard.cardHeight(context);
    final radius = tv ? shellCardBorderRadius(context) : 14.0;

    return ShellPaintScope.focusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: radius,
      scaleOnFocus: 1.0,
      gridIndex: widget.tvZone == ShellPaintTvZone.grid ? widget.gridIndex : null,
      gridColumns:
          widget.tvZone == ShellPaintTvZone.grid ? widget.gridColumns : null,
      listIndex: widget.tvZone == ShellPaintTvZone.row ? widget.gridIndex : null,
      onUpEdge: widget.onUpEdge,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      tvTabId: widget.tvTabId,
      tvRowId: widget.tvRowId,
      tvZone: widget.tvZone,
      tvItemIndex: widget.gridIndex,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: EventCard(
        title: m.title,
        posterUrl: m.poster,
        homeTeam: m.homeTeam,
        awayTeam: m.awayTeam,
        homeBadgeUrl: m.homeBadge ?? '',
        awayBadgeUrl: m.awayBadge ?? '',
        categoryLabel: m.categoryLabel,
        scheduleLabel: m.scheduleLabel,
        timeLabel: m.timeLabel,
        viewers: _viewers,
        live: live,
        selected: widget.selected,
        active: active,
        tvDensity: tv,
        width: w,
        height: h,
        borderRadius: radius,
        titleFontSize: shellHubCardTitleFontSize(context),
        playOverlay: live
            ? ShellCardPlayOverlay(
                active: tv ? true : active,
                visible: true,
                diameter: tv ? 28 : 48,
                iconSize: tv ? 16 : 28,
              )
            : null,
      ),
    );
  }
}

// ===== filter_sheet_option.dart =====

class KitFilterSheetOption extends StatelessWidget {
  const KitFilterSheetOption({
    super.key,
    required this.label,
    required this.selected,
    required this.icon,
    required this.onSelected,
    required this.tvTabId,
    this.subtitle,
    this.tvItemIndex,
    this.tvRowId,
    this.focusNode,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final IconData icon;
  final VoidCallback onSelected;
  final String tvTabId;
  final int? tvItemIndex;
  final String? tvRowId;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final useTv = ShellPaintScope.useTvFocusOf(context);
    return FilterSheetOption(
      label: label,
      subtitle: subtitle,
      selected: selected,
      icon: icon,
      onSelected: onSelected,
      focusNode: focusNode,
      scaleOnHover: ShellPaintScope.scaleOnHoverOf(context),
      tvFocus: useTv,
      interactiveBuilder: useTv
          ? ({
              required child,
              required onTap,
              onFocusChange,
              onHoverChange,
              focusNode,
            }) =>
              ShellPaintScope.focusableTap(
                context: context,
                onTap: onTap,
                borderRadius: 12,
                scaleOnFocus: 1.0,
                showFocusBorder: false,
                showFocusFill: false,
                navLeftAlways: true,
                focusNode: focusNode,
                listIndex: tvItemIndex,
                tvTabId: tvTabId,
                tvRowId: tvRowId,
                tvItemIndex: tvItemIndex,
                tvZone: ShellPaintTvZone.row,
                onFocusChange: onFocusChange,
                onHoverChange: onHoverChange,
                child: child,
              )
          : null,
    );
  }
}

// ===== continue_watching_card.dart =====

class HostContinueWatchingCard extends StatefulWidget {
  const HostContinueWatchingCard({
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
  State<HostContinueWatchingCard> createState() =>
      _HostContinueWatchingCardState();
}

class _HostContinueWatchingCardState extends State<HostContinueWatchingCard> {
  bool _hovered = false;
  bool _focused = false;

  bool _activeFor(ShellInputPolicy policy) =>
      ShellInputPolicy.interactiveActive(
        policy,
        hovered: _hovered,
        focused: _focused,
        context: context,
      );

  Future<void> _showTvActions(BuildContext context) async {
    final mapped = ContinueEntry.fromMap(widget.entry);
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A0A0A),
          title: Text(
            mapped.title,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              shellFocusableTap(
                context: ctx,
                borderRadius: 8,
                onTap: () => Navigator.pop(ctx, 'info'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'More info',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
              shellFocusableTap(
                context: ctx,
                borderRadius: 8,
                onTap: () => Navigator.pop(ctx, 'remove'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Remove from Continue Watching',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'info':
        widget.onInfo();
      case 'remove':
        widget.onRemove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final mapped = ContinueEntry.fromMap(widget.entry);
    final radius = shellCardBorderRadius(context);
    final active = _activeFor(policy);

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
      onKeyEvent: policy.useFocusableMoodChips
          ? (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              final key = event.logicalKey;
              if (key == LogicalKeyboardKey.contextMenu ||
                  key == LogicalKeyboardKey.f1) {
                unawaited(_showTvActions(context));
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            }
          : null,
      child: ContinueWatchingCard(
        title: mapped.title,
        coverUrl: mapped.coverUrl,
        subtitle: mapped.subtitle,
        progress: mapped.progress,
        remainingText: mapped.remainingText,
        width: HostContinueWatchingCard.cardWidth(context),
        height: HostContinueWatchingCard.cardHeight(context),
        borderRadius: radius,
        active: active,
        isLoading: widget.isLoading,
        showActionButtons: policy.scaleOnHover,
        onRemove: widget.onRemove,
        onInfo: widget.onInfo,
        playOverlay: ShellCardPlayOverlay(
          active: false,
          visible: active && !widget.isLoading,
        ),
      ),
    );
  }
}

typedef ContinueWatchingCardHost = HostContinueWatchingCard;

// ===== home_loading_skeleton.dart =====

Widget homeLoadingShimmer(Widget child) => skeleton_ds.homeLoadingShimmer(child);

Widget homeTitleBarSkeleton(
  BuildContext context, {
  double width = 140,
  double? height,
}) {
  final h = height ?? shellScaled(context, 18).clamp(10.0, 18.0);
  const minWidth = 60.0;
  final maxWidth = math.max(minWidth, width);
  return skeleton_ds.homeTitleBarSkeleton(
    width: shellScaled(context, width).clamp(minWidth, maxWidth),
    height: h,
  );
}

Widget homeCardSkeleton(
  BuildContext context, {
  double? width,
  double? height,
}) {
  return skeleton_ds.homeCardSkeleton(
    width: width ?? MoviePosterCard.cardWidth(context),
    height: height ?? MoviePosterCard.cardHeight(context),
    borderRadius: shellCardBorderRadius(context),
  );
}

bool homeUsesShellLayout(BuildContext context) => shellUsesWideLayout(context);

double homeSectionTitleTop(BuildContext context, {bool compactTop = false}) =>
    shellHomeSectionTitleTop(context, compact: compactTop);

double homeContinueWatchingCardWidth(BuildContext context) =>
    shellContinueWatchingCardWidth(context);

double homeContinueWatchingCardHeight(BuildContext context) =>
    shellContinueWatchingCardHeight(context);

Widget homePosterRowSkeleton(
  BuildContext context, {
  bool compactTop = false,
  double titleWidth = 140,
  int itemCount = 5,
  bool showSubtitle = false,
  double topPadding = 0,
  double? cardWidth,
  double? cardHeight,
}) {
  final top = topPadding > 0
      ? topPadding
      : homeSectionTitleTop(context, compactTop: compactTop);
  return skeleton_ds.homePosterRowSkeleton(
    titleWidth: titleWidth,
    itemCount: itemCount,
    showSubtitle: showSubtitle,
    topPadding: top,
    horizontalPadding: shellHomeSectionHorizontalPadding(context),
    titleBottomGap: shellHomeSectionBottomGap(context),
    cardGap: shellPosterCardRowGap(context),
    cardWidth: cardWidth ?? MoviePosterCard.cardWidth(context),
    cardHeight: cardHeight ?? MoviePosterCard.cardHeight(context),
    borderRadius: shellCardBorderRadius(context),
  );
}

Widget homeContinueWatchingSkeleton(
  BuildContext context, {
  bool compactTop = false,
}) {
  return skeleton_ds.homeContinueWatchingSkeleton(
    topPadding: homeSectionTitleTop(context, compactTop: compactTop),
    horizontalPadding: shellHomeSectionHorizontalPadding(context),
    titleBottomGap: shellHomeSectionBottomGap(context),
    cardGap: shellPosterCardRowGap(context),
    cardWidth: homeContinueWatchingCardWidth(context),
    cardHeight: homeContinueWatchingCardHeight(context),
    borderRadius: shellCardBorderRadius(context),
  );
}

Widget homeCatalogCardRowSkeleton(BuildContext context, {int itemCount = 5}) {
  return skeleton_ds.homeCatalogCardRowSkeleton(
    itemCount: itemCount,
    horizontalPadding: shellHomeSectionHorizontalPadding(context),
    cardGap: shellPosterCardRowGap(context),
    cardWidth: MoviePosterCard.cardWidth(context),
    cardHeight: MoviePosterCard.cardHeight(context),
    borderRadius: shellCardBorderRadius(context),
  );
}

double homeCinematicHeroBodyHeight(
  BuildContext context, {
  required bool compact,
  bool pageBottomBleed = false,
}) {
  return skeleton_ds.homeCinematicHeroBodyHeight(
    screenHeight: MediaQuery.sizeOf(context).height,
    compact: compact,
    pageBottomBleed: pageBottomBleed,
  );
}

Widget homeCinematicHeroShimmer(
  BuildContext context, {
  bool pageBottomBleed = false,
}) {
  final compact =
      !ShellScope.metricsOf(context).usesTvDensity &&
      MediaQuery.sizeOf(context).width < ShellTokens.heroDesktopMinBodyWidth;
  final height =
      homeCinematicHeroBodyHeight(
        context,
        compact: compact,
        pageBottomBleed: pageBottomBleed && !compact,
      ) +
      MediaQuery.paddingOf(context).top;
  return skeleton_ds.homeHubHeroShimmer(height: height);
}

Widget homeHubHeroShimmer({required double height}) =>
    skeleton_ds.homeHubHeroShimmer(height: height);

SliverToBoxAdapter homeHubRowSliver(
  BuildContext context,
  Widget section, {
  required bool isFirstAfterHero,
}) {
  return SliverToBoxAdapter(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isFirstAfterHero) SizedBox(height: shellHomeRowSpacing(context)),
        RepaintBoundary(child: section),
      ],
    ),
  );
}

List<Widget> homeHubLoadingSlivers(
  BuildContext context, {
  required Widget heroShimmer,
  List<HomeHubLoadingRowSpec>? rows,
  double? catalogCardWidth,
  double? catalogCardHeight,
}) {
  final specs = rows ?? skeleton_ds.kHomeHubDefaultLoadingRows;
  return [
    for (final w in skeleton_ds.homeHubLoadingSlivers(
      heroShimmer: heroShimmer,
      rows: specs,
      catalogCardWidth: catalogCardWidth ?? MoviePosterCard.cardWidth(context),
      catalogCardHeight:
          catalogCardHeight ?? MoviePosterCard.cardHeight(context),
      rowSpacing: shellHomeRowSpacing(context),
    ))
      w,
  ];
}

// ===== section_sliver.dart =====
SliverToBoxAdapter hubRowSliver(
  BuildContext context,
  Widget section, {
  required bool isFirstAfterHero,
}) {
  return SliverToBoxAdapter(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isFirstAfterHero) SizedBox(height: shellHomeRowSpacing(context)),
        RepaintBoundary(child: section),
      ],
    ),
  );
}

class KitLazyViewportGate extends StatefulWidget {
  const KitLazyViewportGate({
    super.key,
    required this.detectorKey,
    required this.placeholderHeight,
    required this.onVisible,
    required this.builder,
    this.prefetchSlot,
  });

  final Key detectorKey;
  final double placeholderHeight;
  final VoidCallback onVisible;
  final Widget Function(bool activated) builder;
  final KitRowPrefetchSlot? prefetchSlot;

  @override
  State<KitLazyViewportGate> createState() => _KitLazyViewportGateState();
}

class _KitLazyViewportGateState extends State<KitLazyViewportGate> {
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    _registerPrefetch();
  }

  @override
  void didUpdateWidget(covariant KitLazyViewportGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.prefetchSlot != null) {
      _registerPrefetch();
    }
  }

  void _registerPrefetch() {
    final slot = widget.prefetchSlot;
    if (slot == null) return;
    slot.lane.register(slot.index, _warmFromPrefetch);
  }

  void _warmFromPrefetch() {
    _activate(prefetch: true);
  }

  void _activate({required bool prefetch}) {
    if (_activated) {
      if (!prefetch) widget.prefetchSlot?.notifyVisible();
      return;
    }
    setState(() => _activated = true);
    widget.onVisible();
    widget.prefetchSlot?.notifyVisible();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_activated || info.visibleFraction <= 0) return;
    _activate(prefetch: false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_activated) {
      return VisibilityDetector(
        key: widget.detectorKey,
        onVisibilityChanged: _onVisibilityChanged,
        child: SizedBox(height: widget.placeholderHeight),
      );
    }
    return widget.builder(true);
  }
}

// ===== section.dart =====

const int kMetaRailPageSizeHint = kMetaRailPageSizeFallback;

class KitSection<T> extends StatefulWidget {
  const KitSection({
    super.key,
    required this.title,
    required this.cardBuilder,
    this.future,
    this.fetchPage,
    this.items,
    this.lazy = false,
    this.pageSizeHint = kMetaRailPageSizeFallback,
    this.itemKey,
    this.compactTop = false,
    this.embedded = false,
    this.showRank = false,
    this.tvTabId,
    this.tvRowId,
    this.tvRowOrder = 0,
    this.tvFocusUp,
    this.cardAspect = KitPosterAspect.portrait,
    this.prefetchSlot,
    this.onFirstPageLoaded,
    this.reloadToken,
    this.holdEmptyStructure = false,
  }) : assert(
         future != null || items != null || fetchPage != null,
         'Provide future, items, or fetchPage',
       );

  final String title;
  final Future<List<T>>? future;
  final Future<MetaRailPage<T>> Function(int page)? fetchPage;
  final List<T>? items;
  final bool lazy;
  final int pageSizeHint;
  final String Function(T item)? itemKey;
  final bool compactTop;
  final bool embedded;
  final bool showRank;
  final String? tvTabId;
  final String? tvRowId;
  final int tvRowOrder;
  final VoidCallback? tvFocusUp;
  final KitPosterAspect cardAspect;
  final KitRowPrefetchSlot? prefetchSlot;
  final void Function(int itemCount)? onFirstPageLoaded;
  final String? reloadToken;
  final bool holdEmptyStructure;
  final KitPosterCard Function(BuildContext context, T item, int index)
  cardBuilder;

  static double sectionHeight(
    BuildContext context, {
    bool compactTop = false,
    bool embedded = false,
    KitPosterAspect cardAspect = KitPosterAspect.portrait,
  }) {
    final titleTop = embedded
        ? 0.0
        : shellHomeSectionTitleTop(context, compact: compactTop);
    return titleTop +
        shellHomeSectionHeaderHeight(context) +
        shellHomeSectionBottomGap(context) +
        KitPosterCard.cardHeight(context, aspect: cardAspect);
  }

  @override
  State<KitSection<T>> createState() => _KitSectionState<T>();
}

class _KitSectionState<T> extends State<KitSection<T>> {
  final GlobalKey<CatalogSectionState<T>> _sectionKey =
      GlobalKey<CatalogSectionState<T>>();

  @override
  void initState() {
    super.initState();
    _registerPrefetch();
  }

  @override
  void didUpdateWidget(covariant KitSection<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.prefetchSlot != null) {
      _registerPrefetch();
    }
  }

  void _registerPrefetch() {
    final slot = widget.prefetchSlot;
    if (slot == null) return;
    slot.lane.register(slot.index, _warmFromPrefetch);
  }

  void _warmFromPrefetch() {
    _sectionKey.currentState?.activateLazy();
    widget.prefetchSlot?.notifyVisible();
  }

  double _sectionTitleTop(BuildContext context) {
    if (widget.embedded) return 0;
    if (!widget.compactTop) return shellHomeSectionTitleTop(context);
    return shellSectionTitleTopCompact(context);
  }

  Widget _rowSkeleton(BuildContext context) {
    return homeLoadingShimmer(
      homePosterRowSkeleton(
        context,
        compactTop: widget.compactTop,
        titleWidth: widget.title.length > 12
            ? 180
            : widget.title.length * 11.0,
        cardWidth: KitPosterCard.cardWidth(context, aspect: widget.cardAspect),
        cardHeight:
            KitPosterCard.cardHeight(context, aspect: widget.cardAspect),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPad = widget.embedded
        ? 0.0
        : shellHomeSectionHorizontalPadding(context);
    final sectionTop = _sectionTitleTop(context);

    return CatalogSection<T>(
      key: _sectionKey,
      title: widget.title,
      future: widget.future,
      fetchPage: widget.fetchPage,
      items: widget.items,
      lazy: widget.lazy,
      pageSizeHint: widget.pageSizeHint,
      itemKey: widget.itemKey,
      compactTop: widget.compactTop,
      embedded: widget.embedded,
      onFirstPageLoaded: widget.onFirstPageLoaded,
      reloadToken: widget.reloadToken,
      holdEmptyStructure: widget.holdEmptyStructure,
      placeholderHeight: KitSection.sectionHeight(
        context,
        compactTop: widget.compactTop,
        embedded: widget.embedded,
        cardAspect: widget.cardAspect,
      ),
      onVisible: () => widget.prefetchSlot?.notifyVisible(),
      cardBuilder: (context, item, index) =>
          widget.cardBuilder(context, item, index),
      skeletonBuilder: _rowSkeleton,
      titleBuilder: (context, title) {
        if (title.isEmpty) return const SizedBox.shrink();
        return ShellSectionTitle(
          title: title,
          padding: EdgeInsetsDirectional.only(
            start: horizontalPad,
            top: sectionTop,
            end: horizontalPad,
            bottom: widget.embedded
                ? DetailsTokens.sectionTitleGap
                : shellHomeSectionBottomGap(context),
          ),
        );
      },
      scrollerBuilder: ({
        required context,
        required children,
        required onApproachingEnd,
      }) {
        return FocusTraversalGroup(
          child: HorizontalScroller(
            height: KitPosterCard.cardHeight(
              context,
              aspect: widget.cardAspect,
            ),
            padding: EdgeInsets.symmetric(horizontal: horizontalPad),
            itemCount: children.length,
            onApproachingEnd: widget.fetchPage != null ? onApproachingEnd : null,
            separatorBuilder: (_, _) => SizedBox(
              width: widget.showRank
                  ? shellScaled(context, 6).clamp(3.0, 6.0)
                  : shellPosterCardRowGap(context),
            ),
            itemBuilder: (context, index) => children[index],
          ),
        );
      },
      wrapRow: (child, {required itemCount}) {
        final tabId = widget.tvTabId ?? ShellTvFocus.currentNavTabId;
        final rowId = widget.tvRowId;
        if (tabId == null || rowId == null) return child;
        return ShellPaintScope.tvRow(
          context: context,
          tabId: tabId,
          rowId: rowId,
          sortOrder: widget.tvRowOrder,
          itemCount: itemCount,
          onFocusUp: widget.tvFocusUp,
          child: child,
        );
      },
      lazyPlaceholder: (context, activate) {
        return VisibilityDetector(
          key: ValueKey('hub-lazy:${widget.tvRowId ?? widget.title}'),
          onVisibilityChanged: (info) {
            if (info.visibleFraction <= 0) return;
            activate();
          },
          child: SizedBox(
            height: KitSection.sectionHeight(
              context,
              compactTop: widget.compactTop,
              embedded: widget.embedded,
              cardAspect: widget.cardAspect,
            ),
          ),
        );
      },
    );
  }
}

// ===== list_event_search.dart =====

const _kSearchCollapsed = 40.0;
const _kSearchExpanded = 260.0;

class KitListEventSearch extends ConsumerStatefulWidget {
  const KitListEventSearch({
    super.key,
    required this.tabId,
    required this.rowId,
    required this.itemIndex,
    this.tooltip = 'Search',
    this.placeholder = 'Search…',
    this.onLeftEdge,
    this.onRightEdge,
    this.onDownEdge,
  });

  final String tabId;
  final String rowId;
  final int itemIndex;
  final String tooltip;
  final String placeholder;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onDownEdge;

  @override
  ConsumerState<KitListEventSearch> createState() =>
      _KitListEventSearchState();
}

class _KitListEventSearchState extends ConsumerState<KitListEventSearch>
    with SingleTickerProviderStateMixin {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _fieldFocus =
      FocusNode(debugLabel: 'kit-list-event-search');
  final FocusNode _closeFocus =
      FocusNode(debugLabel: 'kit-list-event-search-close');
  final GlobalKey<TvBrowseTextFieldState> _fieldKey =
      GlobalKey<TvBrowseTextFieldState>();
  late final AnimationController _anim;
  late final Animation<double> _expand;
  bool _toolFocused = false;
  bool _toolHovered = false;
  bool _closeFocused = false;
  bool _closeHovered = false;
  bool _dialogOpen = false;

  bool get _tv => ShellScope.inputPolicyOf(context).useFocusableMoodChips;

  String get _chromeKey => kitChromeKeyForTab(widget.tabId);

  @override
  void initState() {
    super.initState();
    final key = kitChromeKeyForTab(widget.tabId);
    _ctrl.text = key.isEmpty ? '' : ref.read(kitListEventQueryProvider(key));
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _expand = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _anim.addStatusListener(_onExpandStatus);
    if (key.isNotEmpty && ref.read(kitListEventSearchOpenProvider(key))) {
      _anim.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncTvFieldRegistration(open: true);
      });
    }
    ShellBus.registerFindShortcutHandler(_handleFindShortcut);
  }

  void _onExpandStatus(AnimationStatus status) {
    if (!mounted) return;
    final key = _chromeKey;
    if (status == AnimationStatus.completed &&
        key.isNotEmpty &&
        ref.read(kitListEventSearchOpenProvider(key))) {
      _syncTvFieldRegistration(open: true);
    }
  }

  @override
  void dispose() {
    ShellBus.unregisterFindShortcutHandler(_handleFindShortcut);
    _anim.removeStatusListener(_onExpandStatus);
    _syncTvFieldRegistration(open: false);
    _anim.dispose();
    _ctrl.dispose();
    _fieldFocus.dispose();
    _closeFocus.dispose();
    super.dispose();
  }

  void _syncTvFieldRegistration({required bool open}) {
    if (open) {
      ShellTvFocusCoordinator.registerItemNode(
        tabId: widget.tabId,
        rowId: widget.rowId,
        index: widget.itemIndex,
        node: _fieldFocus,
      );
      return;
    }
    ShellTvFocusCoordinator.unregisterItemNode(
      tabId: widget.tabId,
      rowId: widget.rowId,
      index: widget.itemIndex,
      node: _fieldFocus,
    );
  }

  bool _handleFindShortcut() {
    if (!mounted) return false;
    _openSearch(compact: MediaQuery.sizeOf(context).width < 760);
    return true;
  }

  void _setQuery(String value) {
    final key = _chromeKey;
    if (key.isEmpty) return;
    ref.read(kitListEventQueryProvider(key).notifier).state = value;
  }

  void _setOpen(bool open) {
    final key = _chromeKey;
    if (key.isNotEmpty) {
      ref.read(kitListEventSearchOpenProvider(key).notifier).state = open;
    }
    _syncTvFieldRegistration(open: open);
  }

  void _openSearch({required bool compact}) {
    if (compact) {
      unawaited(_openCompactDialog());
      return;
    }
    final key = _chromeKey;
    if (key.isNotEmpty && ref.read(kitListEventSearchOpenProvider(key))) {
      _focusField(edit: _tv);
      return;
    }
    _setOpen(true);
    _anim.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncTvFieldRegistration(open: true);
      _focusField(edit: _tv);
    });
  }

  Future<void> _openCompactDialog() async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    final key = _chromeKey;
    final initial =
        key.isEmpty ? '' : ref.read(kitListEventQueryProvider(key));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final local = TextEditingController(text: initial);
        return AlertDialog(
          backgroundColor: ForjaShellColors.surfaceElevated,
          title: Text(
            widget.tooltip,
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: local,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: const TextStyle(color: Colors.white38),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, local.text),
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
    _dialogOpen = false;
    if (!mounted || result == null) return;
    _ctrl.text = result;
    _setQuery(result);
    _setOpen(result.trim().isNotEmpty);
  }

  void _closeSearch() {
    _setOpen(false);
    _setQuery('');
    _ctrl.clear();
    _fieldFocus.unfocus();
    _closeFocus.unfocus();
    _anim.reverse();
  }

  void _focusField({bool edit = false}) {
    if (!_fieldFocus.canRequestFocus) return;
    _syncTvFieldRegistration(open: true);
    _fieldFocus.requestFocus();
    ShellTvFocusCoordinator.onRowItemFocused(
      tabId: widget.tabId,
      rowId: widget.rowId,
      index: widget.itemIndex,
      node: _fieldFocus,
      zone: ShellTvZone.topBar,
    );
    if (!edit) {
      _fieldKey.currentState?.endEditing(keepFocus: true);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fieldKey.currentState?.beginEditing();
    });
  }

  KeyEventResult _onFieldKey(FocusNode node, KeyEvent event) {
    if (!_tv) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final editing = _fieldKey.currentState?.isEditing ?? false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape) {
      _closeSearch();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight && !editing) {
      if (_closeFocus.canRequestFocus) _closeFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) return KeyEventResult.handled;
    if (key == LogicalKeyboardKey.arrowDown) {
      widget.onDownEdge?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && !editing) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final key = _chromeKey;
    final open = key.isEmpty
        ? false
        : ref.watch(kitListEventSearchOpenProvider(key));
    final query =
        key.isEmpty ? '' : ref.watch(kitListEventQueryProvider(key));
    if (key.isNotEmpty) {
      ref.listen<bool>(kitListEventSearchOpenProvider(key), (prev, next) {
        if (prev == next) return;
        _syncTvFieldRegistration(open: next);
        if (next) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && ref.read(kitListEventSearchOpenProvider(key))) {
              _syncTvFieldRegistration(open: true);
            }
          });
        }
      });
    }
    if (_ctrl.text != query && !_fieldFocus.hasFocus) {
      _ctrl.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
    if (open && _anim.status == AnimationStatus.dismissed) {
      _anim.value = 1;
    }

    final compact = MediaQuery.sizeOf(context).width < 760;
    if (compact) {
      return _collapsedIcon(compact: true, hasQuery: query.trim().isNotEmpty);
    }

    return AnimatedBuilder(
      animation: _expand,
      builder: (context, _) {
        final t = _expand.value;
        final width =
            _kSearchCollapsed + (_kSearchExpanded - _kSearchCollapsed) * t;
        return SizedBox(
          width: width,
          height: _kSearchCollapsed,
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              if (t > 0.02)
                Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: OverflowBox(
                    maxWidth: _kSearchExpanded,
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: _kSearchExpanded,
                      child: _fieldChrome(),
                    ),
                  ),
                ),
              if (t < 0.98)
                Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: _collapsedIcon(
                    compact: false,
                    hasQuery: query.trim().isNotEmpty,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _collapsedIcon({required bool compact, required bool hasQuery}) {
    final policy = ShellScope.inputPolicyOf(context);
    final active = ShellInputPolicy.interactiveActive(
      policy,
      hovered: _toolHovered,
      focused: _toolFocused,
      context: context,
    );
    final tvFocused = _tv && _toolFocused;
    final idleAlpha = hasQuery ? 0.12 : 0.08;
    return shellFocusableTap(
      context: context,
      onTap: () => _openSearch(compact: compact),
      borderRadius: _kSearchCollapsed / 2,
      scaleOnFocus: 1.0,
      suppressInkHover: true,
      showFocusFill: false,
      tvTabId: widget.tabId,
      tvRowId: widget.rowId,
      tvItemIndex: widget.itemIndex,
      tvZone: ShellTvZone.topBar,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onDownEdge: widget.onDownEdge,
      onUpEdge: () {},
      onFocusChange: (f) => setState(() => _toolFocused = f),
      onHoverChange: (h) => setState(() => _toolHovered = h),
      child: Tooltip(
        message: widget.tooltip,
        child: Container(
          width: _kSearchCollapsed,
          height: _kSearchCollapsed,
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: active || tvFocused ? 0.16 : idleAlpha,
            ),
            borderRadius: BorderRadius.circular(_kSearchCollapsed / 2),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: tvFocused
                    ? 0.45
                    : active
                        ? 0.28
                        : hasQuery
                            ? 0.22
                            : 0.12,
              ),
              width: tvFocused ? 1.5 : 1,
            ),
          ),
          child: Icon(
            Icons.search_rounded,
            color: active || tvFocused || hasQuery
                ? Colors.white
                : Colors.white60,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _fieldChrome() {
    final closeActive = ShellInputPolicy.interactiveActive(
      ShellScope.inputPolicyOf(context),
      hovered: _closeHovered,
      focused: _closeFocused,
      context: context,
    );
    final closeTv = _tv && _closeFocused;
    return Container(
      height: _kSearchCollapsed,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(_kSearchCollapsed / 2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.search_rounded, color: Colors.white70, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: TvBrowseTextField(
              key: _fieldKey,
              controller: _ctrl,
              focusNode: _fieldFocus,
              onChanged: _setQuery,
              onEscape: _closeSearch,
              onSubmitted: (_) => _focusField(edit: false),
              onKeyEvent: _onFieldKey,
              browsePlaceholder: widget.placeholder,
              browseHintStyle: GoogleFonts.plusJakartaSans(
                color: Colors.white38,
                fontSize: 13,
              ),
              caretHeight: 16,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 13,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          shellFocusableTap(
            context: context,
            onTap: _closeSearch,
            focusNode: _closeFocus,
            borderRadius: 16,
            scaleOnFocus: 1.0,
            suppressInkHover: true,
            showFocusFill: false,
            onLeftEdge: () => _focusField(edit: false),
            onRightEdge: widget.onRightEdge,
            onDownEdge: widget.onDownEdge,
            onUpEdge: () {},
            onFocusChange: (f) => setState(() => _closeFocused = f),
            onHoverChange: (h) => setState(() => _closeHovered = h),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: closeActive || closeTv ? Colors.white : Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== kit_top_bar.dart =====
class KitTopBar extends StatelessWidget {
  const KitTopBar({super.key, required this.tabId});

  final String tabId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: KitTopMenuRegistry.revision,
      builder: (context, _) {
        final handle = KitTopMenuRegistry.handleFor(tabId);
        if (handle == null) return const SizedBox.shrink();

        final menuSpec = handle.menuSpec;
        final tabsSpec = handle.tabsSpec;
        final barHeight = KitTopMenuRegistry.bodyTopInset(context, tabId);

        return TopBar(
          height: barHeight,
          child: SafeArea(
            bottom: false,
            left: false,
            right: false,
            child: LayoutScope(
              // Snapshot — live map mutation would make updateShouldNotify
              // see identical content and skip menu/tab rebuilds.
              selections: Map<String, String>.from(handle.selections),
              onSelect: handle.onSelect,
              widgetSpecs: handle.widgetSpecs,
              tabId: tabId,
              focusEdge: (rowId, {last = false}) =>
                  kitFocusEdge(tabId, rowId, last: last),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (menuSpec != null)
                    CatalogMenu(
                      spec: menuSpec,
                      sortOrder: 0,
                      inShellTopBar: true,
                    ),
                  if (tabsSpec != null)
                    CatalogTabs(
                      spec: tabsSpec,
                      sortOrder: 1,
                      inShellTopBar: true,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ===== kit_top_bar_actions.dart =====

List<String> kitTopBarCatalogDeps(List<Map<String, dynamic>> actions) {
  final out = <String>{};
  for (final a in actions) {
    final id = (a['id'] ?? '').toString();
    final isCatalog = id == 'catalog' || a['dynamicCatalogs'] == true;
    if (!isCatalog) continue;
    final raw = a['deps'];
    if (raw is! List) continue;
    for (final d in raw) {
      final s = d?.toString().trim().toLowerCase() ?? '';
      if (s.isNotEmpty) out.add(s);
    }
  }
  final list = out.toList()..sort();
  return list;
}

String kitTopBarCatalogDepsKey(List<String> deps) => deps.join(',');

final kitTopBarCatalogOptionsProvider = FutureProvider.autoDispose
    .family<List<({String id, String label})>, String>((ref, depsKey) async {
  for (final d in depsKey.split(',')) {
    final token = d.trim();
    if (token.isEmpty) continue;
    switch (token) {
      case 'stremio':
        ref.watch(addonRevisionProvider);
      default:
        break;
    }
  }
  final loader = KitTopBarHostHooks.loadCatalogOptions;
  if (loader == null) return const [];
  return loader();
});

class KitTopBarActions extends ConsumerWidget {
  const KitTopBarActions({
    super.key,
    required this.tabId,
    required this.spec,
    this.sortOrder = 0,
    this.onRefresh,
  });

  final String tabId;
  final Map<String, dynamic> spec;
  final int sortOrder;
  final VoidCallback? onRefresh;

  String get _widgetId => (spec['id'] ?? 'topBar').toString();

  List<Map<String, dynamic>> get _actions {
    final raw = spec['actions'];
    if (raw is! List) return const [];
    return [
      for (final a in raw)
        if (a is Map) Map<String, dynamic>.from(a),
    ];
  }

  static bool _isTrailing(Map<String, dynamic> action) {
    if (action['trailing'] == true) return true;
    final slot = (action['slot'] ?? '').toString().trim().toLowerCase();
    return slot == 'trailing' || slot == 'end' || slot == 'right';
  }

  static String _verb(Map<String, dynamic> action) {
    final a = (action['action'] ?? '').toString().trim().toLowerCase();
    if (a.isNotEmpty) return a;
    return (action['id'] ?? '').toString().trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = _actions;
    if (actions.isEmpty) return const SizedBox.shrink();
    final scope = LayoutScope.of(context);
    // last: restore prior schedule/list index (↑ from match → Portals → ↓).
    final focusDown =
        kitFocusEdge(tabId, spec['focusDown']?.toString(), last: true);
    final focusLeft = kitFocusSide(tabId, spec['focusLeft']);
    final focusRight = kitFocusSide(tabId, spec['focusRight']);
    final depsKey = kitTopBarCatalogDepsKey(kitTopBarCatalogDeps(actions));
    final catalogsAsync = ref.watch(kitTopBarCatalogOptionsProvider(depsKey));
    final catalogOptions = catalogsAsync.asData?.value ?? const [];
    final chromeKey = kitChromeKeyForTab(tabId);
    final layoutHorizon = scope.selectedId('horizon') ??
        scope.selectedId('schedule') ??
        scope.selectedId('time');
    final horizonPref = chromeKey.isEmpty
        ? ''
        : ref.watch(kitFeedHorizonPrefProvider(chromeKey));
    final resolvedHorizon =
        (layoutHorizon == null || layoutHorizon.isEmpty)
            ? horizonPref
            : layoutHorizon;
    final layoutCatalog = scope.selectedId('catalog');
    final catalogPref =
        KitTopBarHostHooks.readCatalogPref?.call(ref, tabId: tabId) ??
            layoutCatalog;
    final feedBusy =
        KitTopBarHostHooks.readFeedBusy?.call(ref, tabId: tabId);
    final busy = feedBusy?.busy == true;
    final busyLabel = () {
      final raw = (feedBusy?.label ?? '').trim();
      if (raw.isNotEmpty) return raw;
      return 'Loading…';
    }();
    final updatedLabel = busy
        ? ''
        : (KitTopBarHostHooks.readFeedUpdatedLabel?.call(ref, tabId: tabId) ??
                '')
            .trim();

    final leading = <Map<String, dynamic>>[];
    final trailing = <Map<String, dynamic>>[];
    for (final a in actions) {
      if (_isTrailing(a)) {
        trailing.add(a);
      } else {
        leading.add(a);
      }
    }

    var planned = 0;
    for (final a in leading) {
      if (busy && _isRefreshAction(a)) continue;
      planned++;
    }
    for (final a in trailing) {
      if (busy && _isRefreshAction(a)) continue;
      planned++;
    }
    final lastIndex = planned - 1;

    final built = <Widget>[];
    var index = 0;
    for (final a in leading) {
      // Hide Refresh while scrape/search is busy — status text sits center-top.
      if (busy && _isRefreshAction(a)) continue;
      final w = _buildAction(
        context,
        ref,
        scope,
        a,
        index: index,
        focusDown: focusDown,
        focusLeft: index == 0 ? focusLeft : null,
        focusRight: index == lastIndex ? focusRight : null,
        catalogOptions: catalogOptions,
        catalogPref: catalogPref,
        horizonPref: resolvedHorizon,
      );
      if (w != null) {
        built.add(w);
        index++;
      }
    }
    final leadingCount = built.length;
    final trailingBuilt = <Widget>[];
    for (final a in trailing) {
      if (busy && _isRefreshAction(a)) continue;
      final w = _buildAction(
        context,
        ref,
        scope,
        a,
        index: index,
        focusDown: focusDown,
        focusLeft: index == 0 ? focusLeft : null,
        focusRight: index == lastIndex ? focusRight : null,
        catalogOptions: catalogOptions,
        catalogPref: catalogPref,
        horizonPref: resolvedHorizon,
      );
      if (w != null) {
        trailingBuilt.add(w);
        index++;
      }
    }

    final Widget? centerStatus;
    if (busy) {
      centerStatus = _KitTopBarCatalogProgressChip(label: busyLabel);
    } else if (updatedLabel.isNotEmpty) {
      centerStatus = _KitTopBarUpdatedLabel(label: updatedLabel);
    } else {
      centerStatus = null;
    }

    final itemCount = leadingCount + trailingBuilt.length;
    final chromeOrder = sortOrder < 0 ? sortOrder : -100 - sortOrder;
    return TopBarActions(
      leading: built,
      trailing: trailingBuilt,
      center: centerStatus,
      padding: EdgeInsets.fromLTRB(
        ShellTokens.compactChromeLeadingInset(context),
        ShellTokens.tabHeaderTopPadding,
        ShellTokens.bodyHorizontalPadding,
        4,
      ),
      wrapRow: (child) => TvKitRow(
        tabId: tabId,
        rowId: _widgetId,
        sortOrder: chromeOrder,
        itemCount: itemCount,
        onFocusUp: () {},
        child: child,
      ),
    );
  }

  static bool _isRefreshAction(Map<String, dynamic> action) {
    final verb = _verb(action);
    final id = (action['id'] ?? '').toString();
    return verb == 'refresh' || id == 'refresh';
  }

  Widget? _buildAction(
    BuildContext context,
    WidgetRef ref,
    LayoutScope scope,
    Map<String, dynamic> action, {
    required int index,
    required VoidCallback? focusDown,
    required VoidCallback? focusLeft,
    required VoidCallback? focusRight,
    required List<({String id, String label})> catalogOptions,
    required String? catalogPref,
    required String? horizonPref,
  }) {
    final verb = _verb(action);
    final id = (action['id'] ?? '').toString();
    final isRefresh = verb == 'refresh' || id == 'refresh';
    final isView = id == 'view' || verb == 'view' || verb == 'scheduleview';
    final isSchedule = id == 'horizon' || id == 'schedule' || id == 'time';
    final isCatalog = id == 'catalog' || action['dynamicCatalogs'] == true;

    if (verb == 'eventsearch' || verb == 'search') {
      final tooltip = (action['label'] ?? 'Search').toString().trim();
      final hint = (action['placeholder'] ?? action['hint'] ?? '').toString().trim();
      return KitListEventSearch(
        tabId: tabId,
        rowId: _widgetId,
        itemIndex: index,
        tooltip: tooltip.isEmpty ? 'Search' : tooltip,
        placeholder: hint.isEmpty ? 'Search…' : hint,
        onDownEdge: focusDown,
        onLeftEdge: focusLeft,
        onRightEdge: focusRight,
      );
    }

    final hostBuilder = KitTopBarHostHooks.packActionBuilders[verb] ??
        KitTopBarHostHooks.packActionBuilders[id];
    if (hostBuilder != null) {
      return hostBuilder(
        context,
        ref,
        action: action,
        tabId: tabId,
        rowId: _widgetId,
        itemIndex: index,
        onDownEdge: focusDown,
        onLeftEdge: focusLeft,
        onRightEdge: focusRight,
      );
    }

    final icon = _iconFor(action);
    final catalogLabel = KitTopBarHostHooks.catalogChipLabel;
    final catalogSelected = KitTopBarHostHooks.catalogChipSelected;

    if (isRefresh) {
      return ForjaActionChip(
        label: 'Refresh',
        icon: icon ?? Icons.refresh_rounded,
        iconOnly: true,
        selected: false,
        tvTabId: tabId,
        tvRowId: _widgetId,
        tvItemIndex: index,
        onDownEdge: focusDown ?? () {},
        onLeftEdge: focusLeft,
        onRightEdge: focusRight,
        onTap: () => onRefresh?.call(),
      );
    }

    if (isView) {
      final key = kitChromeKeyForTab(tabId);
      final override = key.isEmpty
          ? ''
          : ref.watch(kitListStyleOverrideProvider(key)).trim().toLowerCase();
      final isCards = override == 'cards';
      return ForjaActionChip(
        label: isCards ? 'Cards view' : 'List view',
        icon: isCards ? Icons.grid_view_rounded : Icons.view_list_rounded,
        iconOnly: true,
        selected: false,
        tvTabId: tabId,
        tvRowId: _widgetId,
        tvItemIndex: index,
        onDownEdge: focusDown ?? () {},
        onLeftEdge: focusLeft,
        onRightEdge: focusRight,
        onTap: () {
          if (key.isEmpty) return;
          ref.read(kitListStyleOverrideProvider(key).notifier).state =
              isCards ? 'list' : 'cards';
        },
      );
    }

    final String label;
    final bool selected;
    if (isSchedule) {
      final hookLabel = KitTopBarHostHooks.scheduleChipLabel;
      label = hookLabel != null
          ? hookLabel(horizonPref)
          : _horizonChipLabel(action, horizonPref, catalogOptions);
      final hookSelected = KitTopBarHostHooks.scheduleChipSelected;
      selected = hookSelected != null
          ? hookSelected(horizonPref)
          : (horizonPref != null &&
              horizonPref.isNotEmpty &&
              horizonPref != _packActionDefault(action));
    } else if (isCatalog && catalogLabel != null) {
      label = catalogLabel(catalogPref, catalogOptions);
      selected = catalogSelected?.call(catalogPref) ?? false;
    } else {
      label = _chipLabel(scope, action, catalogOptions: catalogOptions);
      selected = _isSelected(scope, action);
    }

    return ForjaActionChip(
      label: label,
      icon: icon,
      selected: selected,
      tvTabId: tabId,
      tvRowId: _widgetId,
      tvItemIndex: index,
      onDownEdge: focusDown ?? () {},
      onLeftEdge: focusLeft,
      onRightEdge: focusRight,
      onTap: () => unawaited(
        isSchedule
            ? _onSchedule(
                context,
                ref,
                scope,
                action: action,
                horizonPref: horizonPref,
                catalogOptions: catalogOptions,
              )
            : isCatalog
                ? _onCatalog(
                    context,
                    scope,
                    catalogOptions: catalogOptions,
                    catalogPref: catalogPref,
                  )
                : _onAction(
                    context,
                    ref,
                    scope,
                    action,
                    catalogOptions: catalogOptions,
                  ),
      ),
    );
  }

  String _horizonChipLabel(
    Map<String, dynamic> action,
    String? horizonPref,
    List<({String id, String label})> catalogOptions,
  ) {
    final items = _itemsFor(action, catalogOptions: catalogOptions);
    final pref = (horizonPref ?? '').trim().isNotEmpty
        ? horizonPref!.trim()
        : _packActionDefault(action);
    for (final item in items) {
      if (item.id == pref) return item.label;
    }
    return (action['label'] ?? 'Schedule').toString();
  }

  static String _packActionDefault(Map<String, dynamic> action) =>
      (action['default'] ?? '').toString().trim();

  String _chipLabel(
    LayoutScope scope,
    Map<String, dynamic> action, {
    required List<({String id, String label})> catalogOptions,
  }) {
    final id = (action['id'] ?? '').toString();
    final base = (action['label'] ?? id).toString();
    final items = _itemsFor(action, catalogOptions: catalogOptions);
    if (items.isEmpty) return base;
    final selected = scope.selectedId(id);
    if (selected == null || selected.isEmpty || selected == 'all') return base;
    for (final item in items) {
      if (item.id == selected) return '$base: ${item.label}';
    }
    return base;
  }

  bool _isSelected(LayoutScope scope, Map<String, dynamic> action) {
    final id = (action['id'] ?? '').toString();
    final selected = scope.selectedId(id);
    if (selected == null || selected.isEmpty || selected == 'all') return false;
    return true;
  }

  IconData? _iconFor(Map<String, dynamic> action) {
    final name = (action['icon'] ?? '').toString().trim().toLowerCase();
    return switch (name) {
      'refresh' => Icons.refresh_rounded,
      'search' => Icons.search,
      'filter' || 'catalog' => Icons.filter_list,
      'schedule' || 'time' || 'horizon' => Icons.schedule,
      'view' || 'list' => Icons.view_list_rounded,
      'cards' || 'grid' => Icons.grid_view_rounded,
      _ => null,
    };
  }

  List<({String id, String label, String? subtitle})> _itemsFor(
    Map<String, dynamic> action, {
    required List<({String id, String label})> catalogOptions,
  }) {
    final id = (action['id'] ?? '').toString();
    final staticItems = layoutItemsFromSpec(action);
    if (id == 'catalog' || action['dynamicCatalogs'] == true) {
      return [
        (id: 'all', label: 'All', subtitle: 'Every enabled catalog'),
        for (final c in catalogOptions)
          (id: c.id, label: c.label, subtitle: null),
        for (final s in staticItems)
          if (s.id != 'all' && !catalogOptions.any((c) => c.id == s.id))
            (id: s.id, label: s.label, subtitle: null),
      ];
    }
    return [
      for (final s in staticItems) (id: s.id, label: s.label, subtitle: null),
    ];
  }

  Future<void> _onCatalog(
    BuildContext context,
    LayoutScope scope, {
    required List<({String id, String label})> catalogOptions,
    required String? catalogPref,
  }) async {
    final items = _itemsFor(
      const {'id': 'catalog', 'dynamicCatalogs': true},
      catalogOptions: catalogOptions,
    );
    if (items.isEmpty) return;
    final current = (catalogPref ?? scope.selectedId('catalog') ?? 'all').trim();
    final opener = KitTopBarHostHooks.openCatalogSheet;
    final picked = opener != null
        ? await opener(
            context,
            current: current.isEmpty ? 'all' : current,
            options: items,
          )
        : await _genericPicker(
            context,
            title: 'Catalog',
            sheetId: 'catalog',
            current: current.isEmpty ? 'all' : current,
            items: items,
          );
    if (picked == null || !context.mounted) return;
    scope.onSelect('catalog', picked, toggle: false);
    final writer = KitTopBarHostHooks.writeCatalogFilter;
    if (writer != null) {
      await writer(context, picked, tabId: tabId);
    }
  }

  Future<void> _onSchedule(
    BuildContext context,
    WidgetRef ref,
    LayoutScope scope, {
    required Map<String, dynamic> action,
    required String? horizonPref,
    required List<({String id, String label})> catalogOptions,
  }) async {
    final current = ((horizonPref ?? '').trim().isNotEmpty
            ? horizonPref!.trim()
            : _packActionDefault(action))
        .trim();
    final opener = KitTopBarHostHooks.openScheduleSheet;
    if (opener != null) {
      await opener(
        context,
        currentPref:
            current.isEmpty ? 'airing|1h' : current,
        onChanged: (pref) {
          if (!context.mounted) return;
          scope.onSelect('horizon', pref, toggle: false);
          final key = kitChromeKeyForTab(tabId);
          if (key.isNotEmpty) {
            ref.read(kitFeedHorizonPrefProvider(key).notifier).state = pref;
          }
        },
      );
      return;
    }

    final items = _itemsFor(action, catalogOptions: catalogOptions);
    if (items.isEmpty) return;
    final picked = await _genericPicker(
      context,
      title: (action['label'] ?? 'Schedule').toString(),
      sheetId: 'horizon',
      current: current.isEmpty ? 'airing|1h' : current,
      items: items,
    );
    if (picked == null || !context.mounted) return;
    scope.onSelect('horizon', picked, toggle: false);
    final key = kitChromeKeyForTab(tabId);
    if (key.isNotEmpty) {
      ref.read(kitFeedHorizonPrefProvider(key).notifier).state = picked;
    }
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    LayoutScope scope,
    Map<String, dynamic> action, {
    required List<({String id, String label})> catalogOptions,
  }) async {
    final id = (action['id'] ?? '').toString();
    final verb = (action['action'] ?? '').toString().trim().toLowerCase();
    if (verb == 'refresh') {
      onRefresh?.call();
      return;
    }
    if (verb == 'search') return;

    final items = _itemsFor(action, catalogOptions: catalogOptions);
    if (items.isEmpty) return;

    final title = (action['label'] ?? id).toString();
    final picked = await _genericPicker(
      context,
      title: title,
      sheetId: id,
      current: scope.selectedId(id) ?? 'all',
      items: items,
    );
    if (picked == null || !context.mounted) return;
    scope.onSelect(id, picked, toggle: false);
    if (id == 'view' || verb == 'view') {
      final key = kitChromeKeyForTab(tabId);
      if (key.isNotEmpty) {
        ref.read(kitListStyleOverrideProvider(key).notifier).state = picked;
      }
    }
  }

  Future<String?> _genericPicker(
    BuildContext context, {
    required String title,
    required String sheetId,
    required String current,
    required List<({String id, String label, String? subtitle})> items,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: ForjaShellColors.surfaceElevated,
      isScrollControlled: true,
      builder: (ctx) {
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.7;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < items.length; i++)
                      KitFilterSheetOption(
                        label: items[i].label,
                        subtitle: items[i].subtitle,
                        selected: items[i].id == current ||
                            (current.isEmpty && items[i].id == 'all'),
                        icon: items[i].id == 'all'
                            ? Icons.grid_view_rounded
                            : Icons.tune_rounded,
                        onSelected: () => Navigator.pop(ctx, items[i].id),
                        tvTabId: 'kit_top_bar_sheet_$sheetId',
                        tvRowId: 'kit-sheet-$sheetId',
                        tvItemIndex: i,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KitTopBarCatalogProgressChip extends StatelessWidget {
  const _KitTopBarCatalogProgressChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final maxW = (MediaQuery.sizeOf(context).width * 0.42).clamp(160.0, 360.0);
    return ExcludeFocus(
      child: Tooltip(
        message: label,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxW),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ForjaShellColors.borderSubtle.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: ForjaShellColors.sectionAccent,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ForjaShellColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KitTopBarUpdatedLabel extends StatelessWidget {
  const _KitTopBarUpdatedLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: ForjaShellColors.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ===== kit_top_bar_host.dart =====

class PluginKitTopBar extends StatefulWidget {
  const PluginKitTopBar({super.key, required this.tabId});

  final String tabId;

  @override
  State<PluginKitTopBar> createState() => _PluginKitTopBarState();
}

class _PluginKitTopBarState extends State<PluginKitTopBar> {
  EnginePlugin? _plugin;

  @override
  void initState() {
    super.initState();
    SettingsService.navbarChangeNotifier.addListener(_onNavbarChanged);
    EngineService.changeNotifier.addListener(_onEngineChanged);
    _schedulePackFiltersLoad();
    PackFiltersRegistry.revision.addListener(_onFilters);
    KitTopMenuRegistry.revision.addListener(_onFilters);
  }

  @override
  void didUpdateWidget(covariant PluginKitTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabId == widget.tabId) return;
    _plugin = null;
    _schedulePackFiltersLoad();
  }

  void _schedulePackFiltersLoad() {
    final pluginId = PluginNavRegistry.pluginIdForTabSync(widget.tabId);
    if (pluginId == null) return;
    unawaited(_loadPluginAndFilters(pluginId));
  }

  Future<void> _loadPluginAndFilters(String pluginId) async {
    final found = await PluginRegistry.instance.findPlugin(pluginId);
    if (!mounted) return;
    if (PluginNavRegistry.pluginIdForTabSync(widget.tabId) != pluginId) {
      return;
    }
    setState(() => _plugin = found?.plugin);
    if (found?.plugin.hasCapability(PackCapabilities.filters) == true) {
      await PackFiltersRegistry.ensureLoaded(pluginId);
      if (!mounted) return;
      if (PluginNavRegistry.pluginIdForTabSync(widget.tabId) != pluginId) {
        return;
      }
      setState(() {});
    }
  }

  void _onNavbarChanged() {
    if (!mounted) return;
    if (_pluginForTab != null) return;
    _schedulePackFiltersLoad();
  }

  void _onEngineChanged() {
    if (!mounted) return;
    final pluginId = PluginNavRegistry.pluginIdForTabSync(widget.tabId);
    if (pluginId == null) return;
    PackFiltersRegistry.invalidate(pluginId);
    unawaited(_loadPluginAndFilters(pluginId));
  }

  @override
  void dispose() {
    SettingsService.navbarChangeNotifier.removeListener(_onNavbarChanged);
    EngineService.changeNotifier.removeListener(_onEngineChanged);
    PackFiltersRegistry.revision.removeListener(_onFilters);
    KitTopMenuRegistry.revision.removeListener(_onFilters);
    super.dispose();
  }

  void _onFilters() {
    if (mounted) setState(() {});
  }

  EnginePlugin? get _pluginForTab {
    final pluginId = PluginNavRegistry.pluginIdForTabSync(widget.tabId);
    if (pluginId == null || _plugin == null) return null;
    return _plugin!.id == pluginId ? _plugin : null;
  }

  bool _layoutOnlyHub(EnginePlugin? plugin) {
    if (plugin == null) return false;
    final caps = plugin.capabilities.map((c) => c.toLowerCase()).toSet();
    if (!caps.contains('nav') || !caps.contains('layout')) return false;
    const browse = {
      'rail',
      'feed',
      'search',
      'filters',
      'host_search',
      'structured_search',
      'details',
    };
    return caps.intersection(browse).isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (KitTopMenuRegistry.hasTopMenu(widget.tabId)) {
      return KitTopBar(tabId: widget.tabId);
    }
    return _buildBrowseTopBar(context);
  }

  Widget _buildBrowseTopBar(BuildContext context) {
    final pluginId = PluginNavRegistry.pluginIdForTabSync(widget.tabId);
    if (pluginId == null) return const SizedBox.shrink();
    final plugin = _pluginForTab;
    if (_layoutOnlyHub(plugin)) return const SizedBox.shrink();
    final canSearch =
        plugin?.hasCapability(PackCapabilities.search) ?? false;
    final canFilters =
        plugin?.hasCapability(PackCapabilities.filters) ?? false;
    final hasVerticalFilters =
        VerticalFiltersRegistry.specFor(widget.tabId) != null;
    if (!canSearch && !canFilters && !hasVerticalFilters) {
      return const SizedBox.shrink();
    }
    final label =
        PluginNavRegistry.destinations[widget.tabId]?.label ?? 'Search';
    final categories = PackFiltersRegistry.categoriesFor(pluginId);
    final menus = PackFiltersRegistry.menusFor(pluginId);
    final selectedMenu = ShellBus.hubSelectedMenuIdFor(widget.tabId);
    final currentMenu = selectedMenu.value;
    if (currentMenu != null &&
        PackFiltersRegistry.menuById(pluginId, currentMenu) == null) {
      selectedMenu.value = null;
    }
    return KitChromeTopBar(
      tabId: widget.tabId,
      selectedMenuId: selectedMenu,
      selectedCategoryId: ShellBus.hubSelectedCategoryIdFor(widget.tabId),
      menus: menus,
      categories: categories,
      scrollOffset: ShellBus.hubScrollOffsetFor(widget.tabId),
      heroHeight: ShellBus.hubHeroHeightFor(widget.tabId),
      onSearch: canSearch
          ? () {
              unawaited(
                openCatalogSearch(
                  context,
                  pluginId: pluginId,
                  tabId: widget.tabId,
                  hintText: 'Search $label…',
                ),
              );
            }
          : null,
    );
  }
}

// ===== kit_category_bar.dart =====

class KitCategoryBar extends ConsumerStatefulWidget {
  const KitCategoryBar({
    super.key,
    required this.tabId,
    required this.spec,
    this.pluginId = '',
    this.sortOrder = 0,
  });

  final String tabId;
  final Map<String, dynamic> spec;
  final String pluginId;
  final int sortOrder;

  @override
  ConsumerState<KitCategoryBar> createState() => _KitCategoryBarState();
}

class _KitCategoryBarState extends ConsumerState<KitCategoryBar> {
  KitListPage? _dynamicPage;

  String get _widgetId => (widget.spec['id'] ?? 'kind').toString();

  void _applyPage(KitListPage? page) {
    if (!mounted || identical(page, _dynamicPage)) return;
    setState(() => _dynamicPage = page);
  }

  @override
  Widget build(BuildContext context) {
    final scope = LayoutScope.of(context);
    final staticItems = layoutItemsFromSpec(widget.spec);
    final dynamic = widget.spec['dynamic'] == true;
    final sourceId = (widget.spec['source'] ?? '').toString().trim();

    final kindIcons = kitCategoryBarKindIcons(widget.spec);
    var kinds = <({String id, String label, String? icon})>[
      for (final i in staticItems)
        (id: i.id, label: i.label, icon: kindIcons[i.id.toLowerCase()]),
    ];

    if (dynamic) {
      final source = HostListRegistry.resolve(
        sourceId: sourceId.isEmpty ? null : sourceId,
        pluginId: widget.pluginId.isEmpty ? null : widget.pluginId,
      );
      if (source != null) {
        final status =
            scope.selectedId('status') ??
            widget.spec['defaultStatus']?.toString() ??
            'plantowatch';
        // Do not [watchPage] here — KitListWidget watches the same provider.
        // Dual watch flushes listeners mid-list-build → markNeedsBuild during build.
        source.listenPage(ref, status, (async) {
          // Keep last kinds during reload — null page collapses the bar and
          // the Expanded list jumps into that gap (cards flash over chrome).
          final page = async.asData?.value ?? async.valueOrNull;
          if (page == null) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _applyPage(page);
          });
        });
        final seedPage = source.readPage(ref, status);
        final seed = seedPage.asData?.value ?? seedPage.valueOrNull;
        if (_dynamicPage == null && seed != null) {
          _dynamicPage = seed;
        }
        final page = _dynamicPage;
        if (page != null) {
          final found = <String>{};
          for (final e in page.entriesForKind(null)) {
            final k = e.kind.trim();
            if (k.isEmpty || k == 'all' || k == 'live_match') continue;
            found.add(k);
          }
          final sorted = found.toList()..sort();
          final haveAll = kinds.any((i) => i.id == 'all');
          if (!haveAll) {
            kinds = [
              (
                id: 'all',
                label: 'All',
                icon: kindIcons['all'] ?? 'grid',
              ),
              ...kinds,
            ];
          }
          final existing = {for (final i in kinds) i.id};
          for (final id in sorted) {
            if (existing.contains(id)) continue;
            kinds.add((
              id: id,
              label: catalogKitCategoryLabel(id),
              icon: kindIcons[id.toLowerCase()],
            ));
          }
        }
      }
    }

    if (kinds.isEmpty) return const SizedBox.shrink();

    final selected = scope.selectedId(_widgetId) ??
        widget.spec['default']?.toString() ??
        kinds.first.id;
    final focusDownId = (widget.spec['focusDown'] ?? '').toString().trim();
    final focusUp = kitFocusEdge(
      widget.tabId,
      widget.spec['focusUp']?.toString(),
      last: true,
    );
    final focusLeft = kitFocusSide(widget.tabId, widget.spec['focusLeft']);
    final focusRight = kitFocusSide(widget.tabId, widget.spec['focusRight']);
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final resultsRowId =
        focusDownId.isEmpty ? '$_widgetId-results' : focusDownId;

    // Fixed chip size — never FittedBox/forTv shrink. Overflow → scroll.
    final layout = tvFocus
        ? ShellMoodCircleLayout.tvScrollable
        : ShellMoodCircleLayout.desktop;
    final hPad = EdgeInsets.only(
      left: ShellTokens.compactChromeLeadingInset(context),
      right: ShellTokens.bodyHorizontalPadding,
    );

    Widget circleAt(int i, {TvChipEdges? edges}) {
      final item = kinds[i];
      final meta = kitMoodCircleMeta(id: item.id, icon: item.icon);
      final on = selected == item.id;
      return ShellMoodCircleItem(
        layout: layout,
        label: catalogKitCategoryLabel(item.id, label: item.label),
        icon: meta.icon,
        accent: meta.accent,
        selected: on,
        listIndex: i,
        tvTabId: widget.tabId,
        tvRowId: _widgetId,
        onTap: () {
          if (!on) {
            scope.onSelect(_widgetId, item.id, toggle: false);
          } else if (tvFocus) {
            edges?.onSelectAlreadySelected();
          }
        },
        onLeftEdge: edges?.onLeft,
        onRightEdge: edges?.onRight,
        onDownEdge: edges?.onDown ??
            kitFocusEdge(widget.tabId, focusDownId, last: true),
        onUpEdge: focusUp ?? edges?.onUp,
      );
    }

    Widget centeredRow({TvChipEdges Function(int index)? edgesFor}) {
      return SizedBox(
        height: layout.rowHeight,
        width: double.infinity,
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < kinds.length; i++) ...[
                  if (i > 0) SizedBox(width: layout.horizontalGap),
                  circleAt(i, edges: edgesFor?.call(i)),
                ],
              ],
            ),
          ),
        ),
      );
    }

    Widget scrollStrip({TvChipEdges Function(int index)? edgesFor}) {
      return SizedBox(
        height: layout.rowHeight,
        child: HorizontalScroller(
          height: layout.rowHeight,
          padding: hPad,
          itemCount: kinds.length,
          separatorBuilder: (_, _) => SizedBox(width: layout.horizontalGap),
          itemBuilder: (context, i) =>
              circleAt(i, edges: edgesFor?.call(i)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final avail = (constraints.maxWidth - hPad.horizontal)
              .clamp(0.0, double.infinity);
          final fits = layout.contentWidth(kinds.length) <= avail;

          if (tvFocus) {
            return TvChipStrip(
              tabId: widget.tabId,
              rowId: _widgetId,
              sortOrder: widget.sortOrder,
              itemCount: kinds.length,
              resultsRowId: resultsRowId,
              onFocusLeft: focusLeft,
              onFocusRight: focusRight,
              builder: (context, edgesFor) => fits
                  ? Padding(padding: hPad, child: centeredRow(edgesFor: edgesFor))
                  : scrollStrip(edgesFor: edgesFor),
            );
          }

          if (fits) {
            return Padding(padding: hPad, child: centeredRow());
          }
          return scrollStrip();
        },
      ),
    );
  }
}

// ===== list_widget.dart =====
class KitListWidget extends ConsumerStatefulWidget {
  const KitListWidget({
    super.key,
    required this.tabId,
    required this.layoutSpec,
    required this.refreshEpoch,
    this.pluginId = '',
    this.tvRowOrder = 0,
    this.selectedEntryId,
    this.onEntrySelected,
    this.sidePanel,
    this.dynamicKindChips = false,
    this.onDynamicKinds,
    this.shellTabVisible = true,
    this.layoutWidgets = const [],
  });

  final String tabId;
  final Map<String, dynamic> layoutSpec;
  final int refreshEpoch;
  final String pluginId;
  final int tvRowOrder;

  final String? selectedEntryId;

  final ValueChanged<KitListEntry>? onEntrySelected;

  final Widget? sidePanel;

  final bool dynamicKindChips;

  final ValueChanged<List<String>>? onDynamicKinds;

  final bool shellTabVisible;

  final List<Map<String, dynamic>> layoutWidgets;

  String get listSource => (layoutSpec['source'] ?? '').toString().trim();
  String get kindMenuId =>
      (layoutSpec['kindMenu'] ?? layoutSpec['kindTab'] ?? 'kind').toString();
  String get statusTabId =>
      (layoutSpec['statusTab'] ?? 'status').toString();
  String get gridRowId => (layoutSpec['id'] ?? 'grid').toString();

  String? get focusLeftId {
    final raw = (layoutSpec['focusLeft'] ?? '').toString().trim();
    return raw.isEmpty ? null : raw;
  }

  String? get focusRightId {
    final raw = (layoutSpec['focusRight'] ?? '').toString().trim();
    return raw.isEmpty ? null : raw;
  }

  String get listStyle =>
      (layoutSpec['style'] ?? 'grid').toString().trim().toLowerCase();

  bool get isDenseList => listStyle == 'list';

  bool get isMatchCards => listStyle == 'cards';

  String get entryOpen =>
      (layoutSpec['open'] ?? '').toString().trim().toLowerCase();

  bool get opensDetails => entryOpen == 'details';

  bool get opensPanel =>
      entryOpen == 'panel' || (entryOpen.isEmpty && isDenseList);

  String? get openSettingId {
    final raw = (layoutSpec['openSetting'] ?? '').toString().trim();
    return raw.isEmpty ? null : raw;
  }

  @override
  ConsumerState<KitListWidget> createState() =>
      _KitListWidgetState();
}

class _KitListWidgetState extends ConsumerState<KitListWidget> {
  final _scroll = ScrollController();
  KitListSource? _source;
  KitListEntry? _selected;
  List<String> _dynamicKinds = const [];
  String? _kindFilter;
  bool _pendingOpenConsumed = false;

  String _effectiveStyle = 'grid';
  String _effectiveOpen = '';

  bool get _isDenseList => _effectiveStyle == 'list';
  bool get _isMatchCards => _effectiveStyle == 'cards';
  bool get _opensDetails => _effectiveOpen == 'details';
  bool get _opensPanel =>
      _effectiveOpen == 'panel' ||
      (_effectiveOpen.isEmpty && _isDenseList);

  void _resolveEffectiveLayout(WidgetRef ref) {
    final key = kitChromeKey(pluginId: widget.pluginId);
    final override = key.isEmpty
        ? ''
        : ref.watch(kitListStyleOverrideProvider(key)).trim().toLowerCase();
    _effectiveStyle = (override.isEmpty ? widget.listStyle : override)
        .trim()
        .toLowerCase();
    if (_effectiveStyle.isEmpty) _effectiveStyle = 'grid';

    final openSetting = widget.openSettingId;
    if (openSetting != null && widget.pluginId.trim().isNotEmpty) {
      final async = ref.watch(
        kitListOpenModeProvider((
          pluginId: widget.pluginId,
          fieldId: openSetting,
        )),
      );
      final fromPack = (async.asData?.value ?? widget.entryOpen)
          .trim()
          .toLowerCase();
      _effectiveOpen = fromPack.isEmpty ? kKitListOpenModeDefault : fromPack;
    } else {
      _effectiveOpen = widget.entryOpen;
    }

    if (_opensDetails && _selected != null) {
      _selected = null;
    }
  }

  KitListSource? _resolveSource() {
    final registered = HostListRegistry.resolve(
      sourceId: widget.listSource.isEmpty ? null : widget.listSource,
      pluginId: widget.pluginId.isEmpty ? null : widget.pluginId,
    );
    if (registered != null) return registered;
    final pluginId = widget.pluginId.trim();
    if (pluginId.isEmpty) return null;
    // Pack-owned list feed — no host product registration required.
    return PluginFeedSource(pluginId);
  }

  KitPanelHost? get _panelHost {
    final id = widget.listSource;
    if (id.isEmpty) return null;
    return HostListRegistry.resolvePanel(id);
  }

  bool get _autoPanel =>
      widget.sidePanel == null &&
      _panelHost != null &&
      _opensPanel;

  bool get _layoutHasCategoryBar {
    var found = false;
    walkLayoutWidgets(widget.layoutWidgets, (spec) {
      if (found) return;
      final type = LayoutTypes.normalize(
        (spec['type'] ?? '').toString(),
        spec,
      );
      if (type == LayoutTypes.categoryBar) found = true;
    });
    return found;
  }

  void _openEntry(BuildContext context, KitListSource source,
      KitListEntry entry) {
    widget.onEntrySelected?.call(entry);
    if (_opensDetails && _panelHost != null) {
      final layouts = widget.layoutWidgets.isNotEmpty
          ? widget.layoutWidgets
          : [widget.layoutSpec];
      unawaited(
        KitEntryDetailsPage.open(
          context,
          entry: entry,
          listSourceId: widget.listSource,
          layoutWidgets: layouts,
          refreshEpoch: widget.refreshEpoch,
          shellTabId: widget.tabId,
        ),
      );
      return;
    }
    if (_autoPanel) {
      setState(() => _selected = entry);
      _claimPanelProvidersFocus();
      return;
    }
    source.openEntry(context, entry);
  }

  void _openEntryWithChoice(
    BuildContext context,
    KitListSource source,
    KitListEntry entry,
  ) {
    // Side-panel / details hosts keep primary open; Open-with is list grids.
    if (_opensDetails || _autoPanel) {
      _openEntry(context, source, entry);
      return;
    }
    unawaited(source.openEntryWithChoice(context, entry));
  }

  void _claimPanelProvidersFocus() {
    if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) return;
    KitSourcesPanel.claimProvidersFocus();
  }

  VoidCallback? _packFocusLeft() =>
      kitFocusSide(widget.tabId, widget.focusLeftId);

  VoidCallback? _listRightEdge({
    required bool selected,
    required bool panelActive,
    required bool atRightColumn,
  }) {
    final named = kitFocusSide(widget.tabId, widget.focusRightId);
    if (named != null) {
      if (panelActive) return selected ? named : null;
      return atRightColumn ? named : null;
    }
    if (selected && panelActive) return _claimPanelProvidersFocus;
    return null;
  }

  void _focusSelectedEvent() {
    final handle =
        ShellTvFocusCoordinator.rowHandle(widget.tabId, widget.gridRowId);
    if (handle == null || handle.itemCount <= 0) return;
    final idx = handle.lastFocusedIndex.clamp(0, handle.itemCount - 1);
    ShellTvFocusCoordinator.focusRowItem(widget.tabId, widget.gridRowId, idx);
  }

  @override
  void initState() {
    super.initState();
    _source = _resolveSource();
    _syncScrollIntoView();
    TvHeroActions.bind(
      widget.tabId,
      defaultFocus: _defaultFocusNode,
      enterFromNavFocus: _focusEntry,
      restoreFocus: _landContentFocus,
    );
  }

  @override
  void didUpdateWidget(KitListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabId != oldWidget.tabId ||
        widget.gridRowId != oldWidget.gridRowId) {
      ShellTvFocusCoordinator.setRowScrollIntoView(
        oldWidget.tabId,
        oldWidget.gridRowId,
        null,
      );
      _syncScrollIntoView();
    }
    if (widget.listSource != oldWidget.listSource ||
        widget.pluginId != oldWidget.pluginId) {
      _source = _resolveSource();
    }
    if (widget.refreshEpoch != oldWidget.refreshEpoch) {
      // Invalidate after this frame — mutating providers in didUpdateWidget
      // throws and aborts the rebuild (Live Sports skeleton stutter).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _source?.invalidateOnRefresh(ref);
      });
    }
  }

  @override
  void dispose() {
    ShellTvFocusCoordinator.setRowScrollIntoView(
      widget.tabId,
      widget.gridRowId,
      null,
    );
    _scroll.dispose();
    ShellTvFocusCoordinator.clearTab(widget.tabId);
    super.dispose();
  }

  void _syncScrollIntoView() {
    ShellTvFocusCoordinator.setRowScrollIntoView(
      widget.tabId,
      widget.gridRowId,
      _scrollGridIndexIntoView,
    );
  }

  void _scrollGridIndexIntoView(int index) {
    if (!_scroll.hasClients || index < 0) return;
    final node = ShellTvFocusCoordinator.itemNode(
      widget.tabId,
      widget.gridRowId,
      index,
    );
    final ctx = node?.context;
    if (ctx != null && ctx.mounted) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.25,
        duration: Duration.zero,
      );
      return;
    }
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    final estExtent = _isDenseList
        ? 56.0
        : _isMatchCards
            ? 160.0
            : 220.0;
    final cols = _isDenseList
        ? 1
        : math.max(1, (_scroll.position.viewportDimension / 180).floor());
    final row = index ~/ cols;
    final target = (row * estExtent).clamp(0.0, max);
    if ((_scroll.offset - target).abs() > 1) {
      _scroll.jumpTo(target);
    }
  }

  bool _focusRow(String rowId, int index) =>
      ShellTvFocusCoordinator.focusRowItem(widget.tabId, rowId, index);

  bool _focusRowLast(String rowId) {
    final handle = ShellTvFocusCoordinator.rowHandle(widget.tabId, rowId);
    if (handle == null || handle.itemCount <= 0) return false;
    final idx = handle.lastFocusedIndex.clamp(0, handle.itemCount - 1);
    return _focusRow(rowId, idx);
  }

  bool _landContentFocus() {
    if (_focusRow(widget.kindMenuId, 0)) return true;
    if (_focusRow(widget.statusTabId, 0)) return true;
    return _focusRow(widget.gridRowId, 0);
  }

  FocusNode? _defaultFocusNode() {
    return ShellTvFocusCoordinator.itemNode(
          widget.tabId,
          widget.kindMenuId,
          0,
        ) ??
        ShellTvFocusCoordinator.itemNode(
          widget.tabId,
          widget.statusTabId,
          0,
        ) ??
        ShellTvFocusCoordinator.itemNode(
          widget.tabId,
          widget.gridRowId,
          0,
        );
  }

  double _hoistedTopBarInset(BuildContext context) {
    if (!KitTopMenuRegistry.hasTopMenu(widget.tabId)) return 0;
    return KitTopMenuRegistry.bodyTopInset(context, widget.tabId);
  }

  void _focusEntry() {
    if (_landContentFocus()) return;
    void retry({required int left}) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || ShellTvFocus.currentNavTabId != widget.tabId) return;
        if (_landContentFocus() || left <= 0) return;
        retry(left: left - 1);
      });
    }

    retry(left: 5);
  }

  @override
  Widget build(BuildContext context) {
    _resolveEffectiveLayout(ref);
    final source = _source;
    if (source == null) {
      final label = widget.listSource.isNotEmpty
          ? widget.listSource
          : (widget.pluginId.isNotEmpty ? widget.pluginId : '(none)');
      return Center(
        child: Text(
          'Unsupported kit.list source: $label',
          style: TextStyle(color: ForjaShellColors.textSecondary),
        ),
      );
    }

    final scope = LayoutScope.maybeOf(context);
    final status =
        scope?.selectedId(widget.statusTabId) ??
        widget.layoutSpec['defaultStatus']?.toString() ??
        'plantowatch';

    source.setupSideEffects(ref, status);
    final pageAsync = source.watchPage(ref, status);

    final catalogMenuId =
        (widget.layoutSpec['catalogMenu'] ?? 'catalog').toString();
    final horizonMenuId =
        (widget.layoutSpec['horizonMenu'] ?? 'horizon').toString();
    if (scope != null) {
      final filters = <String, String>{};
      final catalog = scope.selectedId(catalogMenuId);
      final horizon = scope.selectedId(horizonMenuId);
      if (catalog != null) filters['catalog'] = catalog;
      if (horizon != null) filters['horizon'] = horizon;
      // Kind/sport stays in layout scope only (entriesForKind) — no reload.
      if (filters.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          source.onLayoutFilters(ref, filters);
        });
      }
    }

    // Status / Simkl writes re-run the FutureProvider; keep the current grid
    // instead of swapping to the shimmer skeleton (feels like a full reload).
    return pageAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => _loadingGrid(context),
      error: (e, _) => Center(
        child: Text(
          e.toString(),
          style: TextStyle(color: ForjaShellColors.textSecondary),
        ),
      ),
      data: (page) {
        if (page.loadingRemote && page.totalCount == 0) {
          return _scheduleLoadingSkeleton(context);
        }
        final wantKinds =
            widget.dynamicKindChips ||
            widget.onDynamicKinds != null ||
            _autoPanel;
        if (wantKinds) {
          final kinds = <String>{};
          for (final e in page.entriesForKind(null)) {
            if (e.kind.isEmpty) continue;
            final omit = source.omitKindIds.contains(e.kind);
            if (!omit) kinds.add(e.kind);
          }
          final sorted = kinds.toList()..sort();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.onDynamicKinds?.call(sorted);
            if (!_sameStringList(sorted, _dynamicKinds)) {
              setState(() => _dynamicKinds = sorted);
            }
          });
        }
        final scopeKind = scope?.selectedId(widget.kindMenuId);
        final kind = scopeKind ?? _kindFilter;
        final chromeKey = kitChromeKey(pluginId: widget.pluginId);
        final eventQuery = chromeKey.isEmpty
            ? ''
            : ref.watch(kitListEventQueryProvider(chromeKey));
        final rawEntries = page.entriesForKind(kind);
        final entries = kitListFilterEntries(rawEntries, eventQuery);
        _consumePendingOpen(entries);
        if (entries.isEmpty) {
          return _emptyState(
            context,
            kind: kind,
            loadingRemote: page.loadingRemote,
            eventQuery: eventQuery,
          );
        }
        final selectedId = widget.selectedEntryId ?? _selected?.meta.id;
        final body = _isDenseList
            ? _denseList(context, source, entries, selectedId: selectedId)
            : _isMatchCards
                ? _matchCards(
                    context,
                    source,
                    entries,
                    selectedId: selectedId,
                  )
                : _grid(context, source, entries);
        final panel = widget.sidePanel ?? _buildAutoPanel();
        final sidePanelOpen = panel != null && _opensPanel;
        final wide = MediaQuery.sizeOf(context).width >= 900;
        final sideSplit = wide || ShellTokens.isAndroidTvDevice;
        final panelFlex = ShellTokens.isAndroidTvDevice ? 50 : 40;
        final listFlex = 100 - panelFlex;
        final chips = _dynamicKinds;
        final showChips =
            !_layoutHasCategoryBar && _autoPanel && chips.length > 1;
        return CatalogList(
          body: body,
          sidePanel: panel,
          sidePanelOpen: sidePanelOpen,
          sideSplit: sideSplit,
          listFlex: listFlex,
          panelFlex: panelFlex,
          panelWidth: MediaQuery.sizeOf(context).width * 0.92,
          onDismissSidePanel: () {
            if (!mounted) return;
            setState(() => _selected = null);
          },
          header: showChips
              ? ForjaChipRow(
                  tabId: widget.tabId,
                  rowId: widget.kindMenuId,
                  items: [
                    for (final id in ['all', ...chips])
                      (
                        id: id,
                        label: id == 'all'
                            ? 'All'
                            : (id.isEmpty
                                ? id
                                : '${id[0].toUpperCase()}${id.substring(1)}'),
                      ),
                  ],
                  selectedId: kind ?? 'all',
                  onSelect: (id) {
                    setState(() => _kindFilter = id == 'all' ? null : id);
                    scope?.onSelect(widget.kindMenuId, id, toggle: false);
                  },
                )
              : null,
        );
      },
    );
  }

  void _consumePendingOpen(List<KitListEntry> entries) {
    if (_pendingOpenConsumed || entries.isEmpty) return;
    final pending = _source?.takePendingSelectEntryId();
    if (pending == null || pending.isEmpty) {
      _pendingOpenConsumed = true;
      return;
    }
    KitListEntry? hit;
    for (final e in entries) {
      final id = e.meta.id;
      final openId = e.meta.open?.id ?? '';
      if (id == pending || openId == pending) {
        hit = e;
        break;
      }
    }
    _pendingOpenConsumed = true;
    if (hit == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
    if (_autoPanel) {
      setState(() => _selected = hit);
      widget.onEntrySelected?.call(hit!);
      _claimPanelProvidersFocus();
      return;
    }
      _openEntry(context, _source!, hit!);
    });
  }

  Widget? _buildAutoPanel() {
    if (!_autoPanel) return null;
    final entry = _selected;
    final host = _panelHost;
    if (entry == null || host == null) return null;
    final layouts = widget.layoutWidgets.isNotEmpty
        ? widget.layoutWidgets
        : [widget.layoutSpec];
    return host.buildSidePanel(
      context: context,
      entry: entry,
      layoutWidgets: layouts,
      shellTabVisible: widget.shellTabVisible,
      refreshEpoch: widget.refreshEpoch,
      onClosed: () => setState(() => _selected = null),
      onPanelLeftEdge: () => _focusSelectedEvent(),
    );
  }

  static bool _sameStringList(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Widget _denseList(
    BuildContext context,
    KitListSource source,
    List<KitListEntry> entries, {
    String? selectedId,
  }) {
    final leading = ShellTokens.compactChromeLeadingInset(context);
    final panelActive = widget.sidePanel != null || _autoPanel;
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    return CatalogDenseList(
      controller: _scroll,
      leading: leading,
      topPadding: 4 + _hoistedTopBarInset(context),
      trailing: ShellTokens.bodyHorizontalPadding,
      bottomPadding: shellTvKitScrollBottomGap(context),
      itemCount: entries.length,
      wrapScroll: (list) => TvGrid(
        tabId: widget.tabId,
        rowId: widget.gridRowId,
        sortOrder: widget.tvRowOrder + 2,
        columns: 1,
        itemCount: entries.length,
        onFocusUp: () =>
            _focusRowLast(widget.kindMenuId) ||
            _focusRow(widget.kindMenuId, 0),
        child: _kitListScrollbar(
          context,
          interactive: !tv,
          child: list,
        ),
      ),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final meta = entry.meta;
        final airing = meta.airing == true;
        final selected = selectedId != null && selectedId == meta.id;
        return KitEventDenseTile(
          title: meta.name,
          meta: kitEventDenseMetaLine(
            airing: airing,
            startsAt: meta.startsAt,
            badge: meta.badge,
            genres: meta.genres,
          ),
          airing: airing,
          viewers: KitListPaint.fromKitEntry(entry).viewers,
          selected: selected,
          index: index,
          playable: true,
          tvTabId: widget.tabId,
          tvRowId: widget.gridRowId,
          onUpEdge: index == 0
              ? () =>
                  _focusRowLast(widget.kindMenuId) ||
                  _focusRow(widget.kindMenuId, 0)
              : null,
          onLeftEdge: _packFocusLeft(),
          onRightEdge: _listRightEdge(
            selected: selected,
            panelActive: panelActive,
            atRightColumn: true,
          ),
          onTap: () => _openEntry(context, source, entry),
        );
      },
    );
  }

  Widget _matchCards(
    BuildContext context,
    KitListSource source,
    List<KitListEntry> entries, {
    String? selectedId,
  }) {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final panelActive = widget.sidePanel != null || _autoPanel;
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _eventCardsLayout(
          context,
          constraints.maxWidth,
          chromeTop: _hoistedTopBarInset(context),
        );
        return CatalogPosterGrid(
          layout: layout,
          controller: _scroll,
          itemCount: entries.length,
          useAspectRatio: false,
          bottomPadding: shellTvKitScrollBottomGap(context),
          wrapScroll: (grid) => TvGrid(
            tabId: widget.tabId,
            rowId: widget.gridRowId,
            sortOrder: widget.tvRowOrder + 2,
            columns: layout.columns,
            itemCount: entries.length,
            onFocusUp: () =>
                _focusRowLast(widget.kindMenuId) ||
                _focusRow(widget.kindMenuId, 0),
            child: _kitListScrollbar(
              context,
              interactive: !tv,
              child: grid,
            ),
          ),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final selected =
                selectedId != null && selectedId == entry.meta.id;
            return KitEventCard(
              event: KitListPaint.fromKitEntry(entry),
              width: layout.cardW,
              height: layout.cardH,
              gridIndex: index,
              gridColumns: layout.columns,
              selected: selected,
              tvTabId: widget.tabId,
              tvRowId: widget.gridRowId,
              onUpEdge: index < layout.columns
                  ? () =>
                      _focusRowLast(widget.kindMenuId) ||
                      _focusRow(widget.kindMenuId, 0)
                  : null,
              onLeftEdge: index % layout.columns == 0
                  ? _packFocusLeft()
                  : null,
              onRightEdge: _listRightEdge(
                selected: selected,
                panelActive: panelActive,
                atRightColumn: index % layout.columns ==
                        layout.columns - 1 ||
                    index == entries.length - 1,
              ),
              onTap: () => _openEntry(context, source, entry),
            );
          },
        );
      },
    );
  }

  Widget _kitListScrollbar(
    BuildContext context, {
    required bool interactive,
    required Widget child,
  }) {
    return RawScrollbar(
      controller: _scroll,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: interactive,
      thickness: 4,
      radius: const Radius.circular(2),
      mainAxisMargin: 6,
      crossAxisMargin: 2,
      thumbColor: ForjaShellColors.brandGreen.withValues(alpha: 0.55),
      trackColor: Colors.white.withValues(alpha: 0.08),
      trackBorderColor: Colors.transparent,
      child: child,
    );
  }

  Widget _grid(
    BuildContext context,
    KitListSource source,
    List<KitListEntry> entries,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _posterLayout(
          context,
          constraints.maxWidth,
          chromeTop: _hoistedTopBarInset(context),
        );
        return CatalogPosterGrid(
          layout: layout,
          controller: _scroll,
          itemCount: entries.length,
          bottomPadding: shellTvKitScrollBottomGap(context),
          wrapScroll: (grid) => TvGrid(
            tabId: widget.tabId,
            rowId: widget.gridRowId,
            sortOrder: widget.tvRowOrder + 2,
            columns: layout.columns,
            itemCount: entries.length,
            onFocusUp: () =>
                _focusRowLast(widget.statusTabId) ||
                _focusRow(widget.statusTabId, 0),
            child: grid,
          ),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Align(
              alignment: Alignment.topCenter,
              child: _card(context, source, entry, index, layout: layout),
            );
          },
        );
      },
    );
  }

  KitPosterCard _card(
    BuildContext context,
    KitListSource source,
    KitListEntry entry,
    int index, {
    required CatalogPosterGridLayout layout,
  }) {
    final meta = entry.meta;
    final status =
        LayoutScope.maybeOf(context)?.selectedId(widget.statusTabId) ??
        'plantowatch';
    return KitPosterCard(
      imageUrl: kitListPosterUrl(meta),
      title: meta.name,
      subtitle: kitPosterSubtitle(meta),
      rating: (meta.rating ?? 0) > 0 ? meta.rating : null,
      badge: kitPosterBadge(meta),
      listPin: source.buildEntryPin(context, entry, status),
      gridIndex: index,
      gridColumns: layout.columns,
      tvTabId: widget.tabId,
      tvRowId: widget.gridRowId,
      onUpEdge: index < layout.columns
          ? () =>
              _focusRowLast(widget.statusTabId) ||
              _focusRow(widget.statusTabId, 0)
          : null,
      onLeftEdge:
          index % layout.columns == 0 ? _packFocusLeft() : null,
      onRightEdge: _listRightEdge(
        selected: false,
        panelActive: false,
        atRightColumn: index % layout.columns == layout.columns - 1,
      ),
      onTap: () => _openEntry(context, source, entry),
      onLongPress: () => _openEntryWithChoice(context, source, entry),
    );
  }

  Widget _loadingGrid(BuildContext context) {
    if (_isDenseList || _isMatchCards) {
      return _scheduleLoadingSkeleton(context);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _posterLayout(
          context,
          constraints.maxWidth,
          chromeTop: _hoistedTopBarInset(context),
        );
        return CatalogPosterLoadingGrid(
          layout: layout,
          shimmer: homeLoadingShimmer,
          placeholder: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(
                shellCardBorderRadius(context),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _scheduleLoadingSkeleton(BuildContext context) {
    if (_isMatchCards) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final layout = _eventCardsLayout(
            context,
            constraints.maxWidth,
            chromeTop: _hoistedTopBarInset(context),
          );
          final rows = constraints.maxHeight.isFinite
              ? math.max(
                  1,
                  (constraints.maxHeight / (layout.cardH + layout.gap)).ceil(),
                )
              : 2;
          return CatalogPosterLoadingGrid(
            layout: layout,
            rowCount: rows.clamp(1, 4),
            shimmer: homeLoadingShimmer,
            placeholder: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(
                  shellCardBorderRadius(context),
                ),
              ),
            ),
          );
        },
      );
    }
    return CatalogScheduleDenseSkeleton(
      leading: ShellTokens.compactChromeLeadingInset(context),
      topPadding: 4 + _hoistedTopBarInset(context),
      trailing: ShellTokens.bodyHorizontalPadding,
      bottomPadding: shellTvKitScrollBottomGap(context),
      shimmer: homeLoadingShimmer,
    );
  }

  Widget _emptyState(
    BuildContext context, {
    String? kind,
    bool loadingRemote = false,
    String eventQuery = '',
  }) {
    if (loadingRemote) {
      return _scheduleLoadingSkeleton(context);
    }
    final searchQ = eventQuery.trim();
    final searching = searchQ.isNotEmpty;
    final filtered = kind != null && kind.isNotEmpty && kind != 'all';
    String? kindLabel;
    if (filtered) {
      final kindSpec =
          LayoutScope.maybeOf(context)?.widgetSpecFor(widget.kindMenuId);
      if (kindSpec != null) {
        for (final tab in layoutItemsFromSpec(kindSpec)) {
          if (tab.id == kind) kindLabel = tab.label;
        }
      }
    }
    final isLiveSchedule = _isDenseList || _isMatchCards;
    final title = searching
        ? 'No matches for “$searchQ”'
        : filtered && kindLabel != null
            ? 'Nothing in $kindLabel'
            : isLiveSchedule
                ? 'No matches'
                : 'Nothing in this list';
    final subtitle = searching
        ? 'Clear search or try another team / event name'
        : filtered
            ? 'Tap a kind tab again to show everything'
            : isLiveSchedule
                ? 'Try Catalog → All, a wider Schedule window, or Refresh'
                : 'Tap + on a title to set Plan to Watch / Watching / On Hold / Completed / Dropped';
    return CatalogListEmpty(
      topPadding: _hoistedTopBarInset(context),
      title: title,
      subtitle: subtitle,
      icon: searching
          ? Icons.search_off_rounded
          : isLiveSchedule
              ? Icons.sports_rounded
              : Icons.bookmark_border_rounded,
    );
  }
}

CatalogPosterGridLayout _eventCardsLayout(
  BuildContext context,
  double maxWidth, {
  double chromeTop = 0,
}) {
  return CatalogPosterGridLayout.eventCards(
    maxWidth: maxWidth,
    minW: KitEventCard.cardWidth(context),
    minH: KitEventCard.cardHeight(context),
    gap: KitEventCard.gridGap(context),
    pad: shellHomeSectionHorizontalPadding(context),
    chromeTop: chromeTop,
  );
}

CatalogPosterGridLayout _posterLayout(
  BuildContext context,
  double maxWidth, {
  double chromeTop = 0,
}) {
  return CatalogPosterGridLayout.poster(
    maxWidth: maxWidth,
    cardW: shellPosterCardWidth(context),
    cardH: shellPosterCardHeight(context),
    gap: shellPosterCardRowGap(context),
    leading: ShellTokens.compactChromeLeadingInset(context),
    trailing: ShellTokens.bodyHorizontalPadding,
    chromeTop: chromeTop,
  );
}

String kitListPosterUrl(MetaItem meta) {
  final poster = meta.poster;
  if (poster.isEmpty) return '';
  return resolveAbsoluteCoverUrl(poster);
}

// ===== cinematic_hero_interactive.dart =====

class HubHeroSlideExtras {
  const HubHeroSlideExtras({
    this.movie,
    this.listTarget,
    this.onOpenMovie,
  });

  final Movie? movie;
  final ListFollowTarget? listTarget;
  final Future<void> Function(Movie movie)? onOpenMovie;
}

class CinematicHeroInteractive extends StatefulWidget {
  const CinematicHeroInteractive({
    super.key,
    required this.slides,
    required this.layout,
    this.pageBottomChild,
    this.tvTabId = 'home',
    this.bleedRowId,
    this.scrollController,
    this.extrasById = const {},
    this.shimmer,
    this.height,
  });

  final List<CinematicHeroSlide> slides;
  final CinematicHeroLayout layout;
  final Widget? pageBottomChild;
  final String tvTabId;
  final String? bleedRowId;
  final ScrollController? scrollController;
  final Map<String, HubHeroSlideExtras> extrasById;
  final Widget? shimmer;
  final double? height;

  @override
  State<CinematicHeroInteractive> createState() =>
      _CinematicHeroInteractiveState();
}

class _CinematicHeroInteractiveState extends State<CinematicHeroInteractive> {
  final FocusNode _tvHeroPlayFocus = FocusNode(debugLabel: 'hero-play');
  final FocusNode _tvHeroGalleryFocus = FocusNode(debugLabel: 'hero-gallery');
  final GlobalKey<CinematicHeroState> _heroKey = GlobalKey<CinematicHeroState>();

  @override
  void initState() {
    super.initState();
    _syncSharedHeroFocusNodes();
    TvHeroActions.bind(
      widget.tvTabId,
      defaultFocus: () => _tvHeroPlayFocus,
      heroReveal: _scrollHeroIntoView,
    );
  }

  @override
  void dispose() {
    TvHeroActions.unbind(widget.tvTabId);
    if (ShellTvFocus.homeHeroPlay == _tvHeroPlayFocus) {
      ShellTvFocus.homeHeroPlay = null;
    }
    if (ShellTvFocus.homeHeroGallery == _tvHeroGalleryFocus) {
      ShellTvFocus.homeHeroGallery = null;
    }
    _disposeFocusNode(_tvHeroPlayFocus);
    _disposeFocusNode(_tvHeroGalleryFocus);
    super.dispose();
  }

  void _disposeFocusNode(FocusNode node) {
    if (node.hasFocus) {
      node.unfocus();
      scheduleMicrotask(node.dispose);
    } else {
      node.dispose();
    }
  }

  void _syncSharedHeroFocusNodes() {
    if (ShellTvFocus.currentNavTabId != widget.tvTabId) return;
    ShellTvFocus.homeHeroPlay = _tvHeroPlayFocus;
    ShellTvFocus.homeHeroGallery = _tvHeroGalleryFocus;
  }

  void _scrollHeroIntoView() {
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) return;
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _focusHomeHeroGallery() {
    ShellTvFocusCoordinator.revealHeroForTab(widget.tvTabId);
    ShellTvFocus.focusHomeHeroGallery();
  }

  void _focusHomeHeroMenu() {
    ShellTvFocusCoordinator.revealHeroForTab(widget.tvTabId);
    if (widget.tvTabId == 'home') {
      if (ShellTvFocus.focusHomeMenu()) return;
      ShellTvFocus.focusHomeSearch();
      return;
    }
    ShellTvFocus.focusHubHeroSearch();
  }

  void _focusBleedCatalogRow() {
    final rowId = widget.bleedRowId?.trim();
    if (rowId != null &&
        rowId.isNotEmpty &&
        ShellTvFocusCoordinator.focusRowItem(widget.tvTabId, rowId, 0)) {
      return;
    }
    ShellTvFocusCoordinator.focusFirstContentRow(widget.tvTabId);
  }

  void _revealedHeroPlayFocus() {
    void focusPlay() {
      if (!mounted) return;
      ShellTvFocus.focusHomeHeroPlay();
    }

    _scrollHeroIntoView();
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) {
      focusPlay();
      return;
    }
    controller
        .animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(focusPlay);
  }

  HubHeroSlideExtras? _extras(CinematicHeroSlide slide) =>
      widget.extrasById[slide.id];

  @override
  Widget build(BuildContext context) {
    _syncSharedHeroFocusNodes();
    final policy = ShellScope.inputPolicyOf(context);

    return CinematicHero(
      key: _heroKey,
      slides: widget.slides,
      layout: widget.layout,
      pageBottomChild: widget.pageBottomChild,
      height: widget.height,
      shimmer: widget.shimmer,
      upcomingNoticeBuilder: (context, slide) {
        if (!slide.isUpcoming) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: KitDetailsUpcomingNotice(
            releaseDateLabel: slide.upcomingReleaseLabel,
          ),
        );
      },
      galleryOverlayBuilder: policy.useFocusableMoodChips
          ? (context) {
              return IgnorePointer(
                ignoring: policy.scaleOnHover,
                child: shellFocusableTap(
                  context: context,
                  focusNode: _tvHeroGalleryFocus,
                  tvTabId: widget.tvTabId,
                  tvZone: ShellTvZone.hero,
                  scaleOnFocus: 1,
                  ensureVisibleMode: ShellPaintEnsureVisible.off,
                  onLeftEdge: () => _heroKey.currentState?.stepFilm(
                    -1,
                    instant: true,
                  ),
                  onRightEdge: () => _heroKey.currentState?.stepFilm(
                    1,
                    instant: true,
                  ),
                  onUpEdge: _focusHomeHeroMenu,
                  onDownEdge: _revealedHeroPlayFocus,
                  onTap: widget.slides.isEmpty
                      ? null
                      : () {
                          final i =
                              _heroKey.currentState?.heroIndex ?? 0;
                          final slide =
                              widget.slides[i % widget.slides.length];
                          final extras = _extras(slide);
                          if (extras?.movie != null &&
                              extras?.onOpenMovie != null) {
                            unawaited(extras!.onOpenMovie!(extras.movie!));
                          } else {
                            slide.onDetails?.call();
                          }
                        },
                  child: const SizedBox.expand(),
                ),
              );
            }
          : null,
      actionRowBuilder: (context, slide, {required isActive}) {
        return _buildActionRow(slide, isActive: isActive);
      },
    );
  }

  Widget _buildActionRow(CinematicHeroSlide slide, {required bool isActive}) {
    final metrics = ShellScope.metricsOf(context);
    final policy = ShellScope.inputPolicyOf(context);
    final tvNav = policy.useFocusableMoodChips;
    final focusable = isActive;
    final tabId = widget.tvTabId;
    final extras = _extras(slide);
    final hasListAction =
        extras?.movie != null || extras?.listTarget != null;
    final details = HeroPillPlayButton(
      label: 'View details',
      icon: Icons.info_outline_rounded,
      primary: false,
      alwaysShowLabel: true,
      focusNode:
          focusable && policy.heroPlayAutoFocus ? _tvHeroPlayFocus : null,
      tvTabId: focusable && tvNav ? tabId : null,
      tvRowId: focusable && tvNav ? MediaDetailsTv.heroRowId : null,
      tvItemIndex: focusable && tvNav ? 0 : null,
      onUpEdge: focusable && tvNav ? _focusHomeHeroGallery : null,
      onRightEdge: focusable && tvNav && !hasListAction
          ? () {
              ShellTvFocus.registerHeroLastMiniDoor(_tvHeroPlayFocus);
              ShellTvFocus.tryFocusMiniFromHeroLast();
            }
          : null,
      onKeyEvent: focusable && policy.heroPlayAutoFocus
          ? (node, event) {
              if (!shellTvIsNavigationKey(event)) {
                return KeyEventResult.ignored;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                if (ShellTvFocusCoordinator.focusActiveNavTab()) {
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            }
          : null,
      onTap: focusable
          ? () {
              if (extras?.movie != null && extras?.onOpenMovie != null) {
                unawaited(extras!.onOpenMovie!(extras.movie!));
              } else {
                slide.onDetails?.call();
              }
            }
          : null,
    );
    final listAction = extras?.movie != null
        ? BookmarkHeroStatusPill(
            movie: extras!.movie!,
            tvTabId: focusable && tvNav ? tabId : null,
            tvItemIndexStart: focusable && tvNav ? 1 : 0,
            onUpEdge: focusable && tvNav ? _focusHomeHeroGallery : null,
            onRightEdge: focusable && tvNav
                ? () {
                    ShellTvFocus.tryFocusMiniFromHeroLast();
                  }
                : null,
            enabled: focusable,
          )
        : extras?.listTarget != null
            ? KitListStatusHero(
                target: extras!.listTarget!,
                tvTabId: focusable && tvNav ? tabId : null,
                tvItemIndexStart: focusable && tvNav ? 1 : 0,
                onUpEdge: focusable && tvNav ? _focusHomeHeroGallery : null,
                enabled: focusable,
              )
            : null;
    final row = HeroPillActionRow(
      children: [
        if (tvNav)
          FocusTraversalOrder(order: const NumericFocusOrder(1), child: details)
        else
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
    if (!tvNav || !focusable) return body;
    return DetailsHeroTvActionScope(
      tabId: tabId,
      itemCount: listAction != null ? 2 : 1,
      onFocusUp: _focusHomeHeroGallery,
      onFocusDown:
          widget.pageBottomChild != null ? _focusBleedCatalogRow : null,
      child: body,
    );
  }
}

CinematicHeroLayout cinematicHeroLayoutOf(
  BuildContext context, {
  required bool compact,
  double? firstCatalogRowHeight,
  double topBarBleed = 0,
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
    sectionHorizontalPadding: shellHomeSectionHorizontalPadding(context),
    heroHeightFraction: shellHeroHeightFraction(context),
    heroMinHeight: shellHeroMinHeight(context),
    nextRowPeekFraction: shellHeroNextRowPeekFraction(context),
    rowSpacing: shellHomeRowSpacing(context),
    topBarBleed: topBarBleed,
    firstCatalogRowHeight: firstCatalogRowHeight ?? 0,
    scale: shellLayoutScale(context),
  );
}

// ===== cinematic_hero.dart =====

bool hubIsFullCinematicHero(BuildContext context) =>
    homeIsFullCinematicHero(context);

bool hubUsesShellLayout(BuildContext context) =>
    ShellScope.profileOf(context) != ShellProfile.mobile;

bool homeIsFullCinematicHero(BuildContext context) {
  if (ShellScope.metricsOf(context).usesTvDensity) return true;
  return MediaQuery.sizeOf(context).width >= ShellTokens.heroDesktopMinBodyWidth;
}

double homeHeroTextTopInset(BuildContext context) =>
    ShellTokens.heroTextColumnTopInsetDesktop;

class HomeHeroController {
  VoidCallback? revealPlayFocus;
}

class HubHeroSlide {
  const HubHeroSlide({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.overview = '',
    this.rating,
    this.year,
    this.badge,
    this.statusChip,
    this.upcomingReleaseLabel,
    this.isUpcoming = false,
    this.genres = const [],
    this.imageFit = BoxFit.cover,
    this.imageAlignment = Alignment.centerRight,
    this.logoUrl,
    this.tmdbId,
    this.tmdbMediaType = 'tv',
    this.matchTitle,
    this.movie,
    this.listTarget,
    required this.onDetails,
  });

  final String id;
  final String title;
  final String imageUrl;
  final String overview;
  final double? rating;
  final String? year;
  final String? badge;
  final String? statusChip;
  final String? upcomingReleaseLabel;
  final bool isUpcoming;
  final List<String> genres;
  final BoxFit imageFit;
  final Alignment imageAlignment;
  final String? logoUrl;
  final int? tmdbId;
  final String tmdbMediaType;
  final String? matchTitle;
  final Movie? movie;
  final ListFollowTarget? listTarget;
  final VoidCallback onDetails;

  CinematicHeroSlide toFoundationSlide() {
    return CinematicHeroSlide(
      id: id,
      title: title,
      backdropUrl: imageUrl,
      logoUrl: logoUrl,
      overview: overview,
      rating: rating,
      year: year,
      badge: badge,
      statusChip: statusChip,
      upcomingReleaseLabel: upcomingReleaseLabel,
      isUpcoming: isUpcoming,
      genres: genres,
      imageFit: imageFit,
      imageAlignment: imageAlignment,
      mediaType: movie?.mediaType ?? tmdbMediaType,
      onDetails: onDetails,
    );
  }
}

class HomeCinematicHero extends StatefulWidget {
  const HomeCinematicHero({
    super.key,
    required this.moviesFuture,
    required this.compact,
    required this.usesShellHomeLayout,
    required this.scrollController,
    required this.controller,
    required this.onOpenDetails,
    this.pageBottomChild,
    this.tvTabId = 'home',
    this.bleedRowId,
    this.firstCatalogRowHeight,
  }) : slides = null;

  const HomeCinematicHero.hub({
    super.key,
    required this.slides,
    this.pageBottomChild,
    this.tvTabId = 'anime',
    this.bleedRowId,
    this.firstCatalogRowHeight,
    this.scrollController,
  })  : moviesFuture = null,
        compact = false,
        usesShellHomeLayout = true,
        controller = null,
        onOpenDetails = null;

  final Future<List<Movie>>? moviesFuture;
  final List<HubHeroSlide>? slides;
  final bool compact;
  final bool usesShellHomeLayout;
  final ScrollController? scrollController;
  final HomeHeroController? controller;
  final Future<void> Function(Movie movie)? onOpenDetails;
  final String tvTabId;
  final String? bleedRowId;
  final double? firstCatalogRowHeight;
  final Widget? pageBottomChild;

  @override
  State<HomeCinematicHero> createState() => _HomeCinematicHeroState();
}

class _HomeCinematicHeroState extends State<HomeCinematicHero> {
  bool _heroHeightSyncScheduled = false;
  List<Movie>? _lastHeroMovies;

  static String _absArt(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    return resolveAbsoluteCoverUrl(s);
  }

  bool get _isHub => widget.slides != null;

  bool get _compact {
    if (_isHub) {
      if (ShellScope.metricsOf(context).usesTvDensity) return false;
      return MediaQuery.sizeOf(context).width <
          ShellTokens.heroDesktopMinBodyWidth;
    }
    return widget.compact;
  }

  @override
  void initState() {
    super.initState();
    if (!_isHub) {
      widget.controller?.revealPlayFocus = () {};
    }
  }

  ValueNotifier<double> _heroHeightNotifier() =>
      ShellBus.hubHeroHeightFor(widget.tvTabId);

  double _snapToDevicePixels(BuildContext context, double value) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (value * dpr).round() / dpr;
  }

  double _desktopTopBarBleed(BuildContext context) =>
      MediaQuery.paddingOf(context).top;

  double _firstCatalogRowHeight(BuildContext context) {
    return widget.firstCatalogRowHeight ??
        KitSection.sectionHeight(context, compactTop: true);
  }

  double _cinematicHeroHeight(BuildContext context, {required bool compact}) {
    final screenH = MediaQuery.sizeOf(context).height;
    final topBar = _desktopTopBarBleed(context);
    final firstRowHeight = _firstCatalogRowHeight(context);
    final nextRowPeek = KitSection.sectionHeight(context) *
        shellHeroNextRowPeekFraction(context);
    final reservedBelow =
        shellHomeRowSpacing(context) + firstRowHeight + nextRowPeek;
    final target = screenH * shellHeroHeightFraction(context);
    final maxHero = screenH - topBar - reservedBelow;
    return _snapToDevicePixels(
      context,
      mathMin(target, mathMax(shellHeroMinHeight(context), maxHero)),
    );
  }

  double mathMin(double a, double b) => a < b ? a : b;
  double mathMax(double a, double b) => a > b ? a : b;

  double _topBarHideAnchorHeight(
    BuildContext context, {
    required bool compact,
  }) {
    return _snapToDevicePixels(
      context,
      _cinematicHeroHeight(context, compact: compact) +
          _desktopTopBarBleed(context),
    );
  }

  void _publishHeroHeight() {
    if (_heroHeightSyncScheduled) return;
    _heroHeightSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _heroHeightSyncScheduled = false;
      if (!mounted) return;
      final height = _topBarHideAnchorHeight(
        context,
        compact: _isHub ? _compact : widget.compact,
      );
      final notifier = _heroHeightNotifier();
      if (notifier.value != height) {
        notifier.value = height;
      }
    });
  }

  // Pack / Movie art must already be absolute https — no host TmdbApi.

  List<CinematicHeroSlide> _hubFoundationSlides(List<HubHeroSlide> slides) {
    return [
      for (final s in slides)
        CinematicHeroSlide(
          id: s.id,
          title: s.title,
          backdropUrl: _absArt(s.imageUrl),
          logoUrl: _absArt(s.logoUrl ?? ''),
          overview: s.overview,
          rating: s.rating,
          year: s.year,
          badge: s.badge,
          statusChip: s.statusChip,
          upcomingReleaseLabel: s.upcomingReleaseLabel,
          isUpcoming: s.isUpcoming,
          genres: s.genres,
          imageFit: s.imageFit,
          imageAlignment: s.imageAlignment,
          mediaType: s.movie?.mediaType ?? s.tmdbMediaType,
          onDetails: s.onDetails,
        ),
    ];
  }

  Map<String, HubHeroSlideExtras> _hubExtras(List<HubHeroSlide> slides) {
    return {
      for (final s in slides)
        if (s.movie != null || s.listTarget != null)
          s.id: HubHeroSlideExtras(
            movie: s.movie,
            listTarget: s.listTarget,
            onOpenMovie: widget.onOpenDetails,
          ),
    };
  }

  List<CinematicHeroSlide> _movieFoundationSlides(List<Movie> movies) {
    return [
      for (final movie in movies)
        CinematicHeroSlide(
          id: '${movie.id}',
          title: movie.title,
          backdropUrl: _absArt(
            movie.backdropPath.isNotEmpty
                ? movie.backdropPath
                : movie.posterPath,
          ),
          logoUrl: _absArt(movie.logoPath),
          overview: movie.overview,
          rating: movie.voteAverage,
          year: movie.releaseDate,
          genres: movie.genres,
          mediaType: movie.mediaType,
          onDetails: () {
            final open = widget.onOpenDetails;
            if (open != null) unawaited(open(movie));
          },
        ),
    ];
  }

  Map<String, HubHeroSlideExtras> _movieExtras(List<Movie> movies) {
    return {
      for (final m in movies)
        '${m.id}': HubHeroSlideExtras(
          movie: m,
          onOpenMovie: widget.onOpenDetails,
        ),
    };
  }

  Widget _paint({
    required List<CinematicHeroSlide> slides,
    required Map<String, HubHeroSlideExtras> extras,
    required bool compact,
  }) {
    final topBarBleed = _desktopTopBarBleed(context);
    final layout = cinematicHeroLayoutOf(
      context,
      compact: compact,
      firstCatalogRowHeight: _firstCatalogRowHeight(context),
      topBarBleed: topBarBleed,
    );
    return CinematicHeroInteractive(
      slides: slides,
      layout: layout,
      pageBottomChild: widget.pageBottomChild,
      tvTabId: widget.tvTabId,
      bleedRowId: widget.bleedRowId,
      scrollController: widget.scrollController,
      extrasById: extras,
      shimmer: homeCinematicHeroShimmer(
        context,
        pageBottomBleed: widget.pageBottomChild != null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _publishHeroHeight();
    });

    if (_isHub) {
      final slides = widget.slides!;
      if (slides.isEmpty) {
        return homeCinematicHeroShimmer(
          context,
          pageBottomBleed: widget.pageBottomChild != null,
        );
      }
      return _paint(
        slides: _hubFoundationSlides(slides),
        extras: _hubExtras(slides),
        compact: _compact,
      );
    }

    return FutureBuilder<List<Movie>>(
      future: widget.moviesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          _lastHeroMovies = snapshot.data;
        }
        final movies = snapshot.data ?? _lastHeroMovies;
        if (movies == null) {
          return homeCinematicHeroShimmer(
            context,
            pageBottomBleed: widget.pageBottomChild != null,
          );
        }
        final shown = movies.take(5).toList();
        return _paint(
          slides: _movieFoundationSlides(shown),
          extras: _movieExtras(shown),
          compact: widget.compact,
        );
      },
    );
  }
}

typedef HubCinematicHero = HomeCinematicHero;

// ===== continue_widget.dart =====

class ContinueWidget extends StatefulWidget {
  const ContinueWidget({
    super.key,
    required this.pluginId,
    required this.tabId,
    this.mergeHomeWatchHistory = false,
    this.tvRowOrder = 1,
    this.tvFocusUp,
    this.prefetchSlot,
  });

  final String pluginId;
  final String tabId;
  final bool mergeHomeWatchHistory;
  final int tvRowOrder;
  final VoidCallback? tvFocusUp;
  final KitRowPrefetchSlot? prefetchSlot;

  @override
  State<ContinueWidget> createState() => _ContinueWidgetState();
}

class _ContinueWidgetState extends State<ContinueWidget> {
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _entries = const [];
  String? _resumingMetaId;
  bool _viewportActivated = false;
  StreamSubscription<List<Map<String, dynamic>>>? _homeHistorySub;

  @override
  void initState() {
    super.initState();
    _registerPrefetch();
    WatchHistory.revision.addListener(_onHistoryRevision);
    if (widget.mergeHomeWatchHistory) {
      _homeHistorySub = WatchHistoryService().historyStream.listen((_) {
        unawaited(_reload());
      });
    }
  }

  @override
  void didUpdateWidget(covariant ContinueWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.prefetchSlot != null) {
      _registerPrefetch();
    }
  }

  void _onHistoryRevision() => unawaited(_reload());

  void _onViewportVisible() => _activate(prefetch: false);

  void _registerPrefetch() {
    final slot = widget.prefetchSlot;
    if (slot == null) return;
    slot.lane.register(slot.index, () => _activate(prefetch: true));
  }

  void _activate({required bool prefetch}) {
    if (_viewportActivated) {
      if (!prefetch) widget.prefetchSlot?.notifyVisible();
      return;
    }
    setState(() => _viewportActivated = true);
    unawaited(_reload());
    widget.prefetchSlot?.notifyVisible();
  }

  @override
  void dispose() {
    WatchHistory.revision.removeListener(_onHistoryRevision);
    unawaited(_homeHistorySub?.cancel());
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final list = await catalogContinueEntries(
        widget.pluginId,
        mergeHomeWatchHistory: widget.mergeHomeWatchHistory,
      );
      if (!mounted) return;
      setState(() => _entries = list);
    } catch (_) {}
  }

  Future<void> _resume(Map<String, dynamic> entry) async {
    if (isHomeWatchHistoryEntry(entry)) {
      final home = entry['homeHistory'];
      if (home is! Map || _resumingMetaId != null) return;
      final metaId = entry['metaId']?.toString();
      if (metaId == null) return;
      setState(() => _resumingMetaId = metaId);
      try {
        await resumePlaybackFromHistory(
          context,
          Map<String, dynamic>.from(home),
        );
        if (mounted) await _reload();
      } catch (e) {
        if (mounted) ForjaToast.error('Resume failed: $e');
      } finally {
        if (mounted) setState(() => _resumingMetaId = null);
      }
      return;
    }

    final metaId = entry['metaId']?.toString();
    if (metaId == null || _resumingMetaId != null) return;
    final meta = WatchHistory.metaFromEntry(entry);
    if (meta == null) return;
    setState(() => _resumingMetaId = metaId);
    try {
      final epNum = (entry['episodeNumber'] as num?)?.toInt() ?? 1;
      final posMs = (entry['positionMs'] as num?)?.toInt() ?? 0;
      final durMs = (entry['durationMs'] as num?)?.toInt() ?? 0;
      Duration? startPosition;
      if (posMs > 5000 && canResumeFromSavedProgress(posMs, durMs)) {
        final clamped = (durMs > 0 && posMs > durMs - 30000)
            ? (durMs - 30000)
            : posMs;
        startPosition =
            Duration(milliseconds: (clamped - 3000).clamp(0, 1 << 31));
      }
      final extras = entry['extras'];
      final ctx = catalogPlayContextFromMeta(
        meta: meta,
        pluginId: widget.pluginId,
        episodeNumber: epNum,
        episodeVideoId: entry['episodeVideoId']?.toString(),
        extras: extras is Map
            ? Map<String, dynamic>.from(extras)
            : const {},
        startPosition: startPosition,
      );
      if (!mounted) return;
      await runPlayFromContext(context: context, ctx: ctx);
      if (mounted) await _reload();
    } catch (e) {
      if (mounted) ForjaToast.error('Resume failed: $e');
    } finally {
      if (mounted) setState(() => _resumingMetaId = null);
    }
  }

  Future<void> _openDetails(Map<String, dynamic> entry) async {
    if (isHomeWatchHistoryEntry(entry)) {
      final metaJson = entry['meta'];
      if (metaJson is! Map) return;
      final meta = MetaItem.fromJson(Map<String, dynamic>.from(metaJson));
      final home = entry['homeHistory'];
      final season = home is Map ? home['season'] as int? : null;
      final episode = home is Map ? home['episode'] as int? : null;
      await openMetaItem(
        context,
        pluginId: widget.pluginId,
        item: meta,
        initialSeason: season,
        initialEpisode: episode,
      );
      if (mounted) await _reload();
      return;
    }

    final meta = WatchHistory.metaFromEntry(entry);
    if (meta == null) return;
    await openMetaItem(
      context,
      pluginId: widget.pluginId,
      item: meta,
    );
    if (mounted) await _reload();
  }

  Future<void> _remove(Map<String, dynamic> entry) async {
    if (isHomeWatchHistoryEntry(entry)) {
      final id = entry['metaId']?.toString();
      if (id == null) return;
      await WatchHistoryService().removeItem(id);
      if (mounted) await _reload();
      return;
    }

    final id = entry['metaId']?.toString();
    if (id == null) return;
    await WatchHistory.remove(widget.pluginId, id);
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return KitLazyViewportGate(
      detectorKey: ValueKey('continue:${widget.tabId}'),
      placeholderHeight: KitSection.sectionHeight(
        context,
        cardAspect: KitPosterAspect.landscape,
      ),
      prefetchSlot: widget.prefetchSlot,
      onVisible: _onViewportVisible,
      builder: (_) {
        if (_entries.isEmpty) return const SizedBox.shrink();
        final showArrows = ShellScope.inputPolicyOf(context).scaleOnHover;
        return TvKitRow(
          tabId: widget.tabId,
          rowId: 'continue-watching',
          sortOrder: widget.tvRowOrder,
          itemCount: _entries.length,
          onFocusUp: widget.tvFocusUp,
          child: ContinueSection(
            scrollController: _scroll,
            showScrollArrows: showArrows,
            cardWidth: shellContinueWatchingCardWidth(context),
            cardHeight: shellContinueWatchingCardHeight(context),
            titlePadding: EdgeInsets.fromLTRB(
              24,
              shellSectionTitleTopCompact(context),
              24,
              16,
            ),
            rail: SizedBox(
              height: shellContinueWatchingCardHeight(context),
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: ListView.separated(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.sizeOf(context).width < 380
                        ? 14.0
                        : 24.0,
                  ),
                  itemCount: _entries.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (_, i) {
                    return FocusTraversalOrder(
                      order: NumericFocusOrder(i.toDouble()),
                      child: HostContinueWatchingCard(
                        tabId: widget.tabId,
                        listIndex: i,
                        entry: _entries[i],
                        isLoading: _resumingMetaId != null &&
                            _entries[i]['metaId']?.toString() ==
                                _resumingMetaId,
                        onTap: () => _resume(_entries[i]),
                        onRemove: () => _remove(_entries[i]),
                        onInfo: () => unawaited(_openDetails(_entries[i])),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ===== because_section.dart =====
class BecauseSection extends StatefulWidget {
  const BecauseSection({
    super.key,
    required this.pluginId,
    required this.tabId,
    required this.spec,
    this.tvHeaderRowOrder = 0,
    this.tvRowOrder = 0,
    this.prefetchSlot,
  });

  final String pluginId;
  final String tabId;
  final Map<String, dynamic> spec;
  final int tvHeaderRowOrder;
  final int tvRowOrder;
  final KitRowPrefetchSlot? prefetchSlot;

  @override
  State<BecauseSection> createState() => _BecauseSectionState();
}

class _BecauseSectionState extends State<BecauseSection> {
  Future<_BecausePayload>? _future;
  int _shuffleKey = 0;
  int _epoch = 0;
  bool _viewportActivated = false;
  bool _shuffleHovered = false;
  final FocusNode _shuffleFocusNode = FocusNode(debugLabel: 'because-shuffle');

  @override
  void initState() {
    super.initState();
    _registerPrefetch();
    WatchHistory.revision.addListener(_onHistoryRevision);
    _shuffleFocusNode.addListener(_onShuffleFocusChanged);
  }

  void _onShuffleFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onHistoryRevision() {
    if (_viewportActivated) _reload();
  }

  void _onViewportVisible() {
    _activate(prefetch: false);
  }

  void _registerPrefetch() {
    final slot = widget.prefetchSlot;
    if (slot == null) return;
    slot.lane.register(slot.index, () => _activate(prefetch: true));
  }

  void _activate({required bool prefetch}) {
    if (_viewportActivated) {
      if (!prefetch) widget.prefetchSlot?.notifyVisible();
      return;
    }
    setState(() => _viewportActivated = true);
    _reload();
    widget.prefetchSlot?.notifyVisible();
  }

  @override
  void dispose() {
    WatchHistory.revision.removeListener(_onHistoryRevision);
    _shuffleFocusNode.removeListener(_onShuffleFocusChanged);
    _shuffleFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BecauseSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.prefetchSlot != null) {
      _registerPrefetch();
    }
    if (oldWidget.spec != widget.spec ||
        oldWidget.pluginId != widget.pluginId ||
        oldWidget.tabId != widget.tabId) {
      _reload();
    }
  }

  void _reload() {
    final epoch = ++_epoch;
    setState(() {
      _future = _load().then((payload) {
        if (!mounted || epoch != _epoch) return const _BecausePayload.empty();
        return payload;
      });
    });
  }

  Future<_BecausePayload> _load() async {
    final rawParams = widget.spec['params'];
    final params = <String, dynamic>{
      if (rawParams is Map) ...Map<String, dynamic>.from(rawParams),
      'rail': (widget.spec['rail'] ?? 'because').toString(),
      'shuffleKey': _shuffleKey,
      'resumeSeeds': await catalogResumeSeeds(widget.pluginId),
    };
    final envelope = await MetaRuntime.instance.run(
      pluginId: widget.pluginId,
      action: (widget.spec['action'] ?? 'rail').toString().trim(),
      params: catalogParamsWithFilters(
        params,
        filters: catalogChromeFilters(
          tabId: widget.tabId,
          pluginId: widget.pluginId,
        ),
      ),
    );
    if (!envelope.ok) return const _BecausePayload.empty();
    final data = envelope.data ?? const {};
    return _BecausePayload(
      heading: (data['heading'] ?? widget.spec['title'] ?? '').toString(),
      seedPoster: (data['seedPoster'] ?? '').toString(),
      canShuffle: data['canShuffle'] == true,
      items: envelope.items,
    );
  }

  void _shuffle() {
    setState(() => _shuffleKey++);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return KitLazyViewportGate(
      detectorKey: ValueKey('because:${widget.tabId}:${widget.spec['id']}'),
      placeholderHeight: KitSection.sectionHeight(context),
      prefetchSlot: widget.prefetchSlot,
      onVisible: _onViewportVisible,
      builder: (_) => FutureBuilder<_BecausePayload>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return homeLoadingShimmer(homePosterRowSkeleton(context));
          }
          final payload = snap.data ?? const _BecausePayload.empty();
          if (payload.items.isEmpty) return const SizedBox.shrink();

          final rowId = (widget.spec['id'] ?? 'because').toString();
          final headerRowId = '${rowId}_header';
          final seedTitle = _becauseSeedTitle(payload.heading);
          final shuffleActive = _shuffleHovered || _shuffleFocusNode.hasFocus;

          Widget? shuffle;
          if (payload.canShuffle) {
            final cardsLast = ShellTvFocusCoordinator.rowHandle(
                  widget.tabId,
                  rowId,
                )?.lastFocusedIndex ??
                0;
            shuffle = MouseRegion(
              onEnter: (_) => setState(() => _shuffleHovered = true),
              onExit: (_) => setState(() => _shuffleHovered = false),
              child: shellFocusableTap(
                context: context,
                focusNode: _shuffleFocusNode,
                borderRadius: 20,
                scaleOnFocus: 1.0,
                onTap: _shuffle,
                onDownEdge: () => ShellTvFocusCoordinator.focusRowItem(
                  widget.tabId,
                  rowId,
                  cardsLast,
                ),
                tvTabId: widget.tabId,
                tvRowId: headerRowId,
                tvZone: ShellTvZone.row,
                tvItemIndex: 0,
                child: AnimatedScale(
                  scale: shuffleActive ? 1.08 : 1.0,
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: shuffleActive
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.transparent,
                      ),
                      child: Icon(
                        Icons.shuffle_rounded,
                        size: 24,
                        color: shuffleActive
                            ? Colors.white
                            : ForjaShellColors.iconMuted,
                      ),
                    ),
                  ),
                ),
              ),
            );
            shuffle = TvKitRow(
              tabId: widget.tabId,
              rowId: headerRowId,
              sortOrder: widget.tvHeaderRowOrder,
              itemCount: 1,
              child: shuffle,
            );
          }

          return ds.BecauseSection(
            becauseTitle: seedTitle,
            seedPosterUrl: payload.seedPoster,
            titlePadding: shellSectionTitlePadding(context),
            trailing: shuffle,
            rail: KitSection<MetaItem>(
              title: '',
              items: payload.items,
              embedded: true,
              compactTop: true,
              tvTabId: widget.tabId,
              tvRowId: rowId,
              tvRowOrder: widget.tvRowOrder,
              cardBuilder: (context, item, index) => KitPosterCard(
                imageUrl: item.poster,
                title: item.name,
                subtitle: kitPosterSubtitle(item),
                rating: item.rating,
                listIndex: index,
                tvTabId: widget.tabId,
                tvRowId: rowId,
                onTap: () => unawaited(
                  openMetaItem(
                    context,
                    pluginId: widget.pluginId,
                    item: item,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _becauseSeedTitle(String heading) {
  const prefix = 'Because you watched ';
  final trimmed = heading.trim();
  if (trimmed.startsWith(prefix)) {
    return trimmed.substring(prefix.length).trim();
  }
  return trimmed;
}

class _BecausePayload {
  const _BecausePayload({
    required this.heading,
    required this.seedPoster,
    required this.canShuffle,
    required this.items,
  });

  const _BecausePayload.empty()
      : heading = '',
        seedPoster = '',
        canShuffle = false,
        items = const [];

  final String heading;
  final String seedPoster;
  final bool canShuffle;
  final List<MetaItem> items;
}
