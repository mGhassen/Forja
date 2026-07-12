import 'package:flutter/material.dart';

import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/shell_error_retry_panel.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_hero.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_play_row.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/widgets/media_details_body.dart';
import 'package:forja/shared/widgets/tv_season_episode_picker.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'asian_drama_player_screen.dart';

Future<T?> openAsianDramaDetails<T>(BuildContext context, KdramaCard drama) {
  return pushShellRoute<T>(
    context,
    AppRouter.slideShellRoute((_) => AsianDramaDetailsScreen(drama: drama)),
  );
}

Future<T?> replaceAsianDramaDetails<T>(BuildContext context, KdramaCard drama) {
  return pushReplacementShellRoute<T, void>(
    context,
    AppRouter.slideShellRoute((_) => AsianDramaDetailsScreen(drama: drama)),
  );
}

class AsianDramaDetailsScreen extends StatefulWidget {
  final KdramaCard drama;
  const AsianDramaDetailsScreen({super.key, required this.drama});

  @override
  State<AsianDramaDetailsScreen> createState() =>
      _AsianDramaDetailsScreenState();
}

class _AsianDramaDetailsScreenState extends State<AsianDramaDetailsScreen> {
  final KissKhService _service = KissKhService();
  final ScrollController _detailsScrollController = ScrollController();
  final FocusNode _heroPlayFocus = FocusNode(debugLabel: 'asian-drama-details-play');
  KdramaDetails? _details;
  Map<String, dynamic>? _progress;
  bool _loading = true;
  String? _error;
  int _selectedEpisode = 1;

  @override
  void initState() {
    super.initState();
    KissKhService.watchHistoryRevision.addListener(_onHistoryChanged);
    _load();
  }

  @override
  void dispose() {
    KissKhService.watchHistoryRevision.removeListener(_onHistoryChanged);
    _heroPlayFocus.dispose();
    _detailsScrollController.dispose();
    super.dispose();
  }

