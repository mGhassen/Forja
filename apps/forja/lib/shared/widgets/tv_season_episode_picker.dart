import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/shell_section_title.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/episode_range_bar.dart';
import 'package:forja/shared/widgets/watch_progress_bar.dart';
import 'package:rust/rust.dart';

typedef SeasonSelectCallback = void Function(int season);
typedef EpisodeSelectCallback = void Function(int episode);
typedef EpisodeWatchedToggle = void Function(int season, int episode);

class TvSeasonEpisodePicker extends StatefulWidget {
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

  @override
  State<TvSeasonEpisodePicker> createState() => _TvSeasonEpisodePickerState();
}

class _TvSeasonEpisodePickerState extends State<TvSeasonEpisodePicker> {
  bool _oldestFirst = true;
  int _episodeChunk = 0;
  final ScrollController _episodeScrollController = ScrollController();

  static const double _episodeCardStride = _EpisodeCard.cardWidth + 16;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncEpisodeChunk());
  }

  void _syncEpisodeChunk() {
    if (!mounted || widget.isLoadingSeason || _sortedEpisodes.isEmpty) return;
    final chunk = _chunkIndexForEpisode(widget.selectedEpisode);
    if (chunk != _episodeChunk) {
      setState(() => _episodeChunk = chunk);
    }
    _scrollToSelectedEpisode();
  }

  @override
  void dispose() {
    _episodeScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TvSeasonEpisodePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSeason != widget.selectedSeason) {
      _episodeChunk = _chunkIndexForEpisode(widget.selectedEpisode);
    } else if (oldWidget.selectedEpisode != widget.selectedEpisode) {
      final chunk = _chunkIndexForEpisode(widget.selectedEpisode);
      if (chunk != _episodeChunk) _episodeChunk = chunk;
    }
    if (oldWidget.selectedEpisode != widget.selectedEpisode ||
        oldWidget.selectedSeason != widget.selectedSeason ||
        oldWidget.isLoadingSeason != widget.isLoadingSeason ||
        oldWidget.customEpisodesBySeason != widget.customEpisodesBySeason ||
        oldWidget.seasonData != widget.seasonData) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncEpisodeChunk());
    }
  }

  int _episodeNumberAt(dynamic ep) =>
      (ep['episode_number'] ?? ep['episode']) as int;

  List<int> get _episodeNumbers =>
      _sortedEpisodes.map(_episodeNumberAt).toList();

  List<EpisodeRange> get _episodeRanges =>
      buildEpisodeRangesForNumbers(_episodeNumbers);

  List<dynamic> get _visibleEpisodes => filterEpisodeChunkByNumber(
        _sortedEpisodes,
        _episodeNumberAt,
        _episodeChunk,
      );

  int _chunkIndexForEpisode(int episode) =>
      episodeChunkIndexForNumber(episode);

  void _selectChunk(int chunk) {
    if (chunk == _episodeChunk) return;
    setState(() => _episodeChunk = chunk);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chunkIndexForEpisode(widget.selectedEpisode) == chunk) {
        _scrollToSelectedEpisode();
      } else if (_episodeScrollController.hasClients) {
        _episodeScrollController.jumpTo(0);
      }
    });
  }

  List<dynamic> get _episodes {
    if (widget.customEpisodesBySeason != null) {
      return widget.customEpisodesBySeason![widget.selectedSeason] ?? [];
    }
    if (widget.seasonData == null) return [];
    if (widget.seasonData!['episodes'] != null) {
      return widget.seasonData!['episodes'] as List;
    }
    final bySeason = widget.seasonData!['episodesBySeason'];
    if (bySeason is Map) {
      return bySeason[widget.selectedSeason] as List? ?? [];
    }
    return [];
  }

  List<dynamic> get _sortedEpisodes {
    final episodes = List<dynamic>.from(_episodes);
    episodes.sort((a, b) {
      final aNum = (a['episode_number'] ?? a['episode']) as int;
      final bNum = (b['episode_number'] ?? b['episode']) as int;
      return _oldestFirst ? aNum.compareTo(bNum) : bNum.compareTo(aNum);
    });
    return episodes;
  }

  bool _watchedKey(int season, int episode) {
    return widget.watchedEpisodes.contains('${widget.tmdbId}_S${season}_E$episode');
  }

  void _scrollToSelectedEpisode() {
    if (!_episodeScrollController.hasClients) return;
    final chunk = _chunkIndexForEpisode(widget.selectedEpisode);
    if (chunk != _episodeChunk) {
      setState(() => _episodeChunk = chunk);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedEpisode());
      return;
    }
    final index = _visibleEpisodes.indexWhere(
      (ep) => _episodeNumberAt(ep) == widget.selectedEpisode,
    );
    if (index < 0) return;
    final target = (index * _episodeCardStride)
        .clamp(0.0, _episodeScrollController.position.maxScrollExtent);
    _episodeScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  bool _absorbHorizontalScroll(ScrollNotification notification) {
    return notification.metrics.axis == Axis.horizontal;
  }

  String? _resolveThumbnail(dynamic thumb, String fallback) {
    final value = thumb?.toString().trim();
    if (value != null && value.isNotEmpty && value != 'null') return value;
    final fb = fallback.trim();
    return fb.isNotEmpty ? fb : null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.seasonCount <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Episodes', style: ShellSectionTitle.titleStyle),
            ),
            _PickerPill(
              onTap: () => setState(() => _oldestFirst = !_oldestFirst),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swap_vert_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _oldestFirst ? 'Oldest' : 'Newest',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _SeasonPill(
              seasonCount: widget.seasonCount,
              selectedSeason: widget.selectedSeason,
              onSeasonSelected: (season) {
                setState(() => _episodeChunk = 0);
                widget.onSeasonSelected(season);
              },
            ),
          ],
        ),
        if (showEpisodeRangeBar(_episodeNumbers)) ...[
          const SizedBox(height: 12),
          EpisodeRangeBar(
            ranges: _episodeRanges,
            selectedIndex: _episodeChunk,
            onSelected: _selectChunk,
          ),
        ],
        const SizedBox(height: 20),
        if (widget.isLoadingSeason)
          SizedBox(
            height: 220,
            child: Center(
              child: CircularProgressIndicator(
                color: ForjaShellColors.sectionAccent,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_visibleEpisodes.isEmpty)
          const SizedBox.shrink()
        else
          SizedBox(
            height: 228,
            child: NotificationListener<ScrollNotification>(
              onNotification: _absorbHorizontalScroll,
              child: ListView.separated(
                controller: _episodeScrollController,
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: _visibleEpisodes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (_, i) {
                final ep = _visibleEpisodes[i];
                final epNum = (ep['episode_number'] ?? ep['episode']) as int;
                final title =
                    (ep['name'] ?? ep['title'] ?? 'Episode $epNum').toString();
                final overview = (ep['overview'] ?? '').toString();
                final runtime = ep['runtime'] as int? ?? 0;
                final thumbnail = _resolveThumbnail(
                  ep['still_path'] ?? ep['thumbnail'],
                  widget.fallbackPosterPath,
                );
                final watched = _watchedKey(widget.selectedSeason, epNum);
                final progKey = 'S${widget.selectedSeason}_E$epNum';
                final prog = widget.episodeProgress[progKey];
                final pos = prog?['position'] as int? ?? 0;
                final dur = prog?['duration'] as int? ??
                    (runtime > 0 ? runtime * 60000 : 0);

                return _EpisodeCard(
                  key: ValueKey('ep-${widget.selectedSeason}-$epNum'),
                  episodeNumber: epNum,
                  title: title,
                  overview: overview,
                  runtime: runtime,
                  thumbnail: thumbnail,
                  selected: widget.selectedEpisode == epNum,
                  watched: watched,
                  positionMs: pos,
                  durationMs: dur,
                  onTap: () => widget.onEpisodeSelected(epNum),
                  onToggleWatched: () =>
                      widget.onToggleWatched(widget.selectedSeason, epNum),
                );
              },
              ),
            ),
          ),
      ],
    );
  }
}

