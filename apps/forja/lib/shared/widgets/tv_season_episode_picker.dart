import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/episode_air_date.dart';
import 'package:forja/shared/widgets/episode_range_bar.dart';
import 'package:forja/shared/widgets/horizontal_scroller.dart';
import 'package:forja/shared/widgets/shell_card_play_overlay.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
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
    this.onEpisodeFocused,
    this.seasonPosters = const {},
    this.episodeProgress = const {},
    this.customEpisodesBySeason,
    this.tvTabId,
    this.tvSeasonRowId,
    this.tvEpisodeRowId,
    this.tvRowOrderBase = 0,
    this.tvFocusUp,
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
  final EpisodeSelectCallback? onEpisodeFocused;
  final Map<int, String> seasonPosters;
  final Map<String, Map<String, dynamic>> episodeProgress;
  final Map<int, List<Map<String, dynamic>>>? customEpisodesBySeason;
  final String? tvTabId;
  final String? tvSeasonRowId;
  final String? tvEpisodeRowId;
  final int tvRowOrderBase;
  final VoidCallback? tvFocusUp;

  @override
  State<TvSeasonEpisodePicker> createState() => _TvSeasonEpisodePickerState();
}

class _TvSeasonEpisodePickerState extends State<TvSeasonEpisodePicker> {
  bool _oldestFirst = true;
  int _episodeChunk = 0;
  final ScrollController _episodeScrollController = ScrollController();
  final ScrollController _seasonScrollController = ScrollController();

  String get _seasonRowId => widget.tvSeasonRowId ?? 'seasons';
  String get _episodeRowId => widget.tvEpisodeRowId ?? 'episodes';

  @override
  void dispose() {
    final tabId = widget.tvTabId;
    if (tabId != null) {
      if (widget.tvSeasonRowId != null) {
        shellTvUnregisterRow(tabId: tabId, rowId: _seasonRowId);
      }
      if (widget.tvEpisodeRowId != null) {
        shellTvUnregisterRow(tabId: tabId, rowId: _episodeRowId);
      }
    }
    _episodeScrollController.dispose();
    _seasonScrollController.dispose();
    super.dispose();
  }

