import 'package:flutter/material.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_tmdb_match.dart';
import 'package:forja/features/iptv/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/iptv_title_clean.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/hero/rotating_hero_backdrop.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_hero.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_play_row.dart';
import 'package:forja/shared/widgets/media_details/media_details_scroll_page.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:rust/rust.dart';

/// Cinematic IPTV movie details — same shell as series / Asian Drama details.
class IptvMovieDetailsView extends StatefulWidget {
  const IptvMovieDetailsView({super.key, required this.ctrl});

  final IptvController ctrl;

  @override
  State<IptvMovieDetailsView> createState() => _IptvMovieDetailsViewState();
}

class _IptvMovieDetailsViewState extends State<IptvMovieDetailsView> {
  final _scroll = ScrollController();
  final _backFocus = FocusNode(debugLabel: 'iptv-movie-back');
  final _heroPlayFocus = FocusNode(debugLabel: 'iptv-movie-play');

  Movie? _tmdb;
  bool _tmdbLoading = false;
  bool _playing = false;
  bool _heroFocusDone = false;

  IptvController get ctrl => widget.ctrl;

  IptvCleanedTitle get _cleaned {
    final name = ctrl.activeMovie?.name ?? '';
    return cleanIptvMediaTitle(name);
  }

  String get _displayTitle {
    final tmdbTitle = _tmdb?.title.trim() ?? '';
    if (tmdbTitle.isNotEmpty) return tmdbTitle;
    final cleaned = _cleaned.title;
    if (cleaned.isNotEmpty) return cleaned;
    return ctrl.activeMovie?.name ?? 'Movie';
  }

  @override
  void initState() {
    super.initState();
    ctrl.addListener(_onCtrl);
    TvHeroActions.bind(
      'iptv',
      pageBack: () {
        ctrl.back();
        return true;
      },
      restoreFocus: () {
        if (_heroPlayFocus.canRequestFocus) {
          _heroPlayFocus.requestFocus();
          return true;
        }
        return false;
      },
    );
    ShellTvFocusCoordinator.registerDetailBackFocus(_backFocus);
    _loadTmdb();
  }

  @override
  void dispose() {
    ShellTvFocusCoordinator.unregisterDetailBackFocus(_backFocus);
    ctrl.removeListener(_onCtrl);
    _scroll.dispose();
    _backFocus.dispose();
    _heroPlayFocus.dispose();
    super.dispose();
  }

  void _onCtrl() {
    if (!mounted) return;
    setState(() {});
    if (_tmdb == null && !_tmdbLoading && ctrl.activeMovie != null) {
      _loadTmdb();
    }
  }

  Future<void> _loadTmdb() async {
    final movie = ctrl.activeMovie;
    if (movie == null || _tmdbLoading) return;
    final cleaned = cleanIptvMediaTitle(movie.name);
    if (cleaned.isEmpty) return;
    _tmdbLoading = true;
    final hit = await KissKhTmdbMatch.resolve(
      title: cleaned.title,
      year: cleaned.year?.toString(),
      kissKhType: 'movie',
    );
    if (!mounted) return;
    setState(() {
      _tmdb = hit;
      _tmdbLoading = false;
    });
  }

  String _backdropUrl() {
    final path = _tmdb?.backdropPath.trim() ?? '';
    if (path.isNotEmpty) {
      return path.startsWith('http') ? path : TmdbApi.getBackdropUrl(path);
    }
    final poster = _tmdb?.posterPath.trim() ?? '';
    if (poster.isNotEmpty) {
      return poster.startsWith('http') ? poster : TmdbApi.getImageUrl(poster);
    }
    return ctrl.activeMovie?.icon.trim() ?? '';
  }

  List<String> _heroBackdropUrls() {
    final primary = _backdropUrl();
    final icon = ctrl.activeMovie?.icon.trim() ?? '';
    return RotatingHeroBackdrop.normalizeUrls([
      if (primary.isNotEmpty) primary,
      if (icon.isNotEmpty && icon != primary) icon,
    ]);
  }

  String _overview() => _tmdb?.overview.trim() ?? '';

