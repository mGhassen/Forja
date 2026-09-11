import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/engine/lists/list_follow.dart';
import 'package:forja/shared/shell/cinematic_hero_interactive.dart';
import 'package:forja/shared/shell/forja_shell_layout.dart';
import 'package:forja/shared/shell/forja_shell_profile.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja/shared/shell/home_loading_skeleton.dart';
import 'package:forja/shared/shell/kit_section.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/utils/cover_urls.dart';
import 'package:forja_foundation/widgets/catalog/cinematic_hero.dart';
import 'package:rust/rust.dart';

export 'package:forja_foundation/widgets/catalog/cinematic_hero.dart'
    show
        CinematicHero,
        CinematicHeroSlide,
        CinematicHeroLayout,
        CinematicHeroState,
        cinematicHeroIsFullBleed;
export 'package:forja/shared/shell/cinematic_hero_interactive.dart'
    show
        CinematicHeroInteractive,
        HubHeroSlideExtras,
        cinematicHeroLayoutOf;

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

/// Bridges TV focus from catalog rows back to the hero details button.
class HomeHeroController {
  VoidCallback? revealPlayFocus;
}

/// Host slide — absolute URLs + optional Movie / list pin extras.
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

/// Shared cinematic hero — Home / hub. Paint in foundation; TV in interactive.
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
