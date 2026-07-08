import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/watch_progress_bar.dart';
import 'package:rust/rust.dart';

typedef SeasonSelectCallback = void Function(int season);
typedef EpisodeSelectCallback = void Function(int episode);
typedef EpisodeWatchedToggle = void Function(int season, int episode);

class TvSeasonEpisodePicker extends StatelessWidget {
  const TvSeasonEpisodePicker({
    super.key,
    required this.tmdbId,
    required this.seasonCount,
    required this.selectedSeason,
    required this.selectedEpisode,
    required this.isLoadingSeason,
    required this.seasonData,
    required this.watchedEpisodes,
    required this.fallbackPosterPath,
    required this.onSeasonSelected,
    required this.onEpisodeSelected,
    required this.onToggleWatched,
    this.seasonPosters = const {},
    this.episodeProgress = const {},
    this.customEpisodesBySeason,
  });

  final int tmdbId;
  final int seasonCount;
  final int selectedSeason;
  final int selectedEpisode;
  final bool isLoadingSeason;
  final Map<String, dynamic>? seasonData;
  final Set<String> watchedEpisodes;
  final String fallbackPosterPath;
  final SeasonSelectCallback onSeasonSelected;
  final EpisodeSelectCallback onEpisodeSelected;
  final EpisodeWatchedToggle onToggleWatched;
  final Map<int, String> seasonPosters;
  final Map<String, Map<String, dynamic>> episodeProgress;
  final Map<int, List<Map<String, dynamic>>>? customEpisodesBySeason;

  List<dynamic> get _episodes {
    if (customEpisodesBySeason != null) {
      return customEpisodesBySeason![selectedSeason] ?? [];
    }
    if (seasonData == null) return [];
    if (seasonData!['episodes'] != null) {
      return seasonData!['episodes'] as List;
    }
    final bySeason = seasonData!['episodesBySeason'];
    if (bySeason is Map) {
      return bySeason[selectedSeason] as List? ?? [];
    }
    return [];
  }

  int _episodeCountForSeason(int season) {
    if (customEpisodesBySeason != null) {
      return customEpisodesBySeason![season]?.length ?? 0;
    }
    if (season == selectedSeason) return _episodes.length;
    return 0;
  }

  bool _seasonFullyWatched(int season) {
    final eps = customEpisodesBySeason?[season];
    if (eps != null && eps.isNotEmpty) {
      for (final ep in eps) {
        final n = (ep['episode_number'] ?? ep['episode']) as int;
        if (!_watchedKey(season, n)) return false;
      }
      return true;
    }
    if (season != selectedSeason || _episodes.isEmpty) return false;
    for (final ep in _episodes) {
      final n = (ep['episode_number'] ?? ep['episode']) as int;
      if (!_watchedKey(season, n)) return false;
    }
    return _episodes.isNotEmpty;
  }

  bool _watchedKey(int season, int episode) {
    return watchedEpisodes.contains('${tmdbId}_S${season}_E$episode');
  }

