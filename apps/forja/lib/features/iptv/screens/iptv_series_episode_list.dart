import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv_title_clean.dart';
import 'package:forja/features/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/hero/rotating_hero_backdrop.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_hero.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_play_row.dart';
import 'package:forja/shared/widgets/media_details/media_details_scroll_page.dart';
import 'package:forja/shared/widgets/media_details_body.dart';
import 'package:forja/shared/widgets/tv_season_episode_picker.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:rust/rust.dart';

Future<T?> openIptvSeriesEpisodeList<T>(
  BuildContext context, {
  required IptvStream series,
  required VerifiedPortal portal,
}) {
  return pushShellRoute<T>(
    context,
    AppRouter.slideShellRoute(
      (_) => IptvSeriesEpisodeListScreen(series: series, portal: portal),
      settings: const RouteSettings(name: 'iptv_series_episodes'),
    ),
  );
}

/// Portal-only series episode picker — used when the IPTV VOD details pack is not installed.
class IptvSeriesEpisodeListScreen extends StatefulWidget {
  const IptvSeriesEpisodeListScreen({
    super.key,
    required this.series,
    required this.portal,
  });

  final IptvStream series;
  final VerifiedPortal portal;

  @override
  State<IptvSeriesEpisodeListScreen> createState() =>
      _IptvSeriesEpisodeListScreenState();
}

