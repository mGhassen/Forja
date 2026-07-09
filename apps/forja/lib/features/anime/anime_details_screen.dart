import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/features/anime/catalog/animerealms_extractor.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/horizontal_scroller.dart';
import 'package:forja/shared/widgets/hover_scale.dart';
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
    AppRouter.slideRoute((_) => AnimeDetailsScreen(anime: anime)),
  );
}

Future<T?> replaceAnimeDetails<T>(BuildContext context, AnimeCard anime) {
  return pushReplacementShellRoute<T, void>(
    context,
    AppRouter.slideRoute((_) => AnimeDetailsScreen(anime: anime)),
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

  AnimeCard? _full;
  List<AnimeEpisode> _episodes = [];
  List<AnimeCard> _related = [];
  List<AnimeCard> _seasons = [];
  Map<String, dynamic>? _progress;
  String? _error;

  String _category = 'sub';
  int _selectedEpisode = 1;

  MiruroEpisodes? _miruroEpisodes;
  List<String> _availableProviders = [];
  String _selectedProvider = 'kiwi';
  bool _usingAnimeRealms = false;
  bool _hasSub = true;
  bool _hasDub = false;
  bool _loadingStreams = true;
  Map<int, String> _thumbnails = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  AnimeCard get _data => _full ?? widget.anime;

  List<AnimeEpisode> _synthEpisodes(AnimeCard a) {
    final count = a.episodes ?? a.nextAiringEpisode?['episode'];
    final n = (count is int && count > 0) ? count : 1;
    final airedNow = a.nextAiringEpisode?['episode'];
    final maxAired = (airedNow is int && airedNow > 1) ? (airedNow - 1) : n;
    return List.generate(
      n,
      (i) => AnimeEpisode(
        number: i + 1,
        title: 'Episode ${i + 1}',
        aired: (i + 1) <= maxAired,
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _episodes = _synthEpisodes(widget.anime);
      _loadingStreams = true;
    });

    _service.getDetails(widget.anime.id).then((d) {
      if (!mounted) return;
      setState(() {
        _full = d;
        _thumbnails = _service.buildEpisodeThumbnailMap(d.streamingEpisodes);
        if (_episodes.isEmpty || _episodes.length < (d.episodes ?? 0)) {
          _episodes = _synthEpisodes(d);
        }
      });
    }).catchError((e) {
      if (mounted && _full == null) setState(() => _error = 'Failed to load: $e');
    });

    _loadMiruroEpisodes();

    _service.getRelations(widget.anime.id).then((r) {
      if (!mounted) return;
      setState(() => _related = r);
    }).catchError((_) {});

    _service.getProgress(widget.anime.id).then((p) {
      if (!mounted) return;
      setState(() {
        _progress = p;
      });
    }).catchError((_) {});

    _service.getSeasons(widget.anime.id).then((s) {
      if (!mounted) return;
      if (s.length > 1) setState(() => _seasons = s);
    }).catchError((_) {});
  }

  Future<void> _loadMiruroEpisodes() async {
    try {
      final episodes = await _service.getMiruroEpisodes(widget.anime.id);
      if (!mounted) return;
      if (episodes == null || episodes.providers.isEmpty) {
        await _loadFromAnimeRealms();
        return;
      }

      final providers = episodes.providers.keys.toList();
      final defaultProvider = AnimeService.defaultMiruroProvider(providers);
      final prov = episodes.providers[defaultProvider];
      final hasSub = prov != null && prov.subEpisodes.isNotEmpty;
      final hasDub = prov != null && prov.dubEpisodes.isNotEmpty;
      if (!hasSub && !hasDub) {
        await _loadFromAnimeRealms();
        return;
      }

      final category = hasSub ? 'sub' : 'dub';
      setState(() {
        _miruroEpisodes = episodes;
        _availableProviders = providers;
        _selectedProvider = defaultProvider;
        _usingAnimeRealms = false;
        _hasSub = hasSub;
        _hasDub = hasDub;
        _category = category;
        _episodes = _service.miruroEpisodesFor(
          episodes: episodes,
          provider: defaultProvider,
          category: category,
          thumbnails: _thumbnails,
        );
        _loadingStreams = false;
      });
      await _applyProgressPreferences();
    } catch (e) {
      debugPrint('[AnimeDetails] Miruro failed: $e');
      if (mounted) await _loadFromAnimeRealms();
    }
  }

  Future<void> _loadFromAnimeRealms() async {
    try {
      final extractor = AnimeRealmsExtractor();
      final mappings = await extractor.getMappings(widget.anime.id);
      final providers = AnimeRealmsExtractor.getProviderNames(mappings);
      if (!mounted) return;

      final count = _data.episodes ?? widget.anime.episodes ?? 0;
      final n = count > 0 ? count : 1;
      final episodes = List.generate(
        n,
        (i) => AnimeEpisode(
          number: i + 1,
          title: 'Episode ${i + 1}',
          aired: true,
          thumbnail: _thumbnails[i + 1],
        ),
      );

      setState(() {
        _usingAnimeRealms = true;
        _miruroEpisodes = null;
        _availableProviders = providers;
        _selectedProvider =
            providers.isNotEmpty ? providers.first : 'allmanga';
        _hasSub = true;
        _hasDub = false;
        _category = 'sub';
        _episodes = episodes;
        _loadingStreams = false;
      });
      await _applyProgressPreferences();
    } catch (e) {
      debugPrint('[AnimeDetails] AnimeRealms failed: $e');
      if (mounted) setState(() => _loadingStreams = false);
    }
  }

  Future<void> _applyProgressPreferences() async {
    final p = _progress ?? await _service.getProgress(widget.anime.id);
    if (!mounted || p == null) return;
    final prov = (p['provider'] as String?)?.trim();
    if (prov != null && prov.isNotEmpty && _availableProviders.contains(prov)) {
      _onProviderChanged(prov);
    }
    final cat = p['category'] as String?;
    if (cat == 'sub' || cat == 'dub') {
      _onCategoryChanged(cat!);
    }
    final ep = (p['episodeNumber'] as num?)?.toInt();
    if (ep != null && ep > 0) {
      setState(() => _selectedEpisode = ep);
    }
  }

  void _onProviderChanged(String provider) {
    if (_usingAnimeRealms) {
      setState(() => _selectedProvider = provider);
      return;
    }
    final episodes = _miruroEpisodes;
    if (episodes == null) return;
    final prov = episodes.providers[provider];
    final hasSub = prov != null && prov.subEpisodes.isNotEmpty;
    final hasDub = prov != null && prov.dubEpisodes.isNotEmpty;
    var category = _category;
    if (category == 'sub' && !hasSub && hasDub) category = 'dub';
    if (category == 'dub' && !hasDub && hasSub) category = 'sub';
    setState(() {
      _selectedProvider = provider;
      _hasSub = hasSub;
      _hasDub = hasDub;
      _category = category;
      _episodes = _service.miruroEpisodesFor(
        episodes: episodes,
        provider: provider,
        category: category,
        thumbnails: _thumbnails,
      );
    });
  }

  void _onCategoryChanged(String category) {
    if (category == _category) return;
    if (category == 'sub' && !_hasSub) return;
    if (category == 'dub' && !_hasDub) return;
    setState(() => _category = category);
    if (_usingAnimeRealms || _miruroEpisodes == null) return;
    setState(() {
      _episodes = _service.miruroEpisodesFor(
        episodes: _miruroEpisodes!,
        provider: _selectedProvider,
        category: category,
        thumbnails: _thumbnails,
      );
    });
  }

  String? _streamIdFor(int episodeNumber) {
    for (final e in _episodes) {
      if (e.number == episodeNumber) return e.streamId;
    }
    return null;
  }

  void _play(int epNumber) {
    openAnimePlayer(
      context,
      anime: _data,
      episodeNumber: epNumber,
      category: _category,
      provider: _selectedProvider,
      useAnimeRealms: _usingAnimeRealms,
      episodeId: _streamIdFor(epNumber),
      allEpisodes: _episodes,
    );
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
              const MediaDetailsBackButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: ForjaShellColors.sectionAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollLayout() {
    final a = _data;
    final hasProgress = _progress != null;
    final resumeEp =
        hasProgress ? (_progress!['episodeNumber'] as num?)?.toInt() : null;
    final heroHeight = ShellTokens.detailsHeroHeight(context, showEpisodeRail: true);
    final posMs = (_progress?['positionMs'] as num?)?.toInt();
    final durMs = (_progress?['durationMs'] as num?)?.toInt();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HubDetailsHero(
            backdropUrl: a.bannerOrCover,
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
            positionMs: posMs,
            durationMs: durMs,
            actionRow: Row(
              children: [
                HubDetailsPlayRow(
                  label: hasProgress && resumeEp != null
                      ? 'Resume Ep $resumeEp'
                      : 'Play Ep 1',
                  enabled: _episodes.isNotEmpty,
                  onPlay: () => _play(resumeEp ?? 1),
                ),
                const SizedBox(width: 10),
                _buildCategoryToggle(compact: true),
              ],
            ),
          ),
          MediaDetailsBody(
            backgroundColor: AppTheme.bgDark,
            bodyOverlap: ShellTokens.detailsHeroBodyOverlapWithEpisodes,
            topSpacing: ShellTokens.detailsBodyTopSpacingWithEpisodes,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_seasons.length > 1) ...[
                  _buildSeasonsRail(),
                  const SizedBox(height: ShellTokens.detailsSectionSpacing),
                ],
                if (_availableProviders.length > 1) ...[
                  _buildProviderPicker(),
                  const SizedBox(height: ShellTokens.detailsSectionSpacing),
                ],
                if (_loadingStreams)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (_episodes.isNotEmpty)
                  TvSeasonEpisodePicker(
                    tmdbId: a.id,
                    seasonCount: 1,
                    selectedSeason: 1,
                    selectedEpisode: _selectedEpisode,
                    isLoadingSeason: false,
                    seasonData: null,
                    watchedEpisodes: const {},
                    fallbackPosterPath: a.coverUrl,
                    customEpisodesBySeason: _episodeMaps(),
                    episodeProgress: _episodeProgressMap(),
                    onSeasonSelected: (_) {},
                    onEpisodeSelected: (ep) {
                      setState(() => _selectedEpisode = ep);
                      final match = _episodes.where((e) => e.number == ep);
                      if (match.isNotEmpty && match.first.aired) {
                        _play(ep);
                      }
                    },
                    onToggleWatched: (_, _) {},
                  )
                else
                  Text(
                    'No episodes available yet',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 14,
                    ),
                  ),
                if (_related.isNotEmpty) ...[
                  const SizedBox(height: ShellTokens.detailsSectionSpacing),
                  _buildRelated(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _decodeEpisodeTitle(String title) => title
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  Widget _buildCategoryToggle({bool compact = false}) {
    if (!_hasSub && !_hasDub) return const SizedBox.shrink();
    final radius = compact ? 20.0 : 24.0;
    final innerRadius = compact ? 16.0 : 20.0;
    final height = compact ? 40.0 : null;
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: shellChipDecoration(selected: false, radius: radius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasSub)
            _categoryButton('sub', 'SUB', Icons.subtitles_rounded,
                compact: compact, radius: innerRadius),
          if (_hasDub)
            _categoryButton('dub', 'DUB', Icons.mic_rounded,
                compact: compact, radius: innerRadius),
        ],
      ),
    );
  }

  Widget _categoryButton(
    String id,
    String label,
    IconData icon, {
    bool compact = false,
    required double radius,
  }) {
    final selected = _category == id;
    final cinematic = ForjaShellColors.cinematic;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: () => _onCategoryChanged(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 16,
            vertical: compact ? 8 : 10,
          ),
          decoration: shellChipDecoration(selected: selected, radius: radius),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: compact ? 14 : 16,
                color: selected ? cinematic.textPrimary : cinematic.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? cinematic.textPrimary : cinematic.textSecondary,
                  fontSize: compact ? 11 : 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProviderPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SERVER',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: HorizontalScroller(
            height: 36,
            itemCount: _availableProviders.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final p = _availableProviders[i];
              final selected = _selectedProvider == p;
              return HoverScale(
                radius: 10,
                onTap: () => _onProviderChanged(p),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  alignment: Alignment.center,
                  decoration: shellChipDecoration(selected: selected, radius: 10),
                  child: Text(
                    p.toUpperCase(),
                    style: TextStyle(
                      color: selected
                          ? ForjaShellColors.cinematic.textPrimary
                          : ForjaShellColors.cinematic.textSecondary,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonsRail() {
    final currentId = widget.anime.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Related Series', style: ShellSectionTitle.titleStyle),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: HorizontalScroller(
            height: 36,
            itemCount: _seasons.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final s = _seasons[i];
              final selected = s.id == currentId;
              return HoverScale(
                radius: 18,
                onTap: () {
                  if (selected) return;
                  replaceAnimeDetails(context, s);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: shellChipDecoration(selected: selected, radius: 18),
                  child: Text(
                    'S${i + 1}\u00a0\u00b7\u00a0${s.displayTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? ForjaShellColors.cinematic.textPrimary
                          : ForjaShellColors.cinematic.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRelated() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('More Like This', style: ShellSectionTitle.titleStyle),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: HorizontalScroller(
            height: 220,
            itemCount: _related.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final r = _related[i];
              return HoverScale(
                radius: 12,
                onTap: () => openAnimeDetails(context, r),
                child: SizedBox(
                  width: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: r.coverUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: r.coverUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                )
                              : ColoredBox(color: AppTheme.bgCard),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        r.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