  List<String> _metaParts() {
    final parts = <String>[];
    final date = _tmdb?.releaseDate.trim() ?? '';
    if (date.length >= 4) {
      parts.add(date.substring(0, 4));
    } else if (_cleaned.year != null) {
      parts.add('${_cleaned.year}');
    }
    final runtime = _tmdb?.runtime ?? 0;
    if (runtime > 0) parts.add('${runtime}m');
    return parts;
  }

  List<MapEntry<String, String>> _facts() {
    final facts = <MapEntry<String, String>>[];
    final year = _cleaned.year ??
        (_tmdb != null && (_tmdb!.releaseDate.length >= 4)
            ? int.tryParse(_tmdb!.releaseDate.substring(0, 4))
            : null);
    if (year != null) facts.add(MapEntry('Year', '$year'));
    final runtime = _tmdb?.runtime ?? 0;
    if (runtime > 0) facts.add(MapEntry('Runtime', '${runtime}m'));
    final portal = ctrl.activePortal?.displayLabel.trim() ?? '';
    if (portal.isNotEmpty) facts.add(MapEntry('Portal', portal));
    return facts;
  }

  Future<void> _play() async {
    final movie = ctrl.activeMovie;
    final p = ctrl.activePortal;
    if (movie == null || p == null || _playing) return;
    setState(() => _playing = true);
    try {
      final url = await IptvClient.resolvePlayUrl(
        p.portal,
        movie,
        section: movie.kind,
      );
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        ForjaToast.error('Could not open stream');
        return;
      }
      ctrl.noteBrowserSearchPlayedStream(movie);
      await pushShellRoute(
        context,
        AppRouter.slideShellRoute(
          (_) => IptvPtPlayerScreen.singleStream(
            url: url,
            stream: movie,
            portalName: p.displayLabel,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  void _focusBack() {
    if (_backFocus.canRequestFocus) _backFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final movie = ctrl.activeMovie;
    final policy = ShellScope.inputPolicyOf(context);
    final tvFocus = policy.useFocusableMoodChips;

    if (movie == null) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Stack(
          children: [
            const Center(
              child: Text(
                'No movie selected',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            MediaDetailsBackButton(
              focusNode: _backFocus,
              onPressed: ctrl.back,
            ),
          ],
        ),
      );
    }

    final backdrop = _backdropUrl();
    final heroBackdrops = _heroBackdropUrls();
    final rating =
        (_tmdb?.voteAverage ?? 0) > 0 ? _tmdb!.voteAverage : null;
    final heroHeight = DetailsTokens.heroHeight(context);

    if (tvFocus && policy.heroPlayAutoFocus && !_heroFocusDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _heroFocusDone) return;
        if (_heroPlayFocus.canRequestFocus) {
          _heroPlayFocus.requestFocus();
          _heroFocusDone = true;
        }
      });
    }

    final heroFocusUp = tvFocus ? _focusBack : null;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MediaDetailsScrollPage(
            scrollController: _scroll,
            bodyOverlap: 0,
            backgroundColor: AppTheme.bgDark,
            sections: const [],
            hero: HubDetailsHero(
              backdropUrl: backdrop,
              backdropUrls: heroBackdrops,
              title: _displayTitle,
              genres: _tmdb?.genres ?? const [],
              metaParts: _metaParts(),
              rating: rating,
              overview: _overview(),
              facts: _facts(),
              height: heroHeight,
              actionRow: DetailsHeroTvActionScope(
                tabId: 'iptv',
                itemCount: 1,
                onFocusUp: heroFocusUp,
                child: HubDetailsPlayRow(
                  label: _playing ? 'Opening…' : 'Play',
                  enabled: !_playing,
                  onPlay: _play,
                  focusNode:
                      policy.heroPlayAutoFocus ? _heroPlayFocus : null,
                  onUpEdge: heroFocusUp,
                  tvTabId: tvFocus ? 'iptv' : null,
                  tvItemIndex: 0,
                ),
              ),
            ),
          ),
          MediaDetailsBackButton(
            focusNode: _backFocus,
            onPressed: ctrl.back,
          ),
        ],
      ),
    );
  }
}
