import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/engine/lists/list_follow.dart';
import 'package:forja/shared/player/details/kit_details_play_row.dart'
    show KitDetailsUpcomingNotice, DetailsHeroTvActionScope;
import 'package:forja/shared/player/details/kit_list_status_button.dart'
    show BookmarkHeroStatusPill;
import 'package:forja/shared/player/details/kit_list_status_hero.dart';
import 'package:forja/shared/shell/desktop_selectable_title.dart';
import 'package:forja/shared/shell/forja_shell_layout.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja/shared/shell/hero_pill_buttons.dart';
import 'package:forja/shared/shell/shell_focusable_tap.dart';
import 'package:forja/shared/shell/tv/media_details_tv_scope.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/shell/tv/shell_tv_focus.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/widgets/catalog/cinematic_hero.dart';
import 'package:rust/rust.dart';

/// Host extras for a cinematic slide (list pin / Movie open).
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

/// TV / focus / Interactive wrapper around foundation [CinematicHero].
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
                  ensureVisibleMode: ShellTvEnsureVisibleMode.off,
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

/// Map [ShellScope] → foundation layout props.
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
