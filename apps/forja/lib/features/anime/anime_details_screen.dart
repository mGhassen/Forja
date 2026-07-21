import 'package:flutter/material.dart';

import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/shell_error_retry_panel.dart';
import 'package:forja/shared/widgets/hub/hub_catalog_section.dart';
import 'package:forja/shared/widgets/hub/hub_poster_card.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_hero.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_play_row.dart';
import 'package:forja/shared/widgets/media_details_body.dart';
import 'package:forja/shared/widgets/tv_season_episode_picker.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'anime_player_screen.dart';

Future<T?> openAnimeDetails<T>(BuildContext context, AnimeCard anime) {
  return pushShellRoute<T>(
    context,
    AppRouter.slideShellRoute(
      (_) => AnimeDetailsScreen(anime: anime),
      settings: const RouteSettings(name: 'anime_details'),
    ),
  );
}

class AnimeDetailsScreen extends StatefulWidget {
  final AnimeCard anime;
  const AnimeDetailsScreen({super.key, required this.anime});

  @override
  State<AnimeDetailsScreen> createState() => _AnimeDetailsScreenState();
}

class _AnimeDetailsScreenState extends State<AnimeDetailsScreen> {
  final AnimeService _service = AnimeService();
  final ScrollController _detailsScrollController = ScrollController();
  final FocusNode _heroPlayFocus = FocusNode(debugLabel: 'anime-details-play');
  final FocusNode _backFocus = FocusNode(debugLabel: 'anime-details-back');
  bool _detailsHeroInitialFocusDone = false;

  AnimeCard? _full;
  List<AnimeEpisode> _episodes = [];
  bool _episodesLoading = true;
  List<AnimeCard> _related = [];
  Map<String, dynamic>? _progress;
  String? _error;

