import 'package:flutter/material.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_tmdb_match.dart';
import 'package:forja/features/iptv/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/iptv_title_clean.dart';
import 'package:forja/features/iptv/iptv/iptv_tv_focus.dart';
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
import 'package:forja/shared/widgets/media_details_body.dart';
import 'package:forja/shared/widgets/tv_season_episode_picker.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:rust/rust.dart';

/// Cinematic IPTV series details — same shell as movie / Asian Drama details.
class IptvSeriesDetailsView extends StatefulWidget {
  const IptvSeriesDetailsView({super.key, required this.ctrl});

  final IptvController ctrl;

  @override
  State<IptvSeriesDetailsView> createState() => _IptvSeriesDetailsViewState();
}

class _IptvSeriesDetailsViewState extends State<IptvSeriesDetailsView> {
  final _scroll = ScrollController();
  final _backFocus = FocusNode(debugLabel: 'iptv-series-back');
  final _heroPlayFocus = FocusNode(debugLabel: 'iptv-series-play');

  Movie? _tmdb;
  bool _tmdbLoading = false;
  int _selectedSeasonIndex = 1;
  int _selectedEpisode = 1;
  bool _heroFocusDone = false;

  IptvController get ctrl => widget.ctrl;

  List<int> get _seasons {
    final keys = <int>{};
    for (final e in ctrl.episodes) {
      keys.add(e.season);
    }
    final list = keys.toList()..sort();
    return list;
  }

  /// Picker season index (1..N) → portal season number.
  int _portalSeason(int pickerSeason) {
    final seasons = _seasons;
    if (seasons.isEmpty) return pickerSeason;
    final i = (pickerSeason - 1).clamp(0, seasons.length - 1);
    return seasons[i];
  }

  int get _pickerSeasonCount => _seasons.isEmpty ? 0 : _seasons.length;

  IptvCleanedTitle get _cleaned {
    final name = ctrl.activeSeries?.name ?? '';
    return cleanIptvMediaTitle(name);
  }

