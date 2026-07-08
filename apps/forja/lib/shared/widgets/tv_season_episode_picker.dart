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
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            const itemWidth = 120.0;
            const gap = 16.0;
            final totalWidth =
                seasonCount * itemWidth + (seasonCount - 1) * gap;
            final centered = totalWidth <= constraints.maxWidth;

            final cards = List.generate(seasonCount, (i) {
              final n = i + 1;
              final poster = seasonPosters[n];
              final posterUrl = poster != null && poster.isNotEmpty
                  ? TmdbApi.getImageUrl(poster)
                  : (fallbackPosterPath.isNotEmpty
                      ? TmdbApi.getBackdropUrl(fallbackPosterPath)
                      : null);
              final epCount = _episodeCountForSeason(n);
              final subtitle =
                  epCount > 0 ? '$epCount episodes' : 'Season $n';

              return _SeasonCard(
                key: ValueKey('season-$n'),
                seasonNumber: n,
                selected: selectedSeason == n,
                posterUrl: posterUrl,
                subtitle: subtitle,
                watched: _seasonFullyWatched(n),
                onTap: () => onSeasonSelected(n),
              );
            });

            if (centered) {
              return SizedBox(
                height: 200,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(width: gap),
                          cards[i],
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }

            return SizedBox(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: seasonCount,
                  separatorBuilder: (_, _) => const SizedBox(width: gap),
                  itemBuilder: (_, i) => cards[i],
                ),
              ),
            );
          },
        ),
        if (selectedSeason > 0) ...[
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: _buildEpisodePanel(context),
          ),
        ],
      ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Row(
          children: [
            Icon(Icons.playlist_play_rounded, color: Colors.white.withValues(alpha: 0.5), size: 16),
            const SizedBox(width: 6),
            Text(
              'Episodes · Season $selectedSeason',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: episodes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 20),
            itemBuilder: (_, i) {
              final ep = episodes[i];
              final epNum = (ep['episode_number'] ?? ep['episode']) as int;
              final title = (ep['name'] ?? ep['title'] ?? 'Episode $epNum').toString();
              final overview = (ep['overview'] ?? '').toString();
              final runtime = ep['runtime'] as int? ?? 0;
              final thumbnail = ep['still_path'] ?? ep['thumbnail'];
              final watched = _watchedKey(selectedSeason, epNum);
              final progKey = 'S${selectedSeason}_E$epNum';
              final prog = episodeProgress[progKey];
              final pos = prog?['position'] as int? ?? 0;
              final dur = prog?['duration'] as int? ?? (runtime > 0 ? runtime * 60000 : 0);

              return _EpisodeTile(
                key: ValueKey('ep-$selectedSeason-$epNum'),
                episodeNumber: epNum,
                title: title,
                overview: overview,
                runtime: runtime,
                thumbnail: thumbnail,
                selected: selectedEpisode == epNum,
                watched: watched,
                positionMs: pos,
                durationMs: dur,
                onTap: () => onEpisodeSelected(epNum),
                onToggleWatched: () => onToggleWatched(selectedSeason, epNum),
              );
            },
            ),
          ),
        ),
      ],
    );
  }
}

class _EpisodeTile extends StatefulWidget {
  const _EpisodeTile({
    super.key,
    required this.episodeNumber,
    required this.title,
    required this.overview,
    required this.runtime,
    required this.thumbnail,
    required this.selected,
    required this.watched,
    required this.positionMs,
    required this.durationMs,
    required this.onTap,
    required this.onToggleWatched,
  });

  final int episodeNumber;
  final String title;
  final String overview;
  final int runtime;
  final dynamic thumbnail;
  final bool selected;
  final bool watched;
  final int positionMs;
  final int durationMs;
  final VoidCallback onTap;
  final VoidCallback onToggleWatched;

  static const double _tileWidth = 200;
  static const double _thumbHeight = 112;
  static const double _hoverScale = 1.1;
  static const double _selectedScale = 1.06;

  @override
  State<_EpisodeTile> createState() => _EpisodeTileState();
}

class _EpisodeTileState extends State<_EpisodeTile> {
  bool _hovered = false;