  static const double _episodeCardStride = _EpisodeCard.cardWidth + 16;
  static const double _seasonCardStride = _SeasonCard.cardWidth + 12;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncEpisodeChunk();
      _scrollToSelectedSeason();
    });
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
  void didUpdateWidget(covariant TvSeasonEpisodePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSeason != widget.selectedSeason) {
      _episodeChunk = _chunkIndexForEpisode(widget.selectedEpisode);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedSeason();
        _scrollToSelectedEpisode();
      });
    } else if (oldWidget.selectedEpisode != widget.selectedEpisode) {
      final chunk = _chunkIndexForEpisode(widget.selectedEpisode);
      if (chunk != _episodeChunk) {
        setState(() => _episodeChunk = chunk);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToSelectedEpisode();
        });
      }
    }
    if (oldWidget.isLoadingSeason != widget.isLoadingSeason ||
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

  void _scrollToSelectedSeason() {
    if (!_seasonScrollController.hasClients || widget.seasonCount <= 1) return;
    final index = widget.selectedSeason - 1;
    if (index < 0) return;
    final target = (index * _seasonCardStride)
        .clamp(0.0, _seasonScrollController.position.maxScrollExtent);
    _seasonScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
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


  Widget _buildSeasonRow(String? tabId) {
    return HorizontalScroller(
      height: _SeasonCard.cardHeight,
      controller: _seasonScrollController,
      itemCount: widget.seasonCount,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (_, i) {
        final season = i + 1;
        return _SeasonCard(
          key: ValueKey('season-$season'),
          seasonNumber: season,
          selected: widget.selectedSeason == season,
          posterUrl: _seasonPosterUrl(season),
          onTap: () {
            if (season == widget.selectedSeason) {
              if (tabId != null &&
                  widget.tvEpisodeRowId != null &&
                  _visibleEpisodes.isNotEmpty) {
                ShellTvFocusCoordinator.focusRowItem(
                  tabId,
                  _episodeRowId,
                  0,
                );
              }
              return;
            }
            setState(() => _episodeChunk = 0);
            widget.onSeasonSelected(season);
          },
          onLeftEdge: shellTvNavLeftEdge(context, listIndex: i),
          tvTabId: tabId,
          tvRowId: widget.tvSeasonRowId != null ? _seasonRowId : null,
          listIndex: i,
        );
      },
    );
  }

  Widget _buildEpisodeRow(String? tabId) {
    return HorizontalScroller(
      height: _EpisodeCard.rowScrollerHeight,
      controller: _episodeScrollController,
      padding: const EdgeInsets.symmetric(vertical: _EpisodeCard.rowVerticalPadding),
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
        final airDate = episodeAirDateInfo(ep);

        return _EpisodeCard(
          key: ValueKey('ep-${widget.selectedSeason}-$epNum'),
          episodeNumber: epNum,
          title: title,
          overview: overview,
          runtime: runtime,
          dateLabel: airDate.label,
          dateNotShippedYet: airDate.notShippedYet,
          thumbnail: thumbnail,
          selected: widget.selectedEpisode == epNum,
          watched: watched,
          positionMs: pos,
          durationMs: dur,
          onTap: airDate.notShippedYet
              ? null
              : () {
                  widget.onEpisodeSelected(epNum);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToSelectedEpisode();
                  });
                },
          onFocusChange: widget.onEpisodeFocused == null
              ? null
              : (focused) {
                  if (focused) widget.onEpisodeFocused!(epNum);
                },
          onToggleWatched: () =>
              widget.onToggleWatched(widget.selectedSeason, epNum),
          onLeftEdge: shellTvNavLeftEdge(context, listIndex: i),
          tvTabId: tabId,
          tvRowId: widget.tvEpisodeRowId != null ? _episodeRowId : null,
          listIndex: i,
        );
      },
    );
  }

  String? _resolveThumbnail(dynamic thumb, String fallback) {
    final value = thumb?.toString().trim();
    if (value != null && value.isNotEmpty && value != 'null') return value;
    final fb = fallback.trim();
    return fb.isNotEmpty ? fb : null;
  }

  String? _seasonPosterUrl(int season) {
    final poster = widget.seasonPosters[season];
    if (poster != null && poster.isNotEmpty) {
      return poster.startsWith('http') ? poster : TmdbApi.getImageUrl(poster);
    }
    final fb = widget.fallbackPosterPath.trim();
    if (fb.isEmpty) return null;
    return fb.startsWith('http') ? fb : TmdbApi.getImageUrl(fb);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.seasonCount <= 0) return const SizedBox.shrink();

    final episodeCount = _episodes.length;
    final tabId = widget.tvTabId;
    final hasMultiSeason = widget.seasonCount > 1;
    final episodeRowOrder = widget.tvRowOrderBase + (hasMultiSeason ? 1 : 0);

    if (tabId != null && widget.tvSeasonRowId != null && hasMultiSeason) {
      shellTvRegisterRow(
        tabId: tabId,
        rowId: _seasonRowId,
        sortOrder: widget.tvRowOrderBase,
        itemCount: widget.seasonCount,
        onFocusUp: widget.tvFocusUp,
      );
    }

    if (tabId != null &&
        widget.tvEpisodeRowId != null &&
        !widget.isLoadingSeason &&
        _visibleEpisodes.isNotEmpty) {
      shellTvRegisterRow(
        tabId: tabId,
        rowId: _episodeRowId,
        sortOrder: episodeRowOrder,
        itemCount: _visibleEpisodes.length,
        onFocusUp: hasMultiSeason ? null : widget.tvFocusUp,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Episodes', style: ShellSectionTitle.titleStyle),
            if (episodeCount > 0) ...[
              const SizedBox(width: 8),
              Text(
                '$episodeCount',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const Spacer(),
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
          ],
        ),
        if (widget.seasonCount > 1) ...[
          const SizedBox(height: 16),
          _buildSeasonRow(tabId),
        ],
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
          _buildEpisodeRow(tabId),
      ],
    );
  }
}

class _SeasonCard extends StatefulWidget {
  const _SeasonCard({
    super.key,
    required this.seasonNumber,
    required this.selected,
    required this.posterUrl,
    this.onTap,
    this.onLeftEdge,
    this.tvTabId,
    this.tvRowId,
    this.listIndex,
  });

  final int seasonNumber;
  final bool selected;
  final String? posterUrl;
  final VoidCallback? onTap;
  final VoidCallback? onLeftEdge;
  final String? tvTabId;
  final String? tvRowId;
  final int? listIndex;

  static const double cardWidth = 104;
  static const double cardHeight = 156;
  static const double radius = 8;

  @override
  State<_SeasonCard> createState() => _SeasonCardState();
}

class _SeasonCardState extends State<_SeasonCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final active = ShellInputPolicy.interactiveActive(
      policy,
      hovered: _hovered,
      focused: _focused,
    );
    final borderColor = widget.selected || active
        ? ForjaShellColors.chipSelectedBorder
        : ForjaShellColors.cinematic.borderSubtle;
    final borderWidth = widget.selected || active ? 2.0 : 1.0;
    final scale = active && !widget.selected ? 1.04 : 1.0;

    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: _SeasonCard.radius,
      scaleOnFocus: 1.0,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      onLeftEdge: widget.onLeftEdge,
      tvTabId: widget.tvTabId,
      tvRowId: widget.tvRowId,
      tvItemIndex: widget.listIndex,
      tvZone: ShellTvZone.row,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: _SeasonCard.cardWidth,
          height: _SeasonCard.cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_SeasonCard.radius),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: widget.selected || active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(_SeasonCard.radius - borderWidth),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.posterUrl != null)
                  CachedNetworkImage(
                    imageUrl: widget.posterUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => _fallback(),
                  )
                else
                  _fallback(),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                        stops: const [0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 10,
                  child: Text(
                    'Season ${widget.seasonNumber}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: widget.selected ? 1.0 : 0.85,
                      ),
                      fontSize: 12,
                      fontWeight:
                          widget.selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(color: Colors.white.withValues(alpha: 0.06));
  }
}

