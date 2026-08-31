import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/shared/catalog/kit/details/hub_details_meta.dart';
import 'package:forja/shared/catalog/kit/details/hub_details_play.dart';
import 'package:forja/shared/catalog/kit/details/hub_details_sections.dart';
import 'package:forja/shared/catalog/services/catalog_watch_history.dart';
import 'package:forja/shared/catalog/kit/play/catalog_play_resolve.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/runtime.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/widgets/hub_details/hub_catalog_sources.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_hero.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_play_row.dart';
import 'package:forja/shared/widgets/media_details/media_details.dart';
import 'package:forja/shared/widgets/media_details_body.dart';
import 'package:forja/shared/widgets/shell_error_retry_panel.dart';
import 'package:forja/shared/widgets/tv_season_episode_picker.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:rust/rust.dart' show isInProgressResume;

Future<T?> openHubDetails<T>(
  BuildContext context, {
  required String pluginId,
  required CatalogMetaItem item,
  String? shellTabId,
}) {
  final tab = shellTabId ?? hubShellTabIdForPlugin(pluginId) ?? 'home';
  return pushShellRoute<T>(
    context,
    AppRouter.slideShellRoute(
      (_) => HubDetailsScreen(pluginId: pluginId, item: item),
      settings: RouteSettings(name: '${tab}_hub_details'),
    ),
    shellTabId: tab,
  );
}

/// Pack-driven details — host loads `action: details` then renders shared chrome.
class HubDetailsScreen extends ConsumerStatefulWidget {
  const HubDetailsScreen({
    super.key,
    required this.pluginId,
    required this.item,
  });

  final String pluginId;
  final CatalogMetaItem item;

  @override
  ConsumerState<HubDetailsScreen> createState() => _HubDetailsScreenState();
}