  @override
  Widget build(BuildContext context) {
    if (seasonCount <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.layers_outlined, color: Colors.white.withValues(alpha: 0.5), size: 16),
            const SizedBox(width: 6),
            const Text(
              'Seasons',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: seasonCount,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final n = i + 1;
              final selected = selectedSeason == n;
              final poster = seasonPosters[n];
              final posterUrl = poster != null && poster.isNotEmpty
                  ? TmdbApi.getImageUrl(poster)
                  : (fallbackPosterPath.isNotEmpty
                      ? TmdbApi.getBackdropUrl(fallbackPosterPath)
                      : null);
              final epCount = _episodeCountForSeason(n);
              final countLabel = epCount > 0 ? '$epCount episodes' : 'Season $n';

              return GestureDetector(
                onTap: () => onSeasonSelected(n),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 108,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? AppTheme.primaryColor : Colors.white24,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                            child: AspectRatio(
                              aspectRatio: 2 / 3,
                              child: posterUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: posterUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) => _posterFallback(),
                                    )
                                  : _posterFallback(),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Season $n',
                                        style: TextStyle(
                                          color: selected ? Colors.white : Colors.white70,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      _seasonFullyWatched(n)
                                          ? Icons.visibility
                                          : Icons.visibility_outlined,
                                      size: 14,
                                      color: _seasonFullyWatched(n)
                                          ? AppTheme.primaryColor
                                          : Colors.white38,
                                    ),
                                  ],
                                ),
                                Text(
                                  countLabel,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      CustomPaint(
                        size: const Size(16, 8),
                        painter: _CaretPainter(AppTheme.primaryColor),
                      )
                    else
                      const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        ),
        if (selectedSeason > 0) ...[
          const SizedBox(height: 8),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: _buildEpisodePanel(context),
          ),
        ],
      ],
    );
  }

  Widget _posterFallback() {
    return Container(
      color: Colors.white.withValues(alpha: 0.06),
      child: const Center(
        child: Icon(Icons.movie_outlined, color: Colors.white24, size: 28),
      ),
    );
  }

  Widget _buildEpisodePanel(BuildContext context) {
    if (isLoadingSeason) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2),
        ),
      );
    }

    final episodes = _episodes;
    if (episodes.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Episodes',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: episodes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final ep = episodes[i];
                final epNum = (ep['episode_number'] ?? ep['episode']) as int;
                final selected = selectedEpisode == epNum;
                final title = (ep['name'] ?? ep['title'] ?? 'Episode $epNum').toString();
                final overview = (ep['overview'] ?? '').toString();
                final runtime = ep['runtime'] as int? ?? 0;
                final thumbnail = ep['still_path'] ?? ep['thumbnail'];
                final watched = _watchedKey(selectedSeason, epNum);
                final progKey = 'S${selectedSeason}_E$epNum';
                final prog = episodeProgress[progKey];
                final pos = prog?['position'] as int? ?? 0;
                final dur = prog?['duration'] as int? ?? (runtime > 0 ? runtime * 60000 : 0);

                return GestureDetector(
                  onTap: () => onEpisodeSelected(epNum),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? AppTheme.primaryColor : Colors.white12,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                                child: thumbnail != null
                                    ? CachedNetworkImage(
                                        imageUrl: thumbnail.toString().startsWith('http')
                                            ? thumbnail.toString()
                                            : TmdbApi.getStillUrl(thumbnail.toString()),
                                        fit: BoxFit.cover,
                                        errorWidget: (_, _, _) => _thumbFallback(),
                                      )
                                    : _thumbFallback(),
                              ),
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Text(
                                  '$epNum',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white.withValues(alpha: 0.35),
                                    height: 1,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: GestureDetector(
                                  onTap: () => onToggleWatched(selectedSeason, epNum),
                                  child: Icon(
                                    watched ? Icons.visibility : Icons.visibility_outlined,
                                    size: 18,
                                    color: watched ? AppTheme.primaryColor : Colors.white70,
                                  ),
                                ),
                              ),
                              if (WatchProgressBar.isResumable(pos, dur))
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    color: Colors.black54,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(2),
                                          child: LinearProgressIndicator(
                                            value: (pos / dur).clamp(0.0, 1.0),
                                            minHeight: 3,
                                            backgroundColor: Colors.white24,
                                            valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${WatchProgressBar.formatMinutes(dur - pos)} left',
                                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? Colors.white : Colors.white70,
                                ),
                              ),
                              if (runtime > 0)
                                Text(
                                  '${runtime}m',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontSize: 10,
                                  ),
                                ),
                              if (overview.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  overview,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 10,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ],
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
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(color: Colors.white.withValues(alpha: 0.06));
  }
}

class _CaretPainter extends CustomPainter {
  _CaretPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CaretPainter oldDelegate) => oldDelegate.color != color;
}
