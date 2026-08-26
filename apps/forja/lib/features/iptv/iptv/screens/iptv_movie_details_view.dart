import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/iptv_catalog_recs.dart';
import 'package:forja/features/iptv/iptv/iptv_title_clean.dart';
import 'package:forja/features/iptv/iptv/iptv_tmdb_enrichment.dart';
import 'package:forja/features/iptv/iptv/providers/iptv_controller_provider.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_details_meta.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_series_details_view.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/hero/rotating_hero_backdrop.dart';
import 'package:forja/shared/widgets/hero/tmdb_paint_gate.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_hero.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_play_row.dart';
import 'package:forja/shared/widgets/media_details/media_details_scroll_page.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:rust/rust.dart';

Future<T?> openIptvMovieDetails<T>(
  BuildContext context, {
  required IptvStream movie,
  required VerifiedPortal portal,
}) {
  return pushShellRoute<T>(
    context,
    AppRouter.slideShellRoute(
      (_) => IptvMovieDetailsScreen(movie: movie, portal: portal),
      settings: const RouteSettings(name: 'iptv_movie_details'),
    ),
  );
}

/// IPTV movie details — same TV focus / scroll stack as Home details.
class IptvMovieDetailsScreen extends ConsumerStatefulWidget {
  const IptvMovieDetailsScreen({
    super.key,
    required this.movie,
    required this.portal,
  });

  final IptvStream movie;
  final VerifiedPortal portal;

  @override
  ConsumerState<IptvMovieDetailsScreen> createState() =>
      _IptvMovieDetailsScreenState();
}