class _PickerPill extends StatelessWidget {
  const _PickerPill({
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  static const double _radius = 22;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(horizontal: 14, vertical: 9);
    final policy = ShellScope.inputPolicyOf(context);
    final decoration = BoxDecoration(
      color: const Color(0xFF2A2A2A),
      borderRadius: BorderRadius.circular(_radius),
    );

    final pill = shellRoundedInkHost(
      radius: _radius,
      decoration: decoration,
      onTap: policy.useFocusableMoodChips ? null : onTap,
      padding: padding,
      child: child,
    );

    if (onTap == null || !policy.useFocusableMoodChips) return pill;

    return FocusableControl(
      onTap: onTap,
      borderRadius: _radius,
      scaleOnFocus: ShellTokens.focusActiveScale,
      child: pill,
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
    this.dateLabel,
    this.dateNotShippedYet = false,
    required this.thumbnail,
    required this.selected,
    required this.watched,
    required this.positionMs,
    required this.durationMs,
    this.onTap,
    required this.onToggleWatched,
    this.onFocusChange,
    this.onLeftEdge,
    this.tvTabId,
    this.tvRowId,
    this.listIndex,
  });

  final int episodeNumber;
  final String title;
  final String overview;
  final int runtime;
  final String? dateLabel;
  final bool dateNotShippedYet;
  final dynamic thumbnail;
  final bool selected;
  final bool watched;
  final int positionMs;
  final int durationMs;
  final VoidCallback? onTap;
  final VoidCallback onToggleWatched;
  final ValueChanged<bool>? onFocusChange;
  final VoidCallback? onLeftEdge;
  final String? tvTabId;
  final String? tvRowId;
  final int? listIndex;

  static const double cardWidth = 268;
  static const double thumbRadius = 10;
  static const double rowVerticalPadding = 8;

  static const double _bodyTopGap = 10;
  static const double _metaGap = 4;
  static const double _titleLineHeight = 14 * 1.25;
  static const double _dateBlockHeight = _metaGap + 12 * 1.2;
  static const double _overviewBlockHeight = _metaGap + 12 * 1.4 * 2;

  static double get thumbHeight => cardWidth * 9 / 16;

  /// Height when title, air date, and two-line overview are all visible.
  static double get maxContentHeight =>
      thumbHeight +
      _bodyTopGap +
      _titleLineHeight +
      _dateBlockHeight +
      _overviewBlockHeight;

  static double get rowScrollerHeight =>
      maxContentHeight.ceilToDouble() + rowVerticalPadding * 2;

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  bool _hovered = false;
  bool _focused = false;

  static const double _hoverScale = ShellCardPlayOverlay.cardHoverScale;

  @override
  Widget build(BuildContext context) {
    final thumbHeight = _EpisodeCard.thumbHeight;
    final showProgress =
        WatchProgressBar.isResumable(widget.positionMs, widget.durationMs);
    final durationLabel = widget.runtime > 0 ? '${widget.runtime}m' : null;
    final policy = ShellScope.inputPolicyOf(context);
    final active = ShellInputPolicy.interactiveActive(
      policy,
      hovered: _hovered,
      focused: _focused,
    );
    final enabled = widget.onTap != null;
    final showPlayOverlay = enabled && (active || widget.selected);
    final tvFocus = policy.useFocusableMoodChips;
    final scale = tvFocus
        ? 1.0
        : (enabled && (active || widget.selected) ? _hoverScale : 1.0);

    return FocusableControl(
      onTap: widget.onTap,
      borderRadius: _EpisodeCard.thumbRadius,
      scaleOnFocus: 1.0,
      onFocusChange: (focused) {
        setState(() => _focused = focused);
        widget.onFocusChange?.call(focused);
      },
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      onLeftEdge: widget.onLeftEdge,
      tvMeta: widget.tvTabId != null &&
              widget.tvRowId != null &&
              widget.listIndex != null
          ? ShellTvFocusMeta(
              tabId: widget.tvTabId!,
              zone: ShellTvZone.row,
              rowId: widget.tvRowId,
              itemIndex: widget.listIndex,
            )
          : null,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          onSecondaryTap: enabled ? widget.onToggleWatched : null,
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
                          child: _ThumbBadge(label: 'E${widget.episodeNumber}'),
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
                        ShellCardPlayOverlay(
                          active: active,
                          visible: showPlayOverlay,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: _EpisodeCard._bodyTopGap),
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
                if (widget.dateLabel != null) ...[
                  const SizedBox(height: _EpisodeCard._metaGap),
                  Text(
                    widget.dateLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: episodeDateColor(
                        notShippedYet: widget.dateNotShippedYet,
                        normal: Colors.white.withValues(alpha: 0.45),
                      ),
                      fontSize: 12,
                      fontWeight: widget.dateNotShippedYet
                          ? FontWeight.w600
                          : FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
                if (widget.overview.isNotEmpty) ...[
                  const SizedBox(height: _EpisodeCard._metaGap),
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
