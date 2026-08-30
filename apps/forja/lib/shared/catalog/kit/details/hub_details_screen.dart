import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/shared/catalog/kit/details/hub_details_meta.dart';
import 'package:forja/shared/catalog/kit/details/hub_details_play.dart';
import 'package:forja/shared/playback/catalog_play_resolve.dart';
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

  bool get _isMovie => hubMetaIsMovie(_show);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
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
    final seasons = hubSeasonNumbers(meta.videos).toList()..sort();
    final firstSeason = seasons.isEmpty ? 1 : seasons.first;
    final seasonVideos = hubVideosForSeason(meta.videos, firstSeason);
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
    final ctx = catalogPlayContextFromMeta(
      meta: _show,
      pluginId: widget.pluginId,
      episode: ep,
      season: season,
      episodeNumber: epNum,
      videos: _videos,
    );
    await runHubPlayFromContext(context: context, ctx: ctx);
    if (!mounted) return;
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
      show.background.isNotEmpty ? show.background : show.poster,
    );
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

    final playLabel = _isMovie
        ? 'Play'
        : (videos.isEmpty ? 'Play' : 'Play Ep $_selectedEpisode');

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
        ),
      ),
      sections: const [],
    );
  }
}
