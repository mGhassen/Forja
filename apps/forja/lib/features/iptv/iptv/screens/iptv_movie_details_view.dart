import 'package:flutter/material.dart';
import 'package:forja/features/iptv/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/iptv_title_clean.dart';
import 'package:forja/features/iptv/iptv/iptv_tmdb_enrichment.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_details_meta.dart';
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

/// Cinematic IPTV movie details — same shell as home / Asian Drama details.
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

  IptvTmdbEnrichment? _enrich;
  bool _tmdbLoading = false;
  bool _playing = false;
  bool _heroFocusDone = false;
  String? _loadedForKey;

  IptvController get ctrl => widget.ctrl;

  IptvCleanedTitle get _cleaned {
    final name = ctrl.activeMovie?.name ?? '';
    return cleanIptvMediaTitle(name);
  }

  Movie? get _movie => _enrich?.rich.movie;

  String get _displayTitle {
    final tmdbTitle = _movie?.title.trim() ?? '';
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
      defaultFocus: () => _heroPlayFocus,
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
    _schedulePlayFocus();
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
    _loadTmdb();
  }

  Future<void> _loadTmdb() async {
    final movie = ctrl.activeMovie;
    if (movie == null || _tmdbLoading) return;
    final key = '${movie.streamId}|${movie.name}';
    if (_loadedForKey == key) return;
    _tmdbLoading = true;
    final hit = await loadIptvTmdbEnrichment(
      rawTitle: movie.name,
      preferMovie: true,
    );
    if (!mounted) return;
    setState(() {
      _enrich = hit;
      _loadedForKey = key;
      _tmdbLoading = false;
    });
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
    return ctrl.activeMovie?.icon.trim() ?? '';
  }

  List<String> _heroBackdropUrls() {
    final primary = _backdropUrl();
    final icon = ctrl.activeMovie?.icon.trim() ?? '';
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

  String _overview() => _movie?.overview.trim() ?? '';

  List<String> _metaParts() {
    final parts = <String>[];
    final date = _movie?.releaseDate.trim() ?? '';
    if (date.length >= 4) {
      parts.add(date.substring(0, 4));
    } else if (_cleaned.year != null) {
      parts.add('${_cleaned.year}');
    }
    final cert = _enrich?.rich.extras.certification.trim() ?? '';
    if (cert.isNotEmpty) parts.add(cert);
    final runtime = _movie?.runtime ?? 0;
    if (runtime > 0) parts.add('${runtime}m');
    return parts;
  }

  List<MapEntry<String, String>> _facts() {
    final year = _cleaned.year ??
        (_movie != null && (_movie!.releaseDate.length >= 4)
            ? int.tryParse(_movie!.releaseDate.substring(0, 4))
            : null);
    final runtime = _movie?.runtime ?? 0;
    final portal = ctrl.activePortal?.displayLabel.trim() ?? '';
    return iptvTmdbFacts(
      _enrich?.rich,
      base: [
        if (year != null) MapEntry('Year', '$year'),
        if (runtime > 0) MapEntry('Runtime', '${runtime}m'),
        if (portal.isNotEmpty) MapEntry('Portal', portal),
      ],
    );
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

  void _schedulePlayFocus({int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
      if (!tv) return;
      if (_heroPlayFocus.canRequestFocus) {
        _heroPlayFocus.requestFocus();
        _heroFocusDone = true;
        if (!_heroPlayFocus.hasFocus && attempt < 10) {
          _schedulePlayFocus(attempt: attempt + 1);
        }
        return;
      }
      if (attempt < 10) _schedulePlayFocus(attempt: attempt + 1);
    });
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
        (_movie?.voteAverage ?? 0) > 0 ? _movie!.voteAverage : null;
    final heroHeight = DetailsTokens.heroHeight(context);
    final heroFocusUp = tvFocus ? _focusBack : null;
    final sections = buildIptvDetailsMetaSections(
      context: context,
      rich: _enrich?.rich,
      tvFocus: tvFocus,
      tvTabId: 'iptv',
      tvRowOrderBase: 0,
      tvFocusUp: () {
        if (_heroPlayFocus.canRequestFocus) {
          _heroPlayFocus.requestFocus();
        } else {
          heroFocusUp?.call();
        }
      },
    );

    if (tvFocus && !_heroFocusDone) {
      _schedulePlayFocus();
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MediaDetailsScrollPage(
            scrollController: _scroll,
            bodyOverlap: 0,
            backgroundColor: AppTheme.bgDark,
            sections: sections,
            hero: HubDetailsHero(
              backdropUrl: backdrop,
              backdropUrls: heroBackdrops,
              title: _displayTitle,
              genres: _movie?.genres ?? const [],
              metaParts: _metaParts(),
              rating: rating,
              overview: _overview(),
              facts: _facts(),
              height: heroHeight,
              actionRow: DetailsHeroTvActionScope(
                tabId: 'iptv',
                itemCount: 1,
                onFocusUp: heroFocusUp,
                onFocusDown: sections.isNotEmpty ? _focusFirstMetaRow : null,
                child: HubDetailsPlayRow(
                  label: _playing ? 'Opening…' : 'Play',
                  enabled: !_playing,
                  onPlay: _play,
                  focusNode: tvFocus ? _heroPlayFocus : null,
                  autoFocus: tvFocus,
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

  void _focusFirstMetaRow() {
    ShellTvFocusCoordinator.focusRowItem('iptv', 'cast', 0) ||
        ShellTvFocusCoordinator.focusRowItem('iptv', 'crew', 0) ||
        ShellTvFocusCoordinator.focusRowItem('iptv', 'trailers', 0) ||
        ShellTvFocusCoordinator.focusRowItem('iptv', 'recommendations', 0);
  }
}