class _IptvMovieDetailsScreenState
    extends ConsumerState<IptvMovieDetailsScreen> {
  final _scroll = ScrollController();
  final _backFocus = FocusNode(debugLabel: 'iptv-movie-back');
  final _heroPlayFocus = FocusNode(debugLabel: 'iptv-movie-play');

  IptvTmdbEnrichment? _enrich;
  List<IptvCatalogRecHit> _catalogRecs = const [];
  bool _playing = false;
  bool _heroFocusDone = false;

  IptvCleanedTitle get _cleaned => cleanIptvMediaTitle(widget.movie.name);

  Movie? get _movie => _enrich?.rich.movie;

  String get _displayTitle {
    final cleaned = _cleaned.title;
    if (cleaned.isNotEmpty) return cleaned;
    return widget.movie.name;
  }

  @override
  void initState() {
    super.initState();
    _loadTmdb();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _backFocus.dispose();
    _heroPlayFocus.dispose();
    super.dispose();
  }

  Future<void> _loadTmdb() async {
    final hit = await loadIptvTmdbEnrichment(
      rawTitle: widget.movie.name,
      preferMovie: true,
    );
    if (!mounted) return;
    setState(() => _enrich = hit);

    try {
      final catalog = await ref
          .read(iptvControllerProvider)
          .vodSeriesCatalog(widget.portal.key);
      if (!mounted) return;
      final recs = filterIptvCatalogRecommendations(
        recommendations: hit?.rich.extras.recommendations ?? const [],
        catalog: catalog,
        excludeStreamId: widget.movie.streamId,
      );
      if (!mounted) return;
      setState(() => _catalogRecs = recs);
    } catch (_) {
      // Enrichment already painted; catalog recs are optional.
    }
  }

  void _revealedDetailsHeroPlayFocus() {
    void focusPlay() {
      if (!mounted) return;
      if (_heroPlayFocus.canRequestFocus) _heroPlayFocus.requestFocus();
    }

    if (!_scroll.hasClients) {
      focusPlay();
      return;
    }
    _scroll
        .animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(focusPlay);
  }

  void _focusDetailsBack() {
    if (!_backFocus.canRequestFocus) {
      MediaDetailsBackButton.popDetails(context);
      return;
    }
    _backFocus.requestFocus();
  }

  String _backdropUrl() {
    final path = _movie?.backdropPath.trim() ?? '';
    if (path.isNotEmpty) {
      return path.startsWith('http') ? path : TmdbApi.getBackdropUrl(path);
    }
    final poster = _movie?.posterPath.trim() ?? '';
    if (poster.isNotEmpty) {
      return poster.startsWith('http') ? poster : TmdbApi.getImageUrl(poster);
    }
    return widget.movie.icon.trim();
  }

  String? _logoUrl() {
    final path = _movie?.logoPath.trim() ?? '';
    if (path.isEmpty) return null;
    return path.startsWith('http') ? path : TmdbApi.getImageUrl(path);
  }

  List<String> _heroBackdropUrls() {
    final primary = _backdropUrl();
    final icon = widget.movie.icon.trim();
    final shots = _movie?.screenshots ?? const <String>[];
    return RotatingHeroBackdrop.normalizeUrls([
      if (primary.isNotEmpty) primary,
      for (final raw in shots)
        if (raw.trim().isNotEmpty)
          raw.trim().startsWith('http')
              ? raw.trim()
              : TmdbApi.getBackdropUrl(raw.trim()),
      if (icon.isNotEmpty && icon != primary) icon,
    ]);
  }

  List<String> _metaParts({bool tmdbChrome = true}) {
    final parts = <String>[];
    final date = tmdbChrome ? (_movie?.releaseDate.trim() ?? '') : '';
    if (date.length >= 4) {
      parts.add(date.substring(0, 4));
    } else if (_cleaned.year != null) {
      parts.add('${_cleaned.year}');
    }
    final cert = tmdbChrome
        ? (_enrich?.rich.extras.certification.trim() ?? '')
        : '';
    if (cert.isNotEmpty) parts.add(cert);
    final runtime = tmdbChrome ? (_movie?.runtime ?? 0) : 0;
    if (runtime > 0) parts.add('${runtime}m');
    return parts;
  }

  List<MapEntry<String, String>> _facts({bool tmdbChrome = true}) {
    final year = _cleaned.year ??
        (_movie != null && (_movie!.releaseDate.length >= 4)
            ? int.tryParse(_movie!.releaseDate.substring(0, 4))
            : null);
    final runtime = _movie?.runtime ?? 0;
    final portal = widget.portal.displayLabel.trim();
    return iptvTmdbFacts(
      tmdbChrome ? _enrich?.rich : null,
      preferTv: false,
      fallback: iptvPortalFacts(
        year: year,
        runtimeMinutes: runtime,
        portal: portal,
      ),
    );
  }

  Future<void> _play() async {
    if (_playing) return;
    setState(() => _playing = true);
    try {
      final url = await IptvClient.resolvePlayUrl(
        widget.portal.portal,
        widget.movie,
        section: widget.movie.kind,
      );
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        ForjaToast.error('Could not open stream');
        return;
      }
      await IptvPtPlayerScreen.open(
        context,
        IptvPtPlayerScreen.singleStream(
          url: url,
          stream: widget.movie,
          portalName: widget.portal.displayLabel,
          portalPlatform: widget.portal.portal.platform,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _playing = false);
        if (_scroll.hasClients) _scroll.jumpTo(0);
        ShellTvFocusCoordinator.claimHeroPlayAfterPlayerExit(
          _heroPlayFocus,
          isMounted: () => mounted,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final tvFocus = policy.useFocusableMoodChips;
    final heroFocusUp = _revealedDetailsHeroPlayFocus;
    final heroPopUp = tvFocus ? _focusDetailsBack : null;

    if (tvFocus && policy.heroPlayAutoFocus && !_heroFocusDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _heroFocusDone) return;
        if (_heroPlayFocus.context == null || !_heroPlayFocus.canRequestFocus) {
          return;
        }
        _heroPlayFocus.requestFocus();
        _heroFocusDone = true;
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          TmdbPaintGate(
            ready: _enrich != null,
            builder: (context, level) {
              final icon = widget.movie.icon.trim();
              final backdrop = level.hasArt ? _backdropUrl() : icon;
              final heroBackdrops = level.hasArt
                  ? _heroBackdropUrls()
                  : RotatingHeroBackdrop.normalizeUrls(
                      [if (icon.isNotEmpty) icon],
                    );
              final rating = level.hasChrome && (_movie?.voteAverage ?? 0) > 0
                  ? _movie!.voteAverage
                  : null;
              final heroHeight = DetailsTokens.heroHeight(context);
              final sections = level.hasRows
                  ? buildIptvDetailsMetaSections(
                      context: context,
                      rich: _enrich?.rich,
                      catalogRecommendations: _catalogRecs,
                      onCatalogRecTap: (hit) {
                        if (hit.stream.kind == 'series') {
                          openIptvSeriesDetails(
                            context,
                            series: hit.stream,
                            portal: widget.portal,
                          );
                        } else {
                          openIptvMovieDetails(
                            context,
                            movie: hit.stream,
                            portal: widget.portal,
                          );
                        }
                      },
                      tvFocus: tvFocus,
                      tvTabId: MediaDetailsTv.tabId,
                      tvRowOrderBase: 0,
                      tvFocusUp: heroFocusUp,
                    )
                  : const <Widget>[];
              return MediaDetailsScrollPage(
                scrollController: _scroll,
                tvHeroPlayFocus: _heroPlayFocus,
                tvBackFocus: _backFocus,
                bodyOverlap: 0,
                backgroundColor: AppTheme.bgDark,
                sections: sections,
                hero: HubDetailsHero(
                  backdropUrl: backdrop,
                  backdropUrls: heroBackdrops,
                  title: _displayTitle,
                  genres: level.hasChrome
                      ? (_movie?.genres ?? const [])
                      : const [],
                  metaParts: _metaParts(tmdbChrome: level.hasChrome),
                  rating: rating,
                  overview: level.hasChrome
                      ? (_movie?.overview.trim() ?? '')
                      : '',
                  facts: _facts(tmdbChrome: level.hasChrome),
                  logoUrl: level.hasChrome ? _logoUrl() : null,
                  height: heroHeight,
                  actionRow: DetailsHeroTvActionScope(
                    tabId: MediaDetailsTv.tabId,
                    itemCount: 1,
                    onFocusUp: heroPopUp,
                    child: HubDetailsPlayRow(
                      label: _playing ? 'Opening…' : 'Play',
                      enabled: !_playing,
                      onPlay: _play,
                      focusNode:
                          policy.heroPlayAutoFocus ? _heroPlayFocus : null,
                      onUpEdge: heroPopUp,
                      tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                      tvItemIndex: 0,
                    ),
                  ),
                ),
              );
            },
          ),
          MediaDetailsBackButton(focusNode: _backFocus),
        ],
      ),
    );
  }
}
