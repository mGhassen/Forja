import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/iptv_catalog_recs.dart';
import 'package:forja/features/iptv/iptv/iptv_title_clean.dart';
import 'package:forja/features/iptv/iptv/iptv_tmdb_enrichment.dart';
import 'package:forja/features/iptv/iptv/providers/iptv_controller_provider.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_details_meta.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_movie_details_view.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/widgets/hero/rotating_hero_backdrop.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_hero.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_play_row.dart';
import 'package:forja/shared/widgets/media_details/media_details_scroll_page.dart';
import 'package:forja/shared/widgets/media_details_body.dart';
import 'package:forja/shared/widgets/tv_season_episode_picker.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:rust/rust.dart';

Future<T?> openIptvSeriesDetails<T>(
  BuildContext context, {
  required IptvStream series,
  required VerifiedPortal portal,
}) {
  return pushShellRoute<T>(
    context,
    AppRouter.slideShellRoute(
      (_) => IptvSeriesDetailsScreen(series: series, portal: portal),
      settings: const RouteSettings(name: 'iptv_series_details'),
    ),
  );
}

/// IPTV series details — same TV focus / scroll stack as Home / Asian Drama.
class IptvSeriesDetailsScreen extends ConsumerStatefulWidget {
  const IptvSeriesDetailsScreen({
    super.key,
    required this.series,
    required this.portal,
  });

  final IptvStream series;
  final VerifiedPortal portal;

  @override
  ConsumerState<IptvSeriesDetailsScreen> createState() =>
      _IptvSeriesDetailsScreenState();
}

