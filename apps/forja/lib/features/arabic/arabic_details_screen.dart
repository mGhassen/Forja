import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/arabic/arabic_hub_play.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/runtime.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/hub_details/hub_catalog_sources.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_hero.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_play_row.dart';
import 'package:forja/shared/widgets/hub_details/hub_engine_auto_play.dart';
import 'package:forja/shared/widgets/media_details/media_details.dart';
import 'package:forja/shared/widgets/media_details_body.dart';
import 'package:forja/shared/widgets/shell_error_retry_panel.dart';
import 'package:forja/shared/widgets/tv_season_episode_picker.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';

Future<T?> openArabicDetails<T>(
  BuildContext context, {
  required String pluginId,
  required CatalogMetaItem item,
}) {
  return pushShellRoute<T>(
    context,
    AppRouter.slideShellRoute(
      (_) => ArabicDetailsScreen(pluginId: pluginId, item: item),
      settings: const RouteSettings(name: 'arabic_details'),
    ),
    shellTabId: 'arabic',
  );
}

class ArabicDetailsScreen extends ConsumerStatefulWidget {
  const ArabicDetailsScreen({
    super.key,
    required this.pluginId,
    required this.item,
  });

  final String pluginId;
  final CatalogMetaItem item;

  @override
  ConsumerState<ArabicDetailsScreen> createState() =>
      _ArabicDetailsScreenState();
}

class _ArabicDetailsScreenState extends ConsumerState<ArabicDetailsScreen> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _heroPlayFocus = FocusNode(debugLabel: 'arabic-details-play');
  final FocusNode _backFocus = FocusNode(debugLabel: 'arabic-details-back');

  CatalogMetaItem? _detail;
  bool _loading = true;
  String? _error;
  int _selectedSeason = 1;
  int _selectedEpisode = 1;
  bool _detailsHeroInitialFocusDone = false;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(settingsPlaybackProvider.future));
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _heroPlayFocus.dispose();
    _backFocus.dispose();
    super.dispose();
  }

  CatalogMetaItem get _show => _detail ?? widget.item;

  List<CatalogVideo> get _videos => _show.videos;

  bool get _isMovie =>
      _show.open?.extraBool('movie') == true ||
      (_show.badge ?? '').toUpperCase() == 'MOVIE';

  Map<String, dynamic> _detailsParams() {
    final params = <String, dynamic>{'id': widget.item.id};
    final open = widget.item.open;
    if (open == null) return params;
    for (final e in open.toJson().entries) {
      if (e.key == 'surface') continue;
      params[e.key] = e.value;
    }
    params['id'] = widget.item.id;
    return params;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final env = await CatalogRuntime.instance.run(
      pluginId: widget.pluginId,
      action: 'details',
      params: _detailsParams(),
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
    final seasons = arabicSeasonNumbers(meta.videos).toList()..sort();
    final firstSeason = seasons.isEmpty ? 1 : seasons.first;
    final seasonVideos = arabicVideosForSeason(meta.videos, firstSeason);
    final firstEp = seasonVideos.isEmpty
        ? 1
        : (seasonVideos.first.episode ?? 1);
    setState(() {
      _detail = meta;
      _loading = false;
      _selectedSeason = firstSeason;
      _selectedEpisode = firstEp;
    });
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

  Future<void> _afterPlayClosed() async {
    if (!mounted) return;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    ShellTvFocusCoordinator.claimHeroPlayAfterPlayerExit(
      _heroPlayFocus,
      isMounted: () => mounted,
    );
  }

  Future<void> _playEpisode(CatalogVideo episode) async {
    if (!await hubEngineAutoPlayEnabled()) return;
    if (!mounted) return;
    final movie = arabicPlayMovieFor(_show, videos: _videos);
    final epNum = episode.episode ?? _selectedEpisode;
    final season = episode.season ?? _selectedSeason;
    final isTv = !_isMovie && _videos.length > 1;
    await runHubEngineAutoPlay(
      context: context,
      movie: movie,
      engineCategory: 'arabic',
      season: isTv ? season : null,
      episode: isTv ? epNum : null,
      arabicVideoId: episode.id,
      arabicVideoIdByEpisode: arabicVideoIdByEpisode(_videos),
      selectedPluginIds: {arabicProviderIdForVideoId(episode.id)},
      loadingSubtitle: episode.title.isNotEmpty ? episode.title : 'EP $epNum',
      hubEpisodes: isTv ? arabicHubEpisodes(_videos) : null,
    );
    if (!mounted) return;
    await _afterPlayClosed();
  }

  void _playSelected() {
    final ep = _selectedVideo();
    if (ep == null) return;
    unawaited(_playEpisode(ep));
  }

  void _openCatalogSources() {
    final ep = _selectedVideo();
    if (ep == null) return;
    final movie = arabicPlayMovieFor(_show, videos: _videos);
    final isTv = !_isMovie && _videos.length > 1;
    unawaited(
      openHubCatalogSources(
        context: context,
        movie: movie,
        season: isTv ? _selectedSeason : null,
        episode: isTv ? _selectedEpisode : null,
        engineCategory: 'arabic',
        arabicVideoId: ep.id,
      ),
    );
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
    final seasons = arabicSeasonNumbers(videos).toList()..sort();
    final backdrop = arabicImageUrl(
      show.background.isNotEmpty ? show.background : show.poster,
    );
    final policy = ShellScope.inputPolicyOf(context);
    final tvFocus = policy.useFocusableMoodChips;
    final playbackSnap = ref.watch(settingsPlaybackProvider).valueOrNull;
    final showCatalogSources = hubHasCatalogPanelSources(playbackSnap);
    final hasEpisodes = videos.isNotEmpty && !_isMovie;

    if (policy.heroPlayAutoFocus &&
        !_detailsHeroInitialFocusDone &&
        videos.isNotEmpty) {
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
              customEpisodesBySeason: arabicEpisodeMaps(videos),
              watchedEpisodes: const {},
              onToggleWatched: (season, episode) {},
              onSeasonSelected: (season) {
                final eps = arabicVideosForSeason(videos, season);
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

    final playLabel = _isMovie
        ? 'Play'
        : 'Play Ep $_selectedEpisode';

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
        title: show.name,
        overview: show.description,
        metaParts: [
          if (_isMovie) 'FILM' else 'TV',
          if (show.releaseInfo.isNotEmpty) show.releaseInfo,
        ],
        height: DetailsTokens.heroHeight(
          context,
          showEpisodeRail: hasEpisodes,
          showSeasonRail: seasons.length > 1,
        ),
        pageBottomChild: episodePicker,
        actionRow: DetailsHeroTvActionScope(
          tabId: MediaDetailsTv.tabId,
          itemCount: heroActionCount,
          onFocusUp: heroPopUp,
          child: HubDetailsPlayRow(
            label: playLabel,
            enabled: _isMovie || videos.isNotEmpty,
            onPlay: _playSelected,
            onOpenSources:
                showCatalogSources ? _openCatalogSources : null,
            focusNode: policy.heroPlayAutoFocus ? _heroPlayFocus : null,
            onUpEdge: heroPopUp,
            tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
            tvItemIndex: playIndex,
            tvSourcesItemIndex: sourcesIndex,
          ),
        ),
      ),
      sections: const [],
    );
  }
}
