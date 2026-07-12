import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/widgets/episode_air_date.dart';
import 'package:forja/shared/widgets/episode_range_bar.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel.dart';
import 'package:forja/shared/widgets/watch_progress_bar.dart';
import 'package:rust/rust.dart';

/// Right-side sliding panel for TV season / episode picking in the player.
class PlayerEpisodePanel {
  static OverlayEntry? _entry;
  static Completer<void>? _completer;

  static bool get isShowing => _entry != null;

  static void dismiss() {
    _entry?.remove();
    _entry = null;
    _completer?.complete();
    _completer = null;
  }

  static Future<void> show({
    required BuildContext context,
    required Movie movie,
    required int currentSeason,
    required int currentEpisode,
    required Future<void> Function(int season, int episode) onEpisodeSelected,
  }) {
    dismiss();

    final overlay = Overlay.of(context);
    _completer = Completer<void>();

    _entry = OverlayEntry(
      builder: (_) => ShellScopeBuilder(
        builder: (context, _) => _EpisodePanelOverlay(
          movie: movie,
          initialSeason: currentSeason,
          currentSeason: currentSeason,
          currentEpisode: currentEpisode,
          onEpisodeSelected: onEpisodeSelected,
          onClose: dismiss,
        ),
      ),
    );

    overlay.insert(_entry!);
    return _completer!.future;
  }
}

class _EpisodePanelOverlay extends StatefulWidget {
  const _EpisodePanelOverlay({
    required this.movie,
    required this.initialSeason,
    required this.currentSeason,
    required this.currentEpisode,
    required this.onEpisodeSelected,
    required this.onClose,
  });

  final Movie movie;
  final int initialSeason;
  final int currentSeason;
  final int currentEpisode;
  final Future<void> Function(int season, int episode) onEpisodeSelected;
  final VoidCallback onClose;

  @override
  State<_EpisodePanelOverlay> createState() => _EpisodePanelOverlayState();
}

class _EpisodePanelOverlayState extends State<_EpisodePanelOverlay> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _open = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TorrentSourcesPanel(
      isOpen: _open,
      onClose: widget.onClose,
      enableBlur: false,
      child: _EpisodePanelBody(
        movie: widget.movie,
        initialSeason: widget.initialSeason,
        currentSeason: widget.currentSeason,
        currentEpisode: widget.currentEpisode,
        onEpisodeSelected: widget.onEpisodeSelected,
        onClose: widget.onClose,
      ),
    );
  }
}

class _EpisodePanelBody extends StatefulWidget {
  const _EpisodePanelBody({
    required this.movie,
    required this.initialSeason,
    required this.currentSeason,
    required this.currentEpisode,
    required this.onEpisodeSelected,
    required this.onClose,
  });

  final Movie movie;
  final int initialSeason;
  final int currentSeason;
  final int currentEpisode;
  final Future<void> Function(int season, int episode) onEpisodeSelected;
  final VoidCallback onClose;

  @override
  State<_EpisodePanelBody> createState() => _EpisodePanelBodyState();
}

class _EpisodePanelBodyState extends State<_EpisodePanelBody> {
  final _tmdb = TmdbService();
  final _scrollController = ScrollController();

  int? _seasonCount;
  late int _selectedSeason;
  List<Map<String, dynamic>> _episodes = [];
  Map<String, Map<String, dynamic>> _episodeProgress = {};
  bool _loading = true;
  int _episodeChunk = 0;

  List<int> get _episodeNumbers => _episodes
      .map((ep) => ep['episode_number'] as int? ?? 0)
      .where((n) => n > 0)
      .toList();

  List<EpisodeRange> get _episodeRanges =>
      buildEpisodeRangesForNumbers(_episodeNumbers);

  List<Map<String, dynamic>> get _visibleEpisodes =>
      filterEpisodeChunkByNumber(
        _episodes,
        (ep) => ep['episode_number'] as int? ?? 0,
        _episodeChunk,
      );

  int _chunkIndexForEpisode(int episode) =>
      episodeChunkIndexForNumber(episode);