class _IptvSeriesEpisodeListScreenState
    extends State<IptvSeriesEpisodeListScreen> {
  final _scroll = ScrollController();
  final _backFocus = FocusNode(debugLabel: 'iptv-series-ep-back');
  final _heroPlayFocus = FocusNode(debugLabel: 'iptv-series-ep-play');

  List<IptvEpisode> _episodes = const [];
  bool _loading = true;
  String? _error;
  int _selectedSeasonIndex = 1;
  int _selectedEpisode = 1;
  bool _heroFocusDone = false;

  IptvCleanedTitle get _cleaned => cleanIptvMediaTitle(widget.series.name);

  List<int> get _seasons {
    final keys = <int>{for (final e in _episodes) e.season};
    return keys.toList()..sort();
  }

  int _portalSeason(int pickerSeason) {
    final seasons = _seasons;
    if (seasons.isEmpty) return pickerSeason;
    final i = (pickerSeason - 1).clamp(0, seasons.length - 1);
    return seasons[i];
  }

  int get _pickerSeasonCount => _seasons.isEmpty ? 0 : _seasons.length;

  String get _displayTitle {
    final cleaned = _cleaned.title;
    if (cleaned.isNotEmpty) return cleaned;
    return widget.series.name;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _backFocus.dispose();
    _heroPlayFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final eps = await IptvClient.seriesEpisodes(
        widget.portal.portal,
        widget.series.streamId,
      );
      if (!mounted) return;
      setState(() {
        _episodes = eps;
        _loading = false;
      });
      _syncSelectionFromEpisodes();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = IptvClient.formatEngineError(e);
        _loading = false;
      });
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
    if (!has) {
      setState(() => _selectedEpisode = eps.first.episode);
    }
  }

  List<IptvEpisode> _episodesForPickerSeason(int pickerSeason) {
    final portalSeason = _portalSeason(pickerSeason);
    final list = _episodes.where((e) => e.season == portalSeason).toList()
      ..sort((a, b) => a.episode.compareTo(b.episode));
    return list;
  }

  IptvEpisode? _episodeAt(int pickerSeason, int episodeNum) {
    for (final e in _episodesForPickerSeason(pickerSeason)) {
      if (e.episode == episodeNum) return e;
    }
    return null;
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
            if (e.plot.trim().isNotEmpty) 'overview': e.plot.trim(),
            if (e.image.isNotEmpty) 'thumbnail': e.image,
          },
      ];
    }
    return out;
  }

  String _episodeDisplayTitle(IptvEpisode e) {
    final t = e.title.trim();
    if (t.isEmpty) return 'Episode ${e.episode}';
    final cleaned = cleanIptvMediaTitle(t);
    if (cleaned.title.isNotEmpty &&
        cleaned.title.toLowerCase() != _cleaned.title.toLowerCase()) {
      return cleaned.title;
    }
    return t;
  }

  List<String> _metaParts() {
    final parts = <String>[];
    if (_cleaned.year != null) parts.add('${_cleaned.year}');
    final seasons = _seasons.length;
    if (seasons > 0) {
      parts.add(seasons == 1 ? '1 Season' : '$seasons Seasons');
    }
    final epCount = _episodes.length;
    if (epCount > 0) {
      parts.add(epCount == 1 ? '1 Episode' : '$epCount Episodes');
    }
    final portal = widget.portal.displayLabel.trim();
    if (portal.isNotEmpty) parts.add(portal);
    return parts;
  }

  void _revealedHeroPlayFocus() {
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

  Future<void> _playEpisode(IptvEpisode episode) async {
    final url = await IptvClient.resolveEpisodeUrl(
      widget.portal.portal,
      episode,
    );
    if (url == null || url.isEmpty) {
      if (mounted) ForjaToast.error('Could not open episode');
      return;
    }
    if (!mounted) return;
    await IptvPtPlayerScreen.open(
      context,
      IptvPtPlayerScreen(
        sources: [
          IptvPlaySource(url: url, label: widget.portal.displayLabel),
        ],
        title: 'Ep ${episode.episode} · ${_episodeDisplayTitle(episode)}',
        subtitle: '$_displayTitle · Season ${episode.season}',
        logoUrl: episode.image.isNotEmpty
            ? episode.image
            : widget.series.icon,
        engineContext: BuiltInPlayerContext.iptv,
        vodPlayback: true,
        onlineSubtitles: true,
        subtitleSearchTitle: _displayTitle,
        subtitleSeason: episode.season,
        subtitleEpisode: episode.episode,
        subtitleYear: _cleaned.year,
        seriesEpisodes: List<IptvEpisode>.from(_episodes),
        seriesPortal: widget.portal.portal,
        seriesShowTitle: _displayTitle,
      ),
    );
    if (!mounted) return;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    ShellTvFocusCoordinator.claimHeroPlayAfterPlayerExit(
      _heroPlayFocus,
      isMounted: () => mounted,
    );
  }

  Future<void> _playSelected() async {
    final ep = _episodeAt(_selectedSeasonIndex, _selectedEpisode);
    if (ep == null) return;
    await _playEpisode(ep);
  }

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final tvFocus = policy.useFocusableMoodChips;

    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Stack(
          children: [
            const Center(child: CircularProgressIndicator()),
            MediaDetailsBackButton(focusNode: _backFocus),
          ],
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
            MediaDetailsBackButton(focusNode: _backFocus),
          ],
        ),
      );
    }

    final multiSeason = _pickerSeasonCount > 1;
    final icon = widget.series.icon.trim();
    final heroBackdrops = RotatingHeroBackdrop.normalizeUrls(
      [if (icon.isNotEmpty) icon],
    );

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

    final episodePicker = MediaDetailsBody.padContent(
      context,
      TvSeasonEpisodePicker(
        tmdbId: 0,
        seasonCount: _pickerSeasonCount,
        selectedSeason: _selectedSeasonIndex,
        selectedEpisode: _selectedEpisode,
        isLoadingSeason: false,
        seasonData: null,
        watchedEpisodes: const {},
        fallbackPosterPath: widget.series.icon,
        seasonPosters: {
          for (var i = 0; i < _seasons.length; i++) i + 1: widget.series.icon,
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
          if (hit != null) unawaited(_playEpisode(hit));
        },
        onToggleWatched: (_, _) {},
        tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
        tvSeasonRowId: multiSeason ? 'seasons' : null,
        tvEpisodeRowId: 'episodes',
        tvRowOrderBase: 0,
        tvFocusUp: _revealedHeroPlayFocus,
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MediaDetailsScrollPage(
            scrollController: _scroll,
            tvHeroPlayFocus: _heroPlayFocus,
            tvBackFocus: _backFocus,
            bodyOverlap: 0,
            topSpacing: DetailsTokens.bodyTopSpacingWithEpisodes,
            backgroundColor: AppTheme.bgDark,
            sections: const [],
            hero: HubDetailsHero(
              backdropUrl: icon,
              backdropUrls: heroBackdrops,
              title: _displayTitle,
              genres: const [],
              metaParts: _metaParts(),
              overview: '',
              facts: const [],
              height: DetailsTokens.heroHeight(
                context,
                showEpisodeRail: true,
                showSeasonRail: multiSeason,
              ),
              showSeasonRail: multiSeason,
              pageBottomChild: episodePicker,
              actionRow: DetailsHeroTvActionScope(
                tabId: MediaDetailsTv.tabId,
                itemCount: 1,
                child: HubDetailsPlayRow(
                  label: 'Play Ep $_selectedEpisode',
                  enabled:
                      _episodeAt(_selectedSeasonIndex, _selectedEpisode) !=
                      null,
                  onPlay: _playSelected,
                  focusNode: policy.heroPlayAutoFocus ? _heroPlayFocus : null,
                  tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                  tvItemIndex: 0,
                ),
              ),
            ),
          ),
          MediaDetailsBackButton(focusNode: _backFocus),
        ],
      ),
    );
  }
}