class _IptvSeriesDetailsScreenState
    extends ConsumerState<IptvSeriesDetailsScreen> {
  final _scroll = ScrollController();
  final _backFocus = FocusNode(debugLabel: 'iptv-series-back');
  final _heroPlayFocus = FocusNode(debugLabel: 'iptv-series-play');

  IptvTmdbEnrichment? _enrich;
  List<IptvCatalogRecHit> _catalogRecs = const [];
  List<IptvEpisode> _episodes = const [];
  bool _loading = true;
  String? _error;
  int _selectedSeasonIndex = 1;
  int _selectedEpisode = 1;
  bool _heroFocusDone = false;

  IptvCleanedTitle get _cleaned => cleanIptvMediaTitle(widget.series.name);

  Movie? get _movie => _enrich?.rich.movie;

  List<int> get _seasons {
    final keys = <int>{};
    for (final e in _episodes) {
      keys.add(e.season);
    }
    final list = keys.toList()..sort();
    return list;
  }

  int _portalSeason(int pickerSeason) {
    final seasons = _seasons;
    if (seasons.isEmpty) return pickerSeason;
    final i = (pickerSeason - 1).clamp(0, seasons.length - 1);
    return seasons[i];
  }

  int get _pickerSeasonCount => _seasons.isEmpty ? 0 : _seasons.length;

  String get _displayTitle {
    final tmdbTitle = _movie?.title.trim() ?? '';
    if (tmdbTitle.isNotEmpty) return tmdbTitle;
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
      unawaited(_loadTmdb());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _loadTmdb() async {
    final hit = await loadIptvTmdbEnrichment(
      rawTitle: widget.series.name,
      preferMovie: false,
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
        excludeStreamId: widget.series.streamId,
      );
      if (!mounted) return;
      setState(() => _catalogRecs = recs);
    } catch (_) {
      // Enrichment already painted; catalog recs are optional.
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
    return widget.series.icon.trim();
  }

  List<String> _heroBackdropUrls() {
    final primary = _backdropUrl();
    final icon = widget.series.icon.trim();
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

  String _overview() {
    final tmdb = _movie?.overview.trim() ?? '';
    if (tmdb.isNotEmpty) return tmdb;
    for (final e in _episodes) {
      final plot = e.plot.trim();
      if (plot.isNotEmpty) return plot;
    }
    return '';
  }

  List<String> _metaParts() {
    final parts = <String>[];
    final date = _movie?.releaseDate.trim() ?? '';
    if (date.length >= 4) parts.add(date.substring(0, 4));
    final cert = _enrich?.rich.extras.certification.trim() ?? '';
    if (cert.isNotEmpty) parts.add(cert);
    final seasons = _seasons.length;
    if (seasons > 0) {
      parts.add(seasons == 1 ? '1 Season' : '$seasons Seasons');
    }
    final epCount = _episodes.length;
    if (epCount > 0) {
      parts.add(epCount == 1 ? '1 Episode' : '$epCount Episodes');
    }
    return parts;
  }

  List<MapEntry<String, String>> _facts() {
    final year = _cleaned.year ??
        (_movie != null && (_movie!.releaseDate.length >= 4)
            ? int.tryParse(_movie!.releaseDate.substring(0, 4))
            : null);
    final portal = widget.portal.displayLabel.trim();
    return iptvTmdbFacts(
      _enrich?.rich,
      preferTv: true,
      fallback: iptvPortalFacts(
        year: year,
        seasons: _seasons.isNotEmpty ? _seasons.length : null,
        episodes: _episodes.isNotEmpty ? _episodes.length : null,
        portal: portal,
      ),
    );
  }

  Map<int, List<Map<String, dynamic>>> _episodeMaps() {
    final stills = _enrich?.episodeStills ?? const {};
    final meta = _enrich?.episodeMeta ?? const {};
    final seasons = _seasons;
    final out = <int, List<Map<String, dynamic>>>{};
    for (var i = 0; i < seasons.length; i++) {
      final pickerSeason = i + 1;
      final eps = _episodesForPickerSeason(pickerSeason);
      out[pickerSeason] = [
        for (final e in eps) _episodeMapEntry(e, stills: stills, meta: meta),
      ];
    }
    return out;
  }

  Map<String, dynamic> _episodeMapEntry(
    IptvEpisode e, {
    required Map<int, String> stills,
    required Map<int, Map<String, dynamic>> meta,
  }) {
    final tmdbMeta = meta[e.episode] ?? const {};
    final tmdbName = (tmdbMeta['name'] as String?)?.trim() ?? '';
    final tmdbOverview = (tmdbMeta['overview'] as String?)?.trim() ?? '';
    final runtime = (tmdbMeta['runtime'] as int?) ?? 0;
    final aired = (tmdbMeta['aired'] as String?)?.trim() ?? '';
    final still = stills[e.episode] ?? '';
    final thumb = e.image.isNotEmpty
        ? e.image
        : (still.isNotEmpty ? still : widget.series.icon);
    return {
      'episode_number': e.episode,
      'name': tmdbName.isNotEmpty ? tmdbName : _episodeDisplayTitle(e),
      'overview': e.plot.isNotEmpty ? e.plot : tmdbOverview,
      'runtime': runtime,
      if (thumb.isNotEmpty) 'thumbnail': thumb,
      if (still.isNotEmpty && !still.startsWith('http')) 'still_path': still,
      if (aired.isNotEmpty) 'aired': aired,
    };
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
    final url = await IptvClient.resolveEpisodeUrl(
      widget.portal.portal,
      episode,
    );
    if (url == null || url.isEmpty) return;
    if (!mounted) return;
    pushShellRoute(
      context,
      AppRouter.slideShellRoute(
        (_) => IptvPtPlayerScreen(
          sources: [
            IptvPlaySource(url: url, label: widget.portal.displayLabel),
          ],
          title: 'Ep ${episode.episode} · ${_episodeDisplayTitle(episode)}',
          subtitle: '$_displayTitle · Season ${episode.season}',
          logoUrl: episode.image.isNotEmpty
              ? episode.image
              : widget.series.icon,
          engineContext: BuiltInPlayerContext.vod,
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
      ),
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
            Center(
              child: CircularProgressIndicator(
                color: ForjaShellColors.sectionAccent,
              ),
            ),
            MediaDetailsBackButton(focusNode: _backFocus),
          ],
        ),
      );
    }

    if (_episodes.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Stack(
          children: [
            Center(
              child: Text(
                _error?.isNotEmpty == true ? _error! : 'No episodes found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 15,
                ),
              ),
            ),
            MediaDetailsBackButton(focusNode: _backFocus),
          ],
        ),
      );
    }

    final multiSeason = _pickerSeasonCount > 1;
    final backdrop = _backdropUrl();
    final heroBackdrops = _heroBackdropUrls();
    final rating =
        (_movie?.voteAverage ?? 0) > 0 ? _movie!.voteAverage : null;
    final heroHeight = DetailsTokens.heroHeight(
      context,
      showEpisodeRail: true,
      showSeasonRail: multiSeason,
    );
    final heroFocusUp = _revealedDetailsHeroPlayFocus;
    final heroPopUp = tvFocus ? _focusDetailsBack : null;

    final metaBase = multiSeason ? 2 : 1;
    final sections = buildIptvDetailsMetaSections(
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
      tvRowOrderBase: metaBase,
      castTitle: 'Characters',
      // First meta row ↑ goes to episodes (coordinator), then hero via picker.
      tvFocusUp: null,
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
        tmdbId: _movie?.id ?? 0,
        seasonCount: _pickerSeasonCount,
        selectedSeason: _selectedSeasonIndex,
        selectedEpisode: _selectedEpisode,
        isLoadingSeason: false,
        seasonData: null,
        watchedEpisodes: const {},
        fallbackPosterPath: widget.series.icon,
        seasonPosters: {
          for (var i = 0; i < _seasons.length; i++)
            i + 1: widget.series.icon,
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
        tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
        tvSeasonRowId: multiSeason ? 'seasons' : null,
        tvEpisodeRowId: 'episodes',
        tvRowOrderBase: 0,
        tvFocusUp: heroFocusUp,
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
              richFacts: _enrich?.rich,
              height: heroHeight,
              showSeasonRail: multiSeason,
              pageBottomChild: episodePicker,
              actionRow: DetailsHeroTvActionScope(
                tabId: MediaDetailsTv.tabId,
                itemCount: 1,
                onFocusUp: heroPopUp,
                child: HubDetailsPlayRow(
                  label: 'Play Ep $_selectedEpisode',
                  enabled: _episodeAt(
                        _selectedSeasonIndex,
                        _selectedEpisode,
                      ) !=
                      null,
                  onPlay: _playSelected,
                  focusNode: policy.heroPlayAutoFocus ? _heroPlayFocus : null,
                  onUpEdge: heroPopUp,
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