class _HubDetailsScreenState extends ConsumerState<HubDetailsScreen> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _heroPlayFocus = FocusNode(debugLabel: 'hub-details-play');
  final FocusNode _backFocus = FocusNode(debugLabel: 'hub-details-back');

  CatalogMetaItem? _detail;
  List<HubDetailRailSection> _packRails = const [];
  List<String> _heroBackdrops = const [];
  bool _loading = true;
  String? _error;
  int _selectedSeason = 1;
  int _selectedEpisode = 1;
  bool _detailsHeroInitialFocusDone = false;
  Map<String, dynamic>? _watchProgress;

  @override
  void initState() {
    super.initState();
    CatalogWatchHistory.revision.addListener(_onWatchHistoryChanged);
    unawaited(ref.read(settingsPlaybackProvider.future));
    unawaited(_loadWatchProgress());
    _loading = !hubMetaTmdbEnriched(widget.item);
    _load();
  }

  @override
  void dispose() {
    CatalogWatchHistory.revision.removeListener(_onWatchHistoryChanged);
    _scrollController.dispose();
    _heroPlayFocus.dispose();
    _backFocus.dispose();
    super.dispose();
  }

  CatalogMetaItem get _show => _detail ?? widget.item;

  List<CatalogVideo> get _videos => _show.videos;

  bool get _isMovie => hubMetaIsMovie(_show);

  void _onWatchHistoryChanged() {
    unawaited(_loadWatchProgress());
  }

  Future<void> _loadWatchProgress() async {
    if (!mounted) return;
    try {
      final entries = await CatalogWatchHistory.getAll(widget.pluginId);
      Map<String, dynamic>? hit;
      for (final entry in entries) {
        if (entry['metaId']?.toString() == _show.id) {
          hit = entry;
          break;
        }
      }
      if (!mounted) return;
      setState(() => _watchProgress = hit);
    } catch (_) {}
  }

  Duration? _startPositionForEpisode(int episodeNumber) {
    final progress = _watchProgress;
    if (progress == null) return null;
    final savedEp = (progress['episodeNumber'] as num?)?.toInt();
    if (savedEp != null && savedEp != episodeNumber) return null;
    final posMs = (progress['positionMs'] as num?)?.toInt() ?? 0;
    final durMs = (progress['durationMs'] as num?)?.toInt() ?? 0;
    if (posMs <= 5000 || !isInProgressResume(posMs, durMs)) return null;
    final clamped =
        (durMs > 0 && posMs > durMs - 30000) ? (durMs - 30000) : posMs;
    return Duration(milliseconds: (clamped - 3000).clamp(0, 1 << 31));
  }

  bool get _canResumeSelected {
    final progress = _watchProgress;
    if (progress == null) return false;
    final savedEp = (progress['episodeNumber'] as num?)?.toInt();
    if (savedEp != null && savedEp != _selectedEpisode) return false;
    final posMs = (progress['positionMs'] as num?)?.toInt() ?? 0;
    final durMs = (progress['durationMs'] as num?)?.toInt() ?? 0;
    return isInProgressResume(posMs, durMs);
  }

  Future<void> _load() async {
    final seedEnriched = hubMetaTmdbEnriched(widget.item);
    if (!seedEnriched) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final env = await CatalogRuntime.instance.run(
      pluginId: widget.pluginId,
      action: 'details',
      params: hubDetailsParams(widget.item),
    );
    if (!mounted) return;
    if (!env.ok) {
      setState(() {
        _loading = false;
        _error = env.error?.message ?? 'Failed to load details';
      });
      return;
    }
    final meta = env.meta ?? widget.item;
    final packRails = parseHubDetailRails(env.data);
    final backdrops = hubHeroBackdropUrls(meta);
    if (!mounted) return;
    final seasons = hubSeasonNumbers(meta.videos).toList()..sort();
    final firstSeason = seasons.isEmpty ? 1 : seasons.first;
    final seasonVideos = hubVideosForSeason(meta.videos, firstSeason);
    final firstEp = seasonVideos.isEmpty
        ? 1
        : (seasonVideos.first.episode ?? 1);
    setState(() {
      _detail = meta;
      _packRails = packRails;
      _heroBackdrops = backdrops;
      _loading = false;
      _selectedSeason = firstSeason;
      _selectedEpisode = firstEp;
    });
    unawaited(_loadWatchProgress());
  }

  void _scrollDetailsHeroIntoView() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _revealedDetailsHeroPlayFocus() => _scrollDetailsHeroIntoView();

  void _focusDetailsBack() {
    if (_backFocus.canRequestFocus) {
      _backFocus.requestFocus();
    } else {
      maybePopShellOverlay();
    }
  }

  CatalogVideo? _selectedVideo() {
    for (final v in _videos) {
      if ((v.season ?? 1) == _selectedSeason &&
          (v.episode ?? 1) == _selectedEpisode) {
        return v;
      }
    }
    return _videos.isEmpty ? null : _videos.first;
  }

  Future<void> _afterPlayClosed() => hubDetailsAfterPlayClosed(
        scrollController: _scrollController,
        heroPlayFocus: _heroPlayFocus,
        isMounted: () => mounted,
      );

  Future<void> _playEpisode(CatalogVideo? episode) async {
    if (!mounted) return;
    final ep = episode ?? _selectedVideo();
    final epNum = ep?.episode ?? _selectedEpisode;
    final season = ep?.season ?? _selectedSeason;
    final progress = _watchProgress;
    final progressExtras = progress?['extras'] is Map
        ? Map<String, dynamic>.from(progress!['extras'] as Map)
        : const <String, dynamic>{};
    final progressVideoId = progress?['episodeVideoId']?.toString();
    final ctx = catalogPlayContextFromMeta(
      meta: _show,
      pluginId: widget.pluginId,
      episode: ep,
      season: season,
      episodeNumber: epNum,
      videos: _videos,
      episodeVideoId: progressVideoId,
      extras: progressExtras,
      startPosition: _startPositionForEpisode(epNum),
    );
    await runHubPlayFromContext(context: context, ctx: ctx);
    if (!mounted) return;
    await _loadWatchProgress();
    await _afterPlayClosed();
  }

  void _playSelected() {
    if (_isMovie || _videos.isEmpty) {
      unawaited(_playEpisode(null));
      return;
    }
    final ep = _selectedVideo();
    if (ep == null) return;
    unawaited(_playEpisode(ep));
  }

  void _openCatalogSources() {
    final ep = _selectedVideo();
    final ctx = catalogPlayContextFromMeta(
      meta: _show,
      pluginId: widget.pluginId,
      episode: ep,
      season: _selectedSeason,
      episodeNumber: _selectedEpisode,
      videos: _videos,
    );
    unawaited(openHubSourcesFromContext(context: context, ctx: ctx));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemePreset>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, _, _) {
        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (_loading)
                Center(
                  child: CircularProgressIndicator(
                    color: ForjaShellColors.sectionAccent,
                  ),
                )
              else if (_error != null)
                ShellErrorRetryPanel(
                  message: _error!,
                  onRetry: _load,
                )
              else
                _buildScrollLayout(),
              MediaDetailsBackButton(focusNode: _backFocus),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScrollLayout() {
    final show = _show;
    final videos = _videos;
    final seasons = hubSeasonNumbers(videos).toList()..sort();
    final backdrop = hubImageUrl(
      _heroBackdrops.isNotEmpty
          ? _heroBackdrops.first
          : (show.background.isNotEmpty ? show.background : show.poster),
    );
    final backdropUrls = _heroBackdrops.length > 1
        ? _heroBackdrops
        : (backdrop.isNotEmpty ? [backdrop] : const <String>[]);
    final policy = ShellScope.inputPolicyOf(context);
    final tvFocus = policy.useFocusableMoodChips;
    final playbackSnap = ref.watch(settingsPlaybackProvider).valueOrNull;
    final showCatalogSources = hubHasCatalogPanelSources(playbackSnap);
    final hasEpisodes = videos.isNotEmpty && !_isMovie;

    if (policy.heroPlayAutoFocus &&
        !_detailsHeroInitialFocusDone &&
        (_isMovie || videos.isNotEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _detailsHeroInitialFocusDone) return;
        if (_heroPlayFocus.context == null || !_heroPlayFocus.canRequestFocus) {
          return;
        }
        _heroPlayFocus.requestFocus();
        _detailsHeroInitialFocusDone = true;
      });
    }

    final heroFocusUp = _revealedDetailsHeroPlayFocus;
    final heroPopUp = tvFocus ? _focusDetailsBack : null;
    var tvIndex = 0;
    final playIndex = tvIndex++;
    final sourcesIndex = showCatalogSources ? tvIndex++ : null;
    final heroActionCount = tvIndex;

    final episodePicker = hasEpisodes
        ? MediaDetailsBody.padContent(
            context,
            TvSeasonEpisodePicker(
              tmdbId: show.id.hashCode,
              seasonCount: seasons.length,
              selectedSeason: _selectedSeason,
              selectedEpisode: _selectedEpisode,
              isLoadingSeason: false,
              seasonData: null,
              fallbackPosterPath: show.poster,
              customEpisodesBySeason: hubEpisodeMaps(videos),
              watchedEpisodes: const {},
              onToggleWatched: (season, episode) {},
              onSeasonSelected: (season) {
                final eps = hubVideosForSeason(videos, season);
                setState(() {
                  _selectedSeason = season;
                  _selectedEpisode =
                      eps.isEmpty ? 1 : (eps.first.episode ?? 1);
                });
              },
              onEpisodeSelected: (ep) => setState(() => _selectedEpisode = ep),
              onEpisodePlay: (ep) {
                setState(() => _selectedEpisode = ep);
                _playSelected();
              },
              tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
              tvSeasonRowId: 'seasons',
              tvEpisodeRowId: 'episodes',
              tvRowOrderBase: 0,
              tvFocusUp: heroFocusUp,
            ),
          )
        : null;

    final canResume = _canResumeSelected;
    final progress = _watchProgress;
    final playLabel = _isMovie
        ? (canResume ? 'Resume' : 'Play')
        : (videos.isEmpty
            ? (canResume ? 'Resume' : 'Play')
            : (canResume
                ? 'Resume Ep $_selectedEpisode'
                : 'Play Ep $_selectedEpisode'));
    final heroPosMs = canResume
        ? (progress?['positionMs'] as num?)?.toInt()
        : null;
    final heroDurMs = canResume
        ? (progress?['durationMs'] as num?)?.toInt()
        : null;

    final isUpcoming =
        (show.status ?? '').toUpperCase() == 'NOT_YET_RELEASED';
    final firstMetaFocusUp = tvFocus ? _revealedDetailsHeroPlayFocus : null;

    final packSections = buildHubDetailRailSections(
      context: context,
      pluginId: widget.pluginId,
      rails: _packRails,
      tvFocus: tvFocus,
      firstMetaFocusUp: firstMetaFocusUp,
    );
    final tmdbSections = buildHubTmdbDetailSections(
      context: context,
      rich: null,
      tvFocus: tvFocus,
      firstMetaFocusUp: packSections.isEmpty ? firstMetaFocusUp : null,
    );
    final sections = [...packSections, ...tmdbSections];

    return MediaDetailsScrollPage(
      scrollController: _scrollController,
      tvHeroPlayFocus: _heroPlayFocus,
      tvBackFocus: _backFocus,
      bodyOverlap: 0,
      topSpacing: hasEpisodes
          ? DetailsTokens.bodyTopSpacingWithEpisodes
          : DetailsTokens.bodyTopSpacing,
      backgroundColor: AppTheme.bgDark,
      hero: HubDetailsHero(
        backdropUrl: backdrop,
        backdropUrls: backdropUrls,
        title: show.name,
        genres: show.genres,
        overview: show.description.trim(),
        metaParts: [
          if (_isMovie) 'FILM' else 'TV',
          if (show.releaseInfo.isNotEmpty) show.releaseInfo,
        ],
        rating: show.rating,
        richFacts: null,
        logoUrl: hubMetaLogoUrl(show),
        height: DetailsTokens.heroHeight(
          context,
          showEpisodeRail: hasEpisodes,
          showSeasonRail: seasons.length > 1,
        ),
        pageBottomChild: episodePicker,
        showSeasonRail: seasons.length > 1,
        positionMs: heroPosMs,
        durationMs: heroDurMs,
        actionRow: DetailsHeroTvActionScope(
          tabId: MediaDetailsTv.tabId,
          itemCount: heroActionCount,
          onFocusUp: heroPopUp,
          child: Row(
            children: [
              if (isUpcoming)
                HubDetailsUpcomingNotice(
                  releaseDateLabel: show.releaseInfo.trim().isEmpty
                      ? null
                      : show.releaseInfo,
                )
              else
                HubDetailsPlayRow(
                  label: playLabel,
                  enabled: _isMovie || videos.isNotEmpty || show.open != null,
                  onPlay: _playSelected,
                  onOpenSources:
                      showCatalogSources && (_isMovie || videos.isNotEmpty)
                          ? _openCatalogSources
                          : null,
                  focusNode: policy.heroPlayAutoFocus ? _heroPlayFocus : null,
                  onUpEdge: heroPopUp,
                  tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                  tvItemIndex: playIndex,
                  tvSourcesItemIndex: sourcesIndex,
                ),
            ],
          ),
        ),
      ),
      sections: sections,
    );
  }
}