  void _revealedDetailsHeroPlayFocus() {
    void focusPlay() {
      if (!mounted) return;
      if (_heroPlayFocus.canRequestFocus) {
        _heroPlayFocus.requestFocus();
      }
    }

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

  void _onHistoryChanged() => _refreshProgress();

  Future<void> _refreshProgress() async {
    try {
      final p = await _service.getProgress(widget.drama.id);
      if (!mounted) return;
      setState(() {
        _progress = p;
        final ep = (p?['episodeNumber'] as num?)?.toInt();
        if (ep != null && ep > 0) _selectedEpisode = ep;
      });
    } catch (_) {}
  }

  Future<void> _load({int attempt = 0}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getDetails(widget.drama.id),
        _service.getProgress(widget.drama.id),
      ]);
      if (!mounted) return;
      final det = results[0] as KdramaDetails;
      final p = results[1] as Map<String, dynamic>?;
      setState(() {
        _details = det;
        _progress = p;
        _loading = false;
        final ep = (p?['episodeNumber'] as num?)?.toInt();
        if (ep != null && ep > 0) _selectedEpisode = ep;
      });
    } catch (e) {
      if (attempt == 0) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) return _load(attempt: 1);
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyLoadError(e);
      });
    }
  }

  String _friendlyLoadError(Object e) {
    final raw = '$e';
    if (raw.contains('→ 429')) {
      return 'kisskh is busy — wait a moment and tap Retry.';
    }
    if (RegExp(r'→ 5\d\d').hasMatch(raw)) {
      return 'kisskh is temporarily unavailable — tap Retry.';
    }
    return raw;
  }

  void _play(KdramaEpisode ep, {Duration? startPosition}) {
    final det = _details!;
    openAsianDramaPlayer(
      context,
      drama: det.toCard(),
      episode: ep,
      allEpisodes: det.episodes,
      startPosition: startPosition,
    ).then((_) => _refreshProgress());
  }

  void _playFirst() {
    final det = _details;
    if (det == null || det.episodes.isEmpty) return;
    _play(det.episodes.first);
  }

  void _resume() {
    final det = _details;
    final p = _progress;
    if (det == null || p == null) return;
    final epNum = (p['episodeNumber'] as num?)?.toDouble() ?? 1.0;
    final epId = (p['episodeId'] as num?)?.toInt();
    final posMs = (p['positionMs'] as num?)?.toInt() ?? 0;
    final durMs = (p['durationMs'] as num?)?.toInt() ?? 0;
    final ep = det.episodeForResume(
      episodeNumber: epNum,
      episodeId: epId,
    );
    if (ep == null) return;
    Duration? start;
    if (posMs > 5000) {
      final clamped =
          (durMs > 0 && posMs > durMs - 30000) ? (durMs - 30000) : posMs;
      start = Duration(milliseconds: (clamped - 3000).clamp(0, 1 << 31));
    }
    _play(ep, startPosition: start);
  }

  Future<void> _clearProgress() async {
    await _service.removeFromHistory(widget.drama.id);
    if (mounted) setState(() => _progress = null);
  }

  List<String> _metaParts(KdramaDetails det) {
    final typeBadge = det.toCard().heroMediaBadge;
    return [
      ?det.year,
      if (det.country.isNotEmpty) det.country,
      ?typeBadge,
      if (det.status.isNotEmpty) det.status,
      if (det.episodesCount > 0) '${det.episodesCount} eps',
    ];
  }

  List<MapEntry<String, String>> _facts(KdramaDetails det) {
    final typeBadge = det.toCard().heroMediaBadge;
    return [
      if (det.releaseDate.isNotEmpty)
        MapEntry('Released', _formatDate(det.releaseDate)),
      if (det.country.isNotEmpty) MapEntry('Country', det.country),
      if (typeBadge != null) MapEntry('Type', typeBadge),
      if (det.status.isNotEmpty) MapEntry('Status', det.status),
      if (det.label != null && det.label!.isNotEmpty)
        MapEntry('Label', det.label!),
    ];
  }

  Map<int, List<Map<String, dynamic>>>? _episodeMaps(KdramaDetails det) {
    if (det.episodes.isEmpty) return null;
    return {
      1: [
        for (var i = 0; i < det.episodes.length; i++)
          {
            'episode_number': i + 1,
            'name': 'Episode ${det.episodes[i].displayNumber}',
            'overview': '',
            'runtime': 0,
          },
      ],
    };
  }

  Map<int, KdramaEpisode> _episodeLookup(KdramaDetails det) {
    return {for (var i = 0; i < det.episodes.length; i++) i + 1: det.episodes[i]};
  }

  Map<String, Map<String, dynamic>> _episodeProgressMap() {
    final p = _progress;
    if (p == null || _details == null) return const {};
    final epNum = (p['episodeNumber'] as num?)?.toDouble();
    if (epNum == null) return const {};
    final index = _details!.episodes.indexWhere((e) => e.number == epNum);
    if (index < 0) return const {};
    final pos = (p['positionMs'] as num?)?.toInt() ?? 0;
    final dur = (p['durationMs'] as num?)?.toInt() ?? 0;
    return {
      'S1_E${index + 1}': {'position': pos, 'duration': dur},
    };
  }

  String _formatDate(String iso) {
    if (iso.length < 10) return iso;
    return iso.substring(0, 10);
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
                _buildError()
              else
                _buildScrollLayout(),
              const MediaDetailsBackButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildError() {
    return ShellErrorRetryPanel(
      message: 'Failed to load:\n$_error',
      onRetry: _load,
      statusIconSize: 56,
    );
  }

  Widget _buildScrollLayout() {
    final det = _details!;
    final hasResume = _progress != null;
    final heroHeight = ShellTokens.detailsHeroHeight(context, showEpisodeRail: true);
    final posMs = (_progress?['positionMs'] as num?)?.toInt();
    final durMs = (_progress?['durationMs'] as num?)?.toInt();
    final lookup = _episodeLookup(det);

    final heroFocusUp = _revealedDetailsHeroPlayFocus;

    final scroll = SingleChildScrollView(
      controller: _detailsScrollController,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HubDetailsHero(
            backdropUrl: det.cover,
            title: det.title,
            metaParts: _metaParts(det),
            overview: det.description.trim(),
            facts: _facts(det),
            height: heroHeight,
            bodyOverlap: ShellTokens.detailsHeroBodyOverlapWithEpisodes,
            positionMs: posMs,
            durationMs: durMs,
            actionRow: DetailsHeroTvActionScope(
              tabId: MediaDetailsTv.tabId,
              itemCount: hasResume ? 2 : 1,
              onFocusUp: heroFocusUp,
              child: Row(
                children: [
                  HubDetailsPlayRow(
                    label: hasResume ? 'Resume' : 'Play',
                    enabled: det.episodes.isNotEmpty,
                    onPlay: hasResume ? _resume : _playFirst,
                    focusNode: _heroPlayFocus,
                    tvTabId: MediaDetailsTv.tabId,
                    tvItemIndex: 0,
                  ),
                  if (hasResume) ...[
                    const SizedBox(width: 10),
                    HeroPillIconGroup(
                      tvTabId: MediaDetailsTv.tabId,
                      tvRowId: MediaDetailsTv.heroRowId,
                      tvItemIndexStart: 1,
                      slots: [
                        HeroPillIconSlot(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Clear progress',
                          onTap: _clearProgress,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          MediaDetailsBody(
            backgroundColor: AppTheme.bgDark,
            bodyOverlap: ShellTokens.detailsHeroBodyOverlapWithEpisodes,
            topSpacing: ShellTokens.detailsBodyTopSpacingWithEpisodes,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (det.episodes.isNotEmpty)
                  MediaDetailsBody.padContent(
                    context,
                    TvSeasonEpisodePicker(
                      tmdbId: det.id,
                      seasonCount: 1,
                      selectedSeason: 1,
                      selectedEpisode: _selectedEpisode,
                      isLoadingSeason: false,
                      seasonData: null,
                      watchedEpisodes: const {},
                      fallbackPosterPath: det.cover,
                      customEpisodesBySeason: _episodeMaps(det),
                      episodeProgress: _episodeProgressMap(),
                      onSeasonSelected: (_) {},
                      onEpisodeSelected: (ep) {
                        setState(() => _selectedEpisode = ep);
                        final match = lookup[ep];
                        if (match != null) _play(match);
                      },
                      onToggleWatched: (_, _) {},
                      tvTabId: MediaDetailsTv.tabId,
                      tvSeasonRowId: 'seasons',
                      tvEpisodeRowId: 'episodes',
                      tvRowOrderBase: 0,
                      tvFocusUp: heroFocusUp,
                    ),
                  )
                else
                  MediaDetailsBody.padContent(
                    context,
                    Text(
                      'No episodes available yet',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 14,
                      ),
                    ),
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
}