  String _category = 'sub';
  int _selectedEpisode = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _heroPlayFocus.dispose();
    _backFocus.dispose();
    _detailsScrollController.dispose();
    super.dispose();
  }

  void _scrollDetailsHeroIntoView() {
    if (!_detailsScrollController.hasClients) return;
    _detailsScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _revealedDetailsHeroPlayFocus() {
    void focusPlay() {
      if (!mounted) return;
      if (_heroPlayFocus.canRequestFocus) {
        _heroPlayFocus.requestFocus();
      }
    }

    _scrollDetailsHeroIntoView();
    if (!_detailsScrollController.hasClients) {
      focusPlay();
      return;
    }
    _detailsScrollController
        .animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(focusPlay);
  }

  void _focusDetailsBack() {
    if (!_backFocus.canRequestFocus) {
      maybePopShellOverlay();
      return;
    }
    _backFocus.requestFocus();
  }

  AnimeCard get _data => _full ?? widget.anime;

  Future<void> _load() async {
    setState(() {
      _error = null;
      _episodes = [];
      _episodesLoading = true;
    });

    // Metadata + AniList episode rail (Anikoto only resolves on Play for Vidwish).
    // TMDB backdrop for the hero (AniList banner fallback).
    _service.getDetails(widget.anime.id).then((d) async {
      final seeded = widget.anime.tmdbBackdropUrl == null
          ? d
          : d.copyWith(tmdbBackdropUrl: widget.anime.tmdbBackdropUrl);
      final enriched = await _service.attachTmdbBackdrop(seeded);
      if (!mounted) return;
      setState(() => _full = enriched);
    }).catchError((e) {
      if (mounted && _full == null) setState(() => _error = 'Failed to load: $e');
    });

    if (widget.anime.tmdbBackdropUrl == null) {
      _service.attachTmdbBackdrop(widget.anime).then((enriched) {
        if (!mounted || _full != null) return;
        setState(() => _full = enriched);
      });
    }

    _service.getEpisodes(widget.anime).then((eps) {
      if (!mounted) return;
      setState(() {
        _episodes = eps;
        _episodesLoading = false;
        if (_episodes.isNotEmpty &&
            !_episodes.any((e) => e.number == _selectedEpisode)) {
          _selectedEpisode = _episodes.first.number;
        }
      });
    }).catchError((_) {
      if (mounted) setState(() => _episodesLoading = false);
    });

    _service.getRelations(widget.anime.id).then((r) {
      if (!mounted) return;
      setState(() => _related = r);
    }).catchError((_) {});

    _service.getProgress(widget.anime.id).then((p) {
      if (!mounted) return;
      setState(() {
        _progress = p;
        final ep = (p?['episodeNumber'] as num?)?.toInt();
        if (ep != null &&
            ep > 0 &&
            (_episodesLoading || _episodes.any((e) => e.number == ep))) {
          _selectedEpisode = ep;
        }
      });
    }).catchError((_) {});
  }

  void _play(int epNumber, {Duration? startPosition}) {
    openAnimePlayer(
      context,
      anime: _data,
      episodeNumber: epNumber,
      category: _category,
      allEpisodes: _episodes,
      startPosition: startPosition,
    );
  }

  void _playSelected() {
    final match = _episodes.where((e) => e.number == _selectedEpisode);
    if (match.isEmpty || !match.first.aired) return;
    final p = _progress;
    final resumeEp = (p?['episodeNumber'] as num?)?.toInt();
    Duration? start;
    if (p != null && resumeEp == _selectedEpisode) {
      final posMs = (p['positionMs'] as num?)?.toInt() ?? 0;
      final durMs = (p['durationMs'] as num?)?.toInt() ?? 0;
      // Same as movies: ≥90% (or <2%) restarts at 0 — avoid credits seek.
      if (posMs > 0 && isInProgressResume(posMs, durMs)) {
        start = Duration(milliseconds: posMs);
      }
    }
    _play(_selectedEpisode, startPosition: start);
  }

  Future<void> _clearProgress() async {
    await _service.removeFromHistory(widget.anime.id);
    if (mounted) setState(() => _progress = null);
  }

  List<String> _metaParts(AnimeCard a) {
    return [
      if (a.format != null && a.format!.isNotEmpty) a.format!,
      if (a.seasonYear != null) '${a.seasonYear}',
      if (a.episodes != null) '${a.episodes} eps',
      if (a.status != null && a.status!.isNotEmpty) _statusLabel(a.status!),
    ];
  }

  List<MapEntry<String, String>> _facts(AnimeCard a) {
    return [
      if (a.mainStudio != null && a.mainStudio!.isNotEmpty)
        MapEntry('Studio', a.mainStudio!),
      if (a.duration != null) MapEntry('Duration', '${a.duration} min/ep'),
      if (a.season != null && a.seasonYear != null)
        MapEntry(
          'Season',
          '${a.season![0]}${a.season!.substring(1).toLowerCase()} ${a.seasonYear}',
        ),
      if (a.popularity != null) MapEntry('Popularity', _compactNum(a.popularity!)),
      if (a.genres.isNotEmpty) MapEntry('Genres', a.genres.join(', ')),
    ];
  }

  Map<int, List<Map<String, dynamic>>>? _episodeMaps() {
    if (_episodes.isEmpty) return null;
    return {
      1: _episodes
          .map(
            (e) => {
              'episode_number': e.number,
              'name': _decodeEpisodeTitle(e.title),
              'overview': '',
              'runtime': _data.duration ?? 0,
              'still_path': e.thumbnail,
              'aired': e.aired,
            },
          )
          .toList(),
    };
  }

  Map<String, Map<String, dynamic>> _episodeProgressMap() {
    final p = _progress;
    if (p == null) return const {};
    final ep = (p['episodeNumber'] as num?)?.toInt();
    final pos = (p['positionMs'] as num?)?.toInt() ?? 0;
    final dur = (p['durationMs'] as num?)?.toInt() ?? 0;
    if (ep == null || ep <= 0) return const {};
    return {
      'S1_E$ep': {'position': pos, 'duration': dur},
    };
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'RELEASING':
        return 'Airing';
      case 'FINISHED':
        return 'Completed';
      case 'NOT_YET_RELEASED':
        return 'Upcoming';
      case 'CANCELLED':
        return 'Cancelled';
      case 'HIATUS':
        return 'Hiatus';
      default:
        return s;
    }
  }

  String _compactNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
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
              if (_error != null)
                _buildError()
              else
                _buildScrollLayout(),
              MediaDetailsBackButton(focusNode: _backFocus),
            ],
          ),
        );
      },
    );
  }

  Widget _buildError() {
    return ShellErrorRetryPanel(
      message: _error!,
      onRetry: _load,
    );
  }

  Widget _buildScrollLayout() {
    final a = _data;
    final resumeEp = (_progress?['episodeNumber'] as num?)?.toInt();
    final rawPosMs = (_progress?['positionMs'] as num?)?.toInt();
    final rawDurMs = (_progress?['durationMs'] as num?)?.toInt();
    final canResumeSelected = _progress != null &&
        resumeEp == _selectedEpisode &&
        isInProgressResume(rawPosMs ?? 0, rawDurMs ?? 0);
    final heroHeight = DetailsTokens.heroHeight(context, showEpisodeRail: true);
    final posMs = canResumeSelected ? rawPosMs : null;
    final durMs = canResumeSelected ? rawDurMs : null;
    final policy = ShellScope.inputPolicyOf(context);
    final tvFocus = policy.useFocusableMoodChips;

    if (policy.heroPlayAutoFocus &&
        !_detailsHeroInitialFocusDone &&
        _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _detailsHeroInitialFocusDone) return;
        if (_heroPlayFocus.canRequestFocus) {
          _heroPlayFocus.requestFocus();
          _detailsHeroInitialFocusDone = true;
        }
      });
    }

    final heroFocusUp = _revealedDetailsHeroPlayFocus;
    final heroPopUp = tvFocus ? _focusDetailsBack : null;
    final showEpisodeRail = _episodesLoading || _episodes.isNotEmpty;
    final relatedOrder = showEpisodeRail ? 1 : 0;

    final episodePicker = showEpisodeRail
        ? MediaDetailsBody.padContent(
            context,
            TvSeasonEpisodePicker(
              tmdbId: a.id,
              seasonCount: 1,
              selectedSeason: 1,
              selectedEpisode: _selectedEpisode,
              isLoadingSeason: _episodesLoading,
              seasonData: null,
              watchedEpisodes: const {},
              fallbackPosterPath: a.coverUrl,
              customEpisodesBySeason: _episodeMaps(),
              episodeProgress: _episodeProgressMap(),
              onSeasonSelected: (_) {},
              onEpisodeSelected: (ep) {
                setState(() => _selectedEpisode = ep);
              },
              onEpisodePlay: (ep) {
                setState(() => _selectedEpisode = ep);
                _playSelected();
              },
              onToggleWatched: (_, _) {},
              tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
              tvSeasonRowId: 'seasons',
              tvEpisodeRowId: 'episodes',
              tvRowOrderBase: 0,
              tvFocusUp: heroFocusUp,
            ),
          )
        : MediaDetailsBody.padContent(
            context,
            Text(
              'No episodes available yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 14,
              ),
            ),
          );

    final scroll = SingleChildScrollView(
      controller: _detailsScrollController,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HubDetailsHero(
            backdropUrl: a.heroBackdrop,
            title: a.displayTitle,
            subtitle: a.titleNative.isNotEmpty && a.titleNative != a.displayTitle
                ? a.titleNative
                : null,
            genres: a.genres,
            metaParts: _metaParts(a),
            rating: (a.averageScore ?? 0) > 0 ? (a.averageScore! / 10) : null,
            overview: a.cleanDescription,
            facts: _facts(a),
            height: heroHeight,
            pageBottomChild: episodePicker,
            positionMs: posMs,
            durationMs: durMs,
            actionRow: DetailsHeroTvActionScope(
              tabId: MediaDetailsTv.tabId,
              itemCount: (_progress != null ? 2 : 1) + 2,
              onFocusUp: heroPopUp,
              child: Row(
                children: [
                  HubDetailsPlayRow(
                    label: canResumeSelected
                        ? 'Resume Ep $_selectedEpisode'
                        : 'Play Ep $_selectedEpisode',
                    enabled: _episodes.isNotEmpty,
                    onPlay: _playSelected,
                    focusNode: policy.heroPlayAutoFocus ? _heroPlayFocus : null,
                    onUpEdge: heroPopUp,
                    tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                    tvItemIndex: 0,
                  ),
                  if (_progress != null) ...[
                    const SizedBox(width: 10),
                    HeroPillIconGroup(
                      tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                      tvRowId: tvFocus ? MediaDetailsTv.heroRowId : null,
                      tvItemIndexStart: 1,
                      onUpEdge: heroPopUp,
                      slots: [
                        HeroPillIconSlot(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Clear progress',
                          onTap: _clearProgress,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(width: 10),
                  HeroPillSegmentedChoice<String>(
                    selected: _category,
                    onSelected: (cat) => setState(() => _category = cat),
                    tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                    tvRowId: tvFocus ? MediaDetailsTv.heroRowId : null,
                    tvItemIndexStart: _progress != null ? 2 : 1,
                    onUpEdge: heroPopUp,
                    segments: const [
                      HeroPillSegment(
                        value: 'sub',
                        label: 'SUB',
                        icon: Icons.subtitles_rounded,
                      ),
                      HeroPillSegment(
                        value: 'dub',
                        label: 'DUB',
                        icon: Icons.mic_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_related.isNotEmpty)
            MediaDetailsBody(
              backgroundColor: AppTheme.bgDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildRelated(
                    tvRowOrder: relatedOrder,
                    tvFocusUp: showEpisodeRail ? null : heroFocusUp,
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return MediaDetailsTvScope(
      heroPlayFocus: _heroPlayFocus,
      scrollController: _detailsScrollController,
      child: scroll,
    );
  }

  String _decodeEpisodeTitle(String title) => title
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  Widget _buildRelated({
    required int tvRowOrder,
    VoidCallback? tvFocusUp,
  }) {
    return HubCatalogSection<AnimeCard>(
      title: 'More Like This',
      items: _related,
      tvTabId: ShellScope.inputPolicyOf(context).useFocusableMoodChips
          ? MediaDetailsTv.tabId
          : null,
      tvRowId: 'related',
      tvRowOrder: tvRowOrder,
      tvFocusUp: tvFocusUp,
      cardBuilder: (context, r, index) => HubPosterCard(
        imageUrl: r.coverUrl,
        title: r.displayTitle,
        onTap: () => openAnimeDetails(context, r),
        listIndex: index,
        tvTabId: ShellScope.inputPolicyOf(context).useFocusableMoodChips
            ? MediaDetailsTv.tabId
            : null,
        tvRowId: 'related',
      ),
    );
  }
}