  String get _displayTitle {
    final tmdbTitle = _tmdb?.title.trim() ?? '';
    if (tmdbTitle.isNotEmpty) return tmdbTitle;
    final cleaned = _cleaned.title;
    if (cleaned.isNotEmpty) return cleaned;
    return ctrl.activeSeries?.name ?? 'Series';
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
        return iptvFocusRowItem('episodes', 0) ||
            iptvFocusRowItem('seasons', 0);
      },
    );
    ShellTvFocusCoordinator.registerDetailBackFocus(_backFocus);
    _syncSelectionFromEpisodes();
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
    _syncSelectionFromEpisodes();
    setState(() {});
    if (_tmdb == null && !_tmdbLoading && ctrl.activeSeries != null) {
      _loadTmdb();
    }
  }

  void _syncSelectionFromEpisodes() {
    final seasons = _seasons;
    if (seasons.isEmpty) return;
    if (_selectedSeasonIndex > seasons.length) {
      _selectedSeasonIndex = 1;
    }
    final eps = _episodesForPickerSeason(_selectedSeasonIndex);
    if (eps.isEmpty) {
      _selectedEpisode = 1;
      return;
    }
    final has = eps.any((e) => e.episode == _selectedEpisode);
    if (!has) _selectedEpisode = eps.first.episode;
  }

  List<IptvEpisode> _episodesForPickerSeason(int pickerSeason) {
    final portalSeason = _portalSeason(pickerSeason);
    final list = ctrl.episodes.where((e) => e.season == portalSeason).toList()
      ..sort((a, b) => a.episode.compareTo(b.episode));
    return list;
  }

  IptvEpisode? _episodeAt(int pickerSeason, int episodeNum) {
    for (final e in _episodesForPickerSeason(pickerSeason)) {
      if (e.episode == episodeNum) return e;
    }
    return null;
  }

  Future<void> _loadTmdb() async {
    final series = ctrl.activeSeries;
    if (series == null || _tmdbLoading) return;
    final cleaned = cleanIptvMediaTitle(series.name);
    if (cleaned.isEmpty) return;
    _tmdbLoading = true;
    final hit = await KissKhTmdbMatch.resolve(
      title: cleaned.title,
      year: cleaned.year?.toString(),
      kissKhType: 'tv',
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
    final icon = ctrl.activeSeries?.icon.trim() ?? '';
    return icon;
  }

  List<String> _heroBackdropUrls() {
    final primary = _backdropUrl();
    final poster = ctrl.activeSeries?.icon.trim() ?? '';
    return RotatingHeroBackdrop.normalizeUrls([
      if (primary.isNotEmpty) primary,
      if (poster.isNotEmpty && poster != primary) poster,
    ]);
  }

  String _overview() {
    final tmdb = _tmdb?.overview.trim() ?? '';
    if (tmdb.isNotEmpty) return tmdb;
    for (final e in ctrl.episodes) {
      final plot = e.plot.trim();
      if (plot.isNotEmpty) return plot;
    }
    return '';
  }

  List<String> _metaParts() {
    final parts = <String>[];
    final date = _tmdb?.releaseDate.trim() ?? '';
    if (date.length >= 4) parts.add(date.substring(0, 4));
    final seasons = _seasons.length;
    if (seasons > 0) {
      parts.add(seasons == 1 ? '1 Season' : '$seasons Seasons');
    }
    final epCount = ctrl.episodes.length;
    if (epCount > 0) {
      parts.add(epCount == 1 ? '1 Episode' : '$epCount Episodes');
    }
    return parts;
  }

  List<MapEntry<String, String>> _facts() {
    final facts = <MapEntry<String, String>>[];
    final year = _cleaned.year ??
        (_tmdb != null && (_tmdb!.releaseDate.length >= 4)
            ? int.tryParse(_tmdb!.releaseDate.substring(0, 4))
            : null);
    if (year != null) facts.add(MapEntry('Year', '$year'));
    if (_seasons.isNotEmpty) {
      facts.add(MapEntry('Seasons', '${_seasons.length}'));
    }
    if (ctrl.episodes.isNotEmpty) {
      facts.add(MapEntry('Episodes', '${ctrl.episodes.length}'));
    }
    final portal = ctrl.activePortal?.displayLabel.trim() ?? '';
    if (portal.isNotEmpty) facts.add(MapEntry('Portal', portal));
    return facts;
  }

  Map<int, List<Map<String, dynamic>>> _episodeMaps() {
    final seasons = _seasons;
    final out = <int, List<Map<String, dynamic>>>{};
    for (var i = 0; i < seasons.length; i++) {
      final pickerSeason = i + 1;
      final eps = _episodesForPickerSeason(pickerSeason);
      out[pickerSeason] = [
        for (final e in eps)
          {
            'episode_number': e.episode,
            'name': _episodeDisplayTitle(e),
            'overview': e.plot,
            'thumbnail': e.image.isNotEmpty
                ? e.image
                : (ctrl.activeSeries?.icon ?? ''),
          },
      ];
    }
    return out;
  }

  String _episodeDisplayTitle(IptvEpisode e) {
    var t = e.title.trim();
    if (t.isEmpty) return 'Episode ${e.episode}';
    final afterSe = RegExp(
      r'[Ss]\d{1,2}\s*[Ee]\d{1,3}\s*[-–—:]?\s*(.+)$',
    ).firstMatch(t);
    if (afterSe != null) {
      final rest = afterSe.group(1)?.trim() ?? '';
      if (rest.isNotEmpty) return rest;
    }
    final cleaned = cleanIptvMediaTitle(t);
    if (cleaned.title.isNotEmpty &&
        cleaned.title.toLowerCase() != _cleaned.title.toLowerCase()) {
      return cleaned.title;
    }
    return t;
  }

  Future<void> _playEpisode(IptvEpisode episode) async {
    final p = ctrl.activePortal;
    if (p == null) return;
    final url = await IptvClient.resolveEpisodeUrl(p.portal, episode);
    if (url == null || url.isEmpty) return;
    if (!mounted) return;
    pushShellRoute(
      context,
      AppRouter.slideShellRoute(
        (_) => IptvPtPlayerScreen(
          sources: [IptvPlaySource(url: url, label: p.displayLabel)],
          title: 'Ep ${episode.episode} · ${_episodeDisplayTitle(episode)}',
          subtitle: '$_displayTitle · Season ${episode.season}',
          logoUrl: episode.image.isNotEmpty
              ? episode.image
              : ctrl.activeSeries?.icon,
        ),
      ),
    );
  }

  Future<void> _playSelected() async {
    final ep = _episodeAt(_selectedSeasonIndex, _selectedEpisode);
    if (ep == null) return;
    await _playEpisode(ep);
  }

  void _focusBack() {
    if (_backFocus.canRequestFocus) {
      _backFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final tvFocus = policy.useFocusableMoodChips;

    if (ctrl.isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Stack(
          children: [
            Center(
              child: CircularProgressIndicator(
                color: ForjaShellColors.sectionAccent,
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

    if (ctrl.episodes.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Stack(
          children: [
            Center(
              child: Text(
                ctrl.error?.isNotEmpty == true
                    ? ctrl.error!
                    : 'No episodes found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 15,
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

    final multiSeason = _pickerSeasonCount > 1;
    final backdrop = _backdropUrl();
    final heroBackdrops = _heroBackdropUrls();
    final rating =
        (_tmdb?.voteAverage ?? 0) > 0 ? _tmdb!.voteAverage : null;
    final heroHeight = DetailsTokens.heroHeight(
      context,
      showEpisodeRail: true,
      showSeasonRail: multiSeason,
    );

    if (tvFocus &&
        policy.heroPlayAutoFocus &&
        !_heroFocusDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _heroFocusDone) return;
        if (_heroPlayFocus.canRequestFocus) {
          _heroPlayFocus.requestFocus();
          _heroFocusDone = true;
        }
      });
    }

    final heroFocusUp = tvFocus ? _focusBack : null;

    final episodePicker = MediaDetailsBody.padContent(
      context,
      TvSeasonEpisodePicker(
        tmdbId: _tmdb?.id ?? 0,
        seasonCount: _pickerSeasonCount,
        selectedSeason: _selectedSeasonIndex,
        selectedEpisode: _selectedEpisode,
        isLoadingSeason: false,
        seasonData: null,
        watchedEpisodes: const {},
        fallbackPosterPath: ctrl.activeSeries?.icon ?? '',
        seasonPosters: {
          for (var i = 0; i < _seasons.length; i++)
            i + 1: ctrl.activeSeries?.icon ?? '',
        },
        customEpisodesBySeason: _episodeMaps(),
        onSeasonSelected: (season) {
          setState(() {
            _selectedSeasonIndex = season;
            final eps = _episodesForPickerSeason(season);
            _selectedEpisode = eps.isEmpty ? 1 : eps.first.episode;
          });
        },
        onEpisodeSelected: (ep) => setState(() => _selectedEpisode = ep),
        onEpisodePlay: (ep) {
          setState(() => _selectedEpisode = ep);
          final hit = _episodeAt(_selectedSeasonIndex, ep);
          if (hit != null) _playEpisode(hit);
        },
        onToggleWatched: (_, _) {},
        tvTabId: tvFocus ? 'iptv' : null,
        tvSeasonRowId: multiSeason ? 'seasons' : null,
        tvEpisodeRowId: 'episodes',
        tvRowOrderBase: 0,
        tvFocusUp: () {
          if (_heroPlayFocus.canRequestFocus) {
            _heroPlayFocus.requestFocus();
          } else {
            heroFocusUp?.call();
          }
        },
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MediaDetailsScrollPage(
            scrollController: _scroll,
            bodyOverlap: 0,
            topSpacing: DetailsTokens.bodyTopSpacingWithEpisodes,
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
              showSeasonRail: multiSeason,
              pageBottomChild: episodePicker,
              actionRow: DetailsHeroTvActionScope(
                tabId: 'iptv',
                itemCount: 1,
                onFocusUp: heroFocusUp,
                child: HubDetailsPlayRow(
                  label: 'Play Ep $_selectedEpisode',
                  enabled: _episodeAt(
                        _selectedSeasonIndex,
                        _selectedEpisode,
                      ) !=
                      null,
                  onPlay: _playSelected,
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