  double get _scale {
    if (widget.selected && _hovered) return _EpisodeTile._selectedScale * 1.04;
    if (widget.selected) return _EpisodeTile._selectedScale;
    if (_hovered) return _EpisodeTile._hoverScale;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final showProgress = WatchProgressBar.isResumable(widget.positionMs, widget.durationMs);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: _EpisodeTile._tileWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _EpisodeTile._tileWidth,
                  height: _EpisodeTile._thumbHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: selected || _hovered
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(
                                alpha: selected ? 0.4 : 0.2,
                              ),
                              blurRadius: _hovered ? 18 : 12,
                              spreadRadius: _hovered ? 1 : 0,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.thumbnail != null
                            ? CachedNetworkImage(
                                imageUrl: widget.thumbnail.toString().startsWith('http')
                                    ? widget.thumbnail.toString()
                                    : TmdbApi.getStillUrl(widget.thumbnail.toString()),
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => _thumbFallback(),
                              )
                            : _thumbFallback(),
                        Positioned(
                          top: 6,
                          left: 8,
                          child: Text(
                            '${widget.episodeNumber}',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white.withValues(alpha: 0.4),
                              height: 1,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: widget.onToggleWatched,
                            child: Icon(
                              widget.watched ? Icons.visibility : Icons.visibility_outlined,
                              size: 18,
                              color: widget.watched ? AppTheme.primaryColor : Colors.white70,
                            ),
                          ),
                        ),
                        if (showProgress)
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
                                      value: (widget.positionMs / widget.durationMs).clamp(0.0, 1.0),
                                      minHeight: 3,
                                      backgroundColor: Colors.white24,
                                      valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${WatchProgressBar.formatMinutes(widget.durationMs - widget.positionMs)} left',
                                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected || _hovered ? Colors.white : Colors.white70,
                  ),
                ),
                if (widget.runtime > 0)
                  Text(
                    '${widget.runtime}m',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                if (widget.overview.isNotEmpty)
                  Text(
                    widget.overview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(color: Colors.white.withValues(alpha: 0.06));
  }
}

class _SeasonCard extends StatefulWidget {
  const _SeasonCard({
    super.key,
    required this.seasonNumber,
    required this.selected,
    required this.posterUrl,
    required this.subtitle,
    required this.watched,
    required this.onTap,
  });

  final int seasonNumber;
  final bool selected;
  final String? posterUrl;
  final String subtitle;
  final bool watched;
  final VoidCallback onTap;

  static const double _cardWidth = 120;
  static const double _posterSize = 120;
  static const double _hoverScale = 1.1;
  static const double _selectedScale = 1.06;

  @override
  State<_SeasonCard> createState() => _SeasonCardState();
}

class _SeasonCardState extends State<_SeasonCard> {
  bool _hovered = false;

  double get _scale {
    if (widget.selected && _hovered) return _SeasonCard._selectedScale * 1.04;
    if (widget.selected) return _SeasonCard._selectedScale;
    if (_hovered) return _SeasonCard._hoverScale;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.seasonNumber;
    final selected = widget.selected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: _SeasonCard._cardWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _SeasonCard._posterSize,
                  height: _SeasonCard._posterSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? AppTheme.primaryColor : Colors.white24,
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected || _hovered
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(
                                alpha: selected ? 0.35 : 0.18,
                              ),
                              blurRadius: _hovered ? 16 : 10,
                              spreadRadius: _hovered ? 1 : 0,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: widget.posterUrl != null
                        ? CachedNetworkImage(
                            imageUrl: widget.posterUrl!,
                            fit: BoxFit.cover,
                            width: _SeasonCard._posterSize,
                            height: _SeasonCard._posterSize,
                            errorWidget: (_, _, _) => _seasonPosterFallback(),
                          )
                        : _seasonPosterFallback(),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'S$n',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected || _hovered
                              ? Colors.white
                              : Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ),
                    Icon(
                      widget.watched
                          ? Icons.visibility
                          : Icons.visibility_outlined,
                      size: 14,
                      color: widget.watched
                          ? AppTheme.primaryColor
                          : Colors.white38,
                    ),
                  ],
                ),
                Text(
                  widget.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 10,
                    height: 1.2,
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
          ),
        ),
      ),
    );
  }

  Widget _seasonPosterFallback() {
    return Container(
      color: Colors.white.withValues(alpha: 0.06),
      child: const Center(
        child: Icon(Icons.movie_outlined, color: Colors.white24, size: 28),
      ),
    );
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