class _PickerPill extends StatefulWidget {
  const _PickerPill({
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_PickerPill> createState() => _PickerPillState();
}

class _PickerPillState extends State<_PickerPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFF3A3A3A)
                : const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(22),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _SeasonPill extends StatelessWidget {
  const _SeasonPill({
    required this.seasonCount,
    required this.selectedSeason,
    required this.onSeasonSelected,
  });

  final int seasonCount;
  final int selectedSeason;
  final SeasonSelectCallback onSeasonSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      initialValue: selectedSeason,
      tooltip: 'Select season',
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: onSeasonSelected,
      itemBuilder: (context) => List.generate(seasonCount, (i) {
        final n = i + 1;
        return PopupMenuItem<int>(
          value: n,
          child: Text(
            'Season $n',
            style: TextStyle(
              color: n == selectedSeason ? Colors.white : Colors.white70,
              fontWeight: n == selectedSeason ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        );
      }),
      child: _PickerPill(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Season $selectedSeason',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpisodeCard extends StatefulWidget {
  const _EpisodeCard({
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

  static const double cardWidth = 268;
  static const double thumbRadius = 10;

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  bool _hovered = false;

  double get _scale {
    if (_hovered) return widget.selected ? 1.08 : 1.05;
    if (widget.selected) return 1.05;
    return 1.0;
  }

  bool get _showPlayOverlay => _hovered || widget.selected;

  @override
  Widget build(BuildContext context) {
    final thumbHeight = _EpisodeCard.cardWidth * 9 / 16;
    final showProgress =
        WatchProgressBar.isResumable(widget.positionMs, widget.durationMs);
    final durationLabel = widget.runtime > 0 ? '${widget.runtime}m' : null;
    final scale = _scale;

    return FocusableControl(
      onTap: widget.onTap,
      borderRadius: _EpisodeCard.thumbRadius,
      scaleOnFocus: 1.0,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: GestureDetector(
            onSecondaryTap: widget.onToggleWatched,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: _EpisodeCard.cardWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: _EpisodeCard.cardWidth,
                    height: thumbHeight,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(_EpisodeCard.thumbRadius),
                      border: widget.selected
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(_EpisodeCard.thumbRadius),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          widget.thumbnail != null
                              ? CachedNetworkImage(
                                  imageUrl: widget.thumbnail
                                          .toString()
                                          .startsWith('http')
                                      ? widget.thumbnail.toString()
                                      : TmdbApi.getStillUrl(
                                          widget.thumbnail.toString(),
                                        ),
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => _thumbFallback(),
                                )
                              : _thumbFallback(),
                          if (showProgress)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: LinearProgressIndicator(
                                value: (widget.positionMs / widget.durationMs)
                                    .clamp(0.0, 1.0),
                                minHeight: 3,
                                backgroundColor: Colors.black54,
                                valueColor: AlwaysStoppedAnimation(
                                  ForjaShellColors.progressFill,
                                ),
                              ),
                            ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child:
                                _ThumbBadge(label: 'E${widget.episodeNumber}'),
                          ),
                          if (durationLabel != null)
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: _ThumbBadge(label: durationLabel),
                            ),
                          if (widget.watched)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AnimatedOpacity(
                                opacity: _showPlayOverlay ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  if (widget.overview.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.overview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
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

class _ThumbBadge extends StatelessWidget {
  const _ThumbBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