  @override
  void initState() {
    super.initState();
    _selectedSeason = widget.initialSeason;
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final cachedSeasonCount = widget.movie.numberOfSeasons;
    final countFuture = _seasonCount != null
        ? Future<int?>.value(_seasonCount)
        : cachedSeasonCount > 0
            ? Future<int?>.value(cachedSeasonCount)
            : _tmdb.getTvSeasonCount(widget.movie.id).then<int?>((v) => v);

    final seasonFuture =
        _tmdb.getTvSeasonDetails(widget.movie.id, _selectedSeason);

    final results = await Future.wait([countFuture, seasonFuture]);
    if (!mounted) return;

    final count = results[0] as int? ?? 0;
    final data = results[1] as Map<String, dynamic>;
    final episodes = (data['episodes'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final chunk = _selectedSeason == widget.currentSeason
        ? _chunkIndexForEpisode(widget.currentEpisode)
        : 0;

    setState(() {
      _seasonCount = count;
      _episodes = episodes;
      _episodeProgress = const {};
      _loading = false;
      _episodeChunk = chunk;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    unawaited(_hydrateEpisodeProgress(episodes));
  }

  Future<void> _hydrateEpisodeProgress(
    List<Map<String, dynamic>> episodes,
  ) async {
    if (episodes.isEmpty) return;

    final history = await WatchHistoryService().getHistory();
    final byUniqueId = <String, Map<String, dynamic>>{
      for (final item in history)
        if (item['uniqueId'] is String) item['uniqueId'] as String: item,
    };

    final progress = <String, Map<String, dynamic>>{};
    for (final ep in episodes) {
      final n = ep['episode_number'] as int? ?? 0;
      if (n <= 0) continue;
      final uniqueId = '${widget.movie.id}_S${_selectedSeason}_E$n';
      final item = byUniqueId[uniqueId];
      if (item != null) {
        progress['S${_selectedSeason}_E$n'] = item;
      }
    }

    if (!mounted) return;
    setState(() => _episodeProgress = progress);
  }

  void _scrollToCurrent() {
    if (!_scrollController.hasClients) return;
    if (_selectedSeason != widget.currentSeason) return;

    final chunk = _chunkIndexForEpisode(widget.currentEpisode);
    if (chunk != _episodeChunk) {
      setState(() => _episodeChunk = chunk);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
      return;
    }

    final index = _visibleEpisodes.indexWhere(
      (ep) => (ep['episode_number'] as int? ?? 0) == widget.currentEpisode,
    );
    if (index < 0) return;

    const rowHeight = 116.0;
    final target = (index * rowHeight).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _selectSeason(int season) async {
    if (season == _selectedSeason) return;
    setState(() {
      _selectedSeason = season;
      _episodeChunk = 0;
    });
    await _load();
  }

  void _selectChunk(int chunk) {
    if (chunk == _episodeChunk) return;
    setState(() => _episodeChunk = chunk);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedSeason == widget.currentSeason &&
          _chunkIndexForEpisode(widget.currentEpisode) == chunk) {
        _scrollToCurrent();
      } else if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  Future<void> _selectEpisode(int season, int episode) async {
    final selectedEpisode = _episodes.cast<Map<String, dynamic>?>().firstWhere(
          (ep) => (ep?['episode_number'] as int? ?? 0) == episode,
          orElse: () => null,
        );
    if (selectedEpisode != null &&
        episodeAirDateInfo(selectedEpisode).notShippedYet) {
      return;
    }

    final selected =
        season == widget.currentSeason && episode == widget.currentEpisode;
    widget.onClose();
    if (selected) return;
    await widget.onEpisodeSelected(season, episode);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlayerSidePanelHeader(
          title: 'Episodes',
          onClose: widget.onClose,
          trailing: (_seasonCount ?? 0) > 1
              ? _SeasonDropdown(
                  seasonCount: _seasonCount!,
                  selectedSeason: _selectedSeason,
                  onSelected: _selectSeason,
                )
              : null,
        ),
        if (!_loading && showEpisodeRangeBar(_episodeNumbers))
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: EpisodeRangeBar(
              ranges: _episodeRanges,
              selectedIndex: _episodeChunk,
              onSelected: _selectChunk,
              compact: true,
            ),
          ),
        Expanded(
          child: _loading
              ? Center(
                  child: CircularProgressIndicator(
                    color: ForjaShellColors.sectionAccent,
                    strokeWidth: 2,
                  ),
                )
              : _visibleEpisodes.isEmpty
                  ? Center(
                      child: Text(
                        'No episodes found',
                        style: TextStyle(
                          color: ForjaShellColors.cinematic.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      itemCount: _visibleEpisodes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 2),
                      itemBuilder: (_, i) {
                        final ep = _visibleEpisodes[i];
                        final num = ep['episode_number'] as int? ?? 0;
                        final name =
                            ep['name']?.toString() ?? 'Episode $num';
                        final overview = (ep['overview'] ?? '').toString();
                        final runtime = ep['runtime'] as int? ?? 0;
                        final thumbnail = ep['still_path'];
                        final selected = _selectedSeason == widget.currentSeason &&
                            num == widget.currentEpisode;
                        final progKey = 'S${_selectedSeason}_E$num';
                        final prog = _episodeProgress[progKey];
                        final pos = prog?['position'] as int? ?? 0;
                        final dur = prog?['duration'] as int? ??
                            (runtime > 0 ? runtime * 60000 : 0);
                        final airDate = episodeAirDateInfo(ep);

                        return _EpisodeRow(
                          episodeNumber: num,
                          title: name,
                          overview: overview,
                          runtime: runtime,
                          dateLabel: airDate.label,
                          dateNotShippedYet: airDate.notShippedYet,
                          fallbackBackdropPath: widget.movie.backdropPath,
                          fallbackPosterPath: widget.movie.posterPath,
                          thumbnail: thumbnail,
                          selected: selected,
                          positionMs: pos,
                          durationMs: dur,
                          onTap: airDate.notShippedYet
                              ? null
                              : () => _selectEpisode(_selectedSeason, num),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _SeasonDropdown extends StatelessWidget {
  const _SeasonDropdown({
    required this.seasonCount,
    required this.selectedSeason,
    required this.onSelected,
  });

  final int seasonCount;
  final int selectedSeason;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const radius = 20.0;
    final borderRadius = BorderRadius.circular(radius);

    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          ForjaShellColors.cinematic.menuSurface,
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      menuChildren: List.generate(seasonCount, (i) {
        final n = i + 1;
        final isSelected = n == selectedSeason;
        return MenuItemButton(
          onPressed: () => onSelected(n),
          style: shellMenuItemStyle().merge(ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(
              isSelected
                  ? ForjaShellColors.cinematic.textPrimary
                  : ForjaShellColors.cinematic.textSecondary,
            ),
            textStyle: WidgetStatePropertyAll(
              TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          )),
          child: Text('Season $n'),
        );
      }),
      builder: (context, controller, child) {
        return Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: shellChipDecoration(selected: true, radius: radius),
            child: InkWell(
              borderRadius: borderRadius,
              onTap: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Season $selectedSeason',
                      style: TextStyle(
                        color: ForjaShellColors.cinematic.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: ForjaShellColors.cinematic.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Right-side sliding panel for hub players (anime, Asian drama).
class PlayerHubEpisodePanel {
  static OverlayEntry? _entry;
  static Completer<void>? _completer;

  static bool get isShowing => _entry != null;

  static void dismiss() {
    _entry?.remove();
    _entry = null;
    _completer?.complete();
    _completer = null;
  }

  static Future<void> show({
    required BuildContext context,
    required List<PlayerHubEpisode> episodes,
    required num currentEpisode,
    required Future<void> Function(PlayerHubEpisode episode) onEpisodeSelected,
    String? fallbackBackdropPath,
    String? fallbackPosterPath,
  }) {
    dismiss();

    final overlay = Overlay.of(context);
    _completer = Completer<void>();

    _entry = OverlayEntry(
      builder: (_) => ShellScopeBuilder(
        builder: (context, _) => _HubEpisodePanelOverlay(
          episodes: episodes,
          currentEpisode: currentEpisode,
          onEpisodeSelected: onEpisodeSelected,
          onClose: dismiss,
          fallbackBackdropPath: fallbackBackdropPath,
          fallbackPosterPath: fallbackPosterPath,
        ),
      ),
    );

    overlay.insert(_entry!);
    return _completer!.future;
  }
}

class _HubEpisodePanelOverlay extends StatefulWidget {
  const _HubEpisodePanelOverlay({
    required this.episodes,
    required this.currentEpisode,
    required this.onEpisodeSelected,
    required this.onClose,
    this.fallbackBackdropPath,
    this.fallbackPosterPath,
  });

  final List<PlayerHubEpisode> episodes;
  final num currentEpisode;
  final Future<void> Function(PlayerHubEpisode episode) onEpisodeSelected;
  final VoidCallback onClose;
  final String? fallbackBackdropPath;
  final String? fallbackPosterPath;

  @override
  State<_HubEpisodePanelOverlay> createState() =>
      _HubEpisodePanelOverlayState();
}

class _HubEpisodePanelOverlayState extends State<_HubEpisodePanelOverlay> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _open = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TorrentSourcesPanel(
      isOpen: _open,
      onClose: widget.onClose,
      enableBlur: false,
      child: _HubEpisodePanelBody(
        episodes: widget.episodes,
        currentEpisode: widget.currentEpisode,
        onEpisodeSelected: widget.onEpisodeSelected,
        onClose: widget.onClose,
        fallbackBackdropPath: widget.fallbackBackdropPath,
        fallbackPosterPath: widget.fallbackPosterPath,
      ),
    );
  }
}

class _HubEpisodePanelBody extends StatefulWidget {
  const _HubEpisodePanelBody({
    required this.episodes,
    required this.currentEpisode,
    required this.onEpisodeSelected,
    required this.onClose,
    this.fallbackBackdropPath,
    this.fallbackPosterPath,
  });

  final List<PlayerHubEpisode> episodes;
  final num currentEpisode;
  final Future<void> Function(PlayerHubEpisode episode) onEpisodeSelected;
  final VoidCallback onClose;
  final String? fallbackBackdropPath;
  final String? fallbackPosterPath;

  @override
  State<_HubEpisodePanelBody> createState() => _HubEpisodePanelBodyState();
}

class _HubEpisodePanelBodyState extends State<_HubEpisodePanelBody> {
  final _scrollController = ScrollController();
  int _episodeChunk = 0;

  List<int> get _episodeNumbers => widget.episodes
      .map((e) => e.number is int ? e.number as int : e.number.toInt())
      .toList();

  List<EpisodeRange> get _episodeRanges =>
      buildEpisodeRangesForNumbers(_episodeNumbers);

  List<PlayerHubEpisode> get _visibleEpisodes =>
      filterEpisodeChunkByNumber(
        widget.episodes,
        (e) => e.number is int ? e.number as int : e.number.toInt(),
        _episodeChunk,
      );

  int _chunkIndexForEpisode(num episode) =>
      episodeChunkIndexForNumber(episode);

  @override
  void initState() {
    super.initState();
    _episodeChunk = _chunkIndexForEpisode(widget.currentEpisode);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void didUpdateWidget(covariant _HubEpisodePanelBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentEpisode != widget.currentEpisode ||
        oldWidget.episodes != widget.episodes) {
      final chunk = _chunkIndexForEpisode(widget.currentEpisode);
      if (chunk != _episodeChunk) _episodeChunk = chunk;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrent() {
    final chunk = _chunkIndexForEpisode(widget.currentEpisode);
    if (chunk != _episodeChunk) {
      setState(() => _episodeChunk = chunk);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
      return;
    }
    final index = _visibleEpisodes.indexWhere(
      (e) => e.number == widget.currentEpisode,
    );
    if (index < 0 || !_scrollController.hasClients) return;
    const rowHeight = 116.0;
    final offset = (index * rowHeight).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _selectChunk(int chunk) {
    if (chunk == _episodeChunk) return;
    setState(() => _episodeChunk = chunk);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chunkIndexForEpisode(widget.currentEpisode) == chunk) {
        _scrollToCurrent();
      } else if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  Future<void> _select(PlayerHubEpisode episode) async {
    if (episode.notShippedYet) return;
    if (episode.number == widget.currentEpisode) {
      widget.onClose();
      return;
    }
    await widget.onEpisodeSelected(episode);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlayerSidePanelHeader(
          title: 'Episodes',
          onClose: widget.onClose,
        ),
        if (showEpisodeRangeBar(_episodeNumbers))
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: EpisodeRangeBar(
              ranges: _episodeRanges,
              selectedIndex: _episodeChunk,
              onSelected: _selectChunk,
              compact: true,
            ),
          ),
        Expanded(
          child: widget.episodes.isEmpty
              ? Center(
                  child: Text(
                    'No episodes found',
                    style: TextStyle(
                      color: ForjaShellColors.cinematic.textSecondary,
                    ),
                  ),
                )
              : _visibleEpisodes.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      itemCount: _visibleEpisodes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 2),
                      itemBuilder: (_, i) {
                        final ep = _visibleEpisodes[i];
                    final selected = ep.number == widget.currentEpisode;
                    final airDate = EpisodeAirDateInfo(
                      label: ep.airDateLabel,
                      notShippedYet: ep.notShippedYet,
                    );
                    return _EpisodeRow(
                      episodeNumber: ep.number is int
                          ? ep.number as int
                          : ep.number.toInt(),
                      episodeBadge: 'E${ep.displayNumber}',
                      title: ep.title,
                      overview: ep.overview ?? '',
                      runtime: ep.runtimeMinutes,
                      dateLabel: airDate.label,
                      dateNotShippedYet: airDate.notShippedYet,
                      fallbackBackdropPath: widget.fallbackBackdropPath,
                      fallbackPosterPath: widget.fallbackPosterPath,
                      thumbnail: ep.thumbnailUrl,
                      selected: selected,
                      positionMs: ep.positionMs,
                      durationMs: ep.durationMs,
                      onTap: airDate.notShippedYet ? null : () => _select(ep),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.episodeNumber,
    required this.title,
    required this.overview,
    required this.runtime,
    this.dateLabel,
    this.dateNotShippedYet = false,
    this.fallbackBackdropPath,
    this.fallbackPosterPath,
    required this.thumbnail,
    required this.selected,
    required this.positionMs,
    required this.durationMs,
    this.onTap,
    this.episodeBadge,
  });

  final int episodeNumber;
  final String? episodeBadge;
  final String title;
  final String overview;
  final int runtime;
  final String? dateLabel;
  final bool dateNotShippedYet;
  final String? fallbackBackdropPath;
  final String? fallbackPosterPath;
  final dynamic thumbnail;
  final bool selected;
  final int positionMs;
  final int durationMs;
  final VoidCallback? onTap;

  static const _thumbRadius = 6.0;
  static const _thumbWidth = 184.0;
  static const _thumbHeight = _thumbWidth * 9 / 16;

  @override
  Widget build(BuildContext context) {
    final durationLabel = runtime > 0 ? '${runtime}m' : null;
    final showProgress =
        WatchProgressBar.isResumable(positionMs, durationMs);

    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: ForjaShellColors.inkHover,
        splashColor: ForjaShellColors.inkSplash,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _thumbWidth,
                height: _thumbHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_thumbRadius),
                    border: selected
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_thumbRadius),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ..._thumbLayers(
                          stillUrl: _resolvedThumbnail(thumbnail),
                          backdropUrl: _resolvedShowArt(
                            fallbackBackdropPath,
                            fallbackPosterPath,
                          ),
                        ),
                        if (showProgress)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(
                              value: (positionMs / durationMs)
                                  .clamp(0.0, 1.0),
                              minHeight: 3,
                              backgroundColor: Colors.black54,
                              valueColor: AlwaysStoppedAnimation(
                                ForjaShellColors.progressFill,
                              ),
                            ),
                          ),
                        Positioned(
                          top: 6,
                          left: 6,
                          child: _Badge(
                            label: episodeBadge ?? 'E$episodeNumber',
                          ),
                        ),
                        if (durationLabel != null)
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: _Badge(label: durationLabel),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ForjaShellColors.cinematic.textPrimary,
                              fontSize: 14,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                        ),
                        if (selected)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.play_circle_filled_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                    if (dateLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        dateLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: episodeDateColor(
                            notShippedYet: dateNotShippedYet,
                            normal: ForjaShellColors.cinematic.textSecondary,
                          ),
                          fontSize: 12,
                          fontWeight: dateNotShippedYet
                              ? FontWeight.w600
                              : FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ],
                    if (overview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ForjaShellColors.cinematic.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _resolvedThumbnail(dynamic thumbnail) {
    final value = thumbnail?.toString().trim();
    if (value == null || value.isEmpty || value == 'null') return null;
    return value;
  }

  static String? _resolvedShowArt(String? backdropPath, String? posterPath) {
    final backdrop = backdropPath?.trim();
    if (backdrop != null && backdrop.isNotEmpty) {
      return backdrop.startsWith('http')
          ? backdrop
          : TmdbApi.getBackdropUrl(backdrop);
    }
    final poster = posterPath?.trim();
    if (poster != null && poster.isNotEmpty) {
      return poster.startsWith('http') ? poster : TmdbApi.getImageUrl(poster);
    }
    return null;
  }

  List<Widget> _thumbLayers({
    required String? stillUrl,
    required String? backdropUrl,
  }) {
    String? resolvedStill;
    if (stillUrl != null) {
      resolvedStill =
          stillUrl.startsWith('http') ? stillUrl : TmdbApi.getStillUrl(stillUrl);
    }

    if (dateNotShippedYet) {
      final imageUrl = backdropUrl ?? resolvedStill;
      return [
        if (imageUrl != null)
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => _thumbFallback(),
          )
        else
          _thumbFallback(),
        ColoredBox(color: Colors.black.withValues(alpha: 0.52)),
      ];
    }

    if (resolvedStill != null) {
      return [
        CachedNetworkImage(
          imageUrl: resolvedStill,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => _thumbFallback(),
        ),
      ];
    }

    return [_thumbFallback()];
  }

  Widget _thumbFallback() {
    return ColoredBox(color: Colors.white.withValues(alpha: 0.06));
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
