import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/widgets/episode_air_date.dart';
import 'package:forja/shared/widgets/episode_range_bar.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
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
    playerChromeCancelSeekScrubs();

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
    return playerOverlayShell(
      context: context,
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
  final _settings = SettingsService();
  final _scrollController = ScrollController();

  int? _seasonCount;
  late int _selectedSeason;
  List<Map<String, dynamic>> _episodes = [];
  Map<String, Map<String, dynamic>> _episodeProgress = {};
  bool _loading = true;
  int _episodeChunk = 0;
  bool _autoNextEpisode = true;
  String _searchQuery = '';

  List<int> get _episodeNumbers => _episodes
      .map((ep) => ep['episode_number'] as int? ?? 0)
      .where((n) => n > 0)
      .toList();

  List<EpisodeRange> get _episodeRanges =>
      buildEpisodeRangesForNumbers(_episodeNumbers);

  List<Map<String, dynamic>> get _chunkEpisodes =>
      filterEpisodeChunkByNumber(
        _episodes,
        (ep) => ep['episode_number'] as int? ?? 0,
        _episodeChunk,
      );

  List<Map<String, dynamic>> get _visibleEpisodes {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _chunkEpisodes;
    return _chunkEpisodes.where((ep) {
      final num = ep['episode_number'] as int? ?? 0;
      final name = (ep['name'] ?? '').toString().toLowerCase();
      return name.contains(q) ||
          '$num'.contains(q) ||
          'e$num'.contains(q) ||
          'episode $num'.contains(q);
    }).toList();
  }

  int _chunkIndexForEpisode(int episode) =>
      episodeChunkIndexForNumber(episode);

  @override
  void initState() {
    super.initState();
    _selectedSeason = widget.initialSeason;
    _autoNextEpisode = SettingsService.autoNextEpisodeNotifier.value;
    unawaited(_loadAutoNext());
    _load();
  }

  Future<void> _loadAutoNext() async {
    final v = await _settings.getAutoNextEpisode();
    if (!mounted) return;
    setState(() => _autoNextEpisode = v);
  }

  Future<void> _setAutoNext(bool value) async {
    setState(() => _autoNextEpisode = value);
    await _settings.setAutoNextEpisode(value);
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
    final showRange = !_loading && showEpisodeRangeBar(_episodeNumbers);
    final showSeason = (_seasonCount ?? 0) > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EpisodePanelTopBar(
          season: showSeason
              ? _SeasonDropdown(
                  seasonCount: _seasonCount!,
                  selectedSeason: _selectedSeason,
                  onSelected: _selectSeason,
                )
              : null,
          searchQuery: _searchQuery,
          onSearchChanged: (q) => setState(() => _searchQuery = q),
          autoNext: _autoNextEpisode,
          onAutoNextChanged: (v) => unawaited(_setAutoNext(v)),
          onClose: widget.onClose,
        ),
        if (showRange) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: EpisodeRangeSelector(
              ranges: _episodeRanges,
              selectedIndex: _episodeChunk,
              onSelected: _selectChunk,
            ),
          ),
        ],
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
                        _searchQuery.trim().isEmpty
                            ? 'No episodes found'
                            : 'No matching episodes',
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
          EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(168, 0)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      menuChildren: List.generate(seasonCount, (i) {
        final n = i + 1;
        final isSelected = n == selectedSeason;
        return MenuItemButton(
          onPressed: () => onSelected(n),
          style: shellMenuItemStyle(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ).merge(ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(156, 52)),
            foregroundColor: WidgetStatePropertyAll(
              isSelected
                  ? ForjaShellColors.cinematic.textPrimary
                  : ForjaShellColors.cinematic.textSecondary,
            ),
            textStyle: WidgetStatePropertyAll(
              TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          )),
          child: Text('Season $n'),
        );
      }),
      builder: (context, controller, child) {
        void toggle() {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        }

        final trigger = Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              color: ForjaShellColors.brandGreen.withValues(alpha: 0.12),
              borderRadius: borderRadius,
            ),
            child: InkWell(
              borderRadius: borderRadius,
              onTap: toggle,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                child: Text(
                  'Season $selectedSeason',
                  style: TextStyle(
                    color: ForjaShellColors.brandGreen,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
        if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) {
          return trigger;
        }
        return shellFocusableTap(
          context: context,
          onTap: toggle,
          borderRadius: radius,
          showFocusBorder: true,
          child: trigger,
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
    playerChromeCancelSeekScrubs();

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
  final bool _open = true;

  @override
  void initState() {
    super.initState();
    playerChromeCancelSeekScrubs();
  }

  @override
  Widget build(BuildContext context) {
    return playerOverlayShell(
      context: context,
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
  final _settings = SettingsService();
  final _scrollController = ScrollController();
  int _episodeChunk = 0;
  bool _autoNextEpisode = true;
  String _searchQuery = '';

  List<int> get _episodeNumbers => widget.episodes
      .map((e) => e.number is int ? e.number as int : e.number.toInt())
      .toList();

  List<EpisodeRange> get _episodeRanges =>
      buildEpisodeRangesForNumbers(_episodeNumbers);

  List<PlayerHubEpisode> get _chunkEpisodes =>
      filterEpisodeChunkByNumber(
        widget.episodes,
        (e) => e.number is int ? e.number as int : e.number.toInt(),
        _episodeChunk,
      );

  List<PlayerHubEpisode> get _visibleEpisodes {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _chunkEpisodes;
    return _chunkEpisodes.where((ep) {
      final num = ep.number is int ? ep.number as int : ep.number.toInt();
      final title = ep.title.toLowerCase();
      final display = ep.displayNumber.toString().toLowerCase();
      return title.contains(q) ||
          '$num'.contains(q) ||
          display.contains(q) ||
          'e$num'.contains(q) ||
          'episode $num'.contains(q);
    }).toList();
  }

  int _chunkIndexForEpisode(num episode) =>
      episodeChunkIndexForNumber(episode);

  @override
  void initState() {
    super.initState();
    _episodeChunk = _chunkIndexForEpisode(widget.currentEpisode);
    _autoNextEpisode = SettingsService.autoNextEpisodeNotifier.value;
    unawaited(_loadAutoNext());
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  Future<void> _loadAutoNext() async {
    final v = await _settings.getAutoNextEpisode();
    if (!mounted) return;
    setState(() => _autoNextEpisode = v);
  }

  Future<void> _setAutoNext(bool value) async {
    setState(() => _autoNextEpisode = value);
    await _settings.setAutoNextEpisode(value);
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
    widget.onClose();
    await widget.onEpisodeSelected(episode);
  }

  @override
  Widget build(BuildContext context) {
    final showRange = showEpisodeRangeBar(_episodeNumbers);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EpisodePanelTopBar(
          searchQuery: _searchQuery,
          onSearchChanged: (q) => setState(() => _searchQuery = q),
          autoNext: _autoNextEpisode,
          onAutoNextChanged: (v) => unawaited(_setAutoNext(v)),
          onClose: widget.onClose,
        ),
        if (showRange) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: EpisodeRangeSelector(
              ranges: _episodeRanges,
              selectedIndex: _episodeChunk,
              onSelected: _selectChunk,
            ),
          ),
        ],
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
                  ? Center(
                      child: Text(
                        _searchQuery.trim().isEmpty
                            ? 'No episodes found'
                            : 'No matching episodes',
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

    final tile = Material(
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

    if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips ||
        onTap == null) {
      return tile;
    }
    return shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: 10,
      showFocusBorder: true,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      child: tile,
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

/// Episode panel chrome: season pill · search + auto-next · close.
class _EpisodePanelTopBar extends StatelessWidget {
  const _EpisodePanelTopBar({
    this.season,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.autoNext,
    required this.onAutoNextChanged,
    required this.onClose,
  });

  final Widget? season;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final bool autoNext;
  final ValueChanged<bool> onAutoNextChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (season != null) ...[
          season!,
          const SizedBox(width: 10),
        ],
        Expanded(
          child: _EpisodeSearchAutoNextBar(
            searchQuery: searchQuery,
            onSearchChanged: onSearchChanged,
            autoNext: autoNext,
            onAutoNextChanged: onAutoNextChanged,
          ),
        ),
        const SizedBox(width: 10),
        _EpisodePanelCloseButton(onClose: onClose),
      ],
    );
  }
}

class _EpisodeSearchAutoNextBar extends StatefulWidget {
  const _EpisodeSearchAutoNextBar({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.autoNext,
    required this.onAutoNextChanged,
  });

  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final bool autoNext;
  final ValueChanged<bool> onAutoNextChanged;

  @override
  State<_EpisodeSearchAutoNextBar> createState() =>
      _EpisodeSearchAutoNextBarState();
}

class _EpisodeSearchAutoNextBarState extends State<_EpisodeSearchAutoNextBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _EpisodeSearchAutoNextBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _controller.text) {
      _controller.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const radius = 22.0;
    final secondary = ForjaShellColors.cinematic.textSecondary;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: ForjaShellColors.surfaceElevated,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: ForjaShellColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 18, color: secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: widget.onSearchChanged,
                      style: TextStyle(
                        color: ForjaShellColors.cinematic.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: TextStyle(
                          color: secondary.withValues(alpha: 0.75),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (widget.searchQuery.isNotEmpty)
                    ForjaCloseButton.compact(
                      tooltip: null,
                      color: secondary,
                      onTap: () => widget.onSearchChanged(''),
                    ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 22,
            color: ForjaShellColors.borderSubtle,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Auto next episode',
                  child: Icon(
                    Icons.skip_next_rounded,
                    size: 20,
                    color: secondary,
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  height: 28,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Switch(
                      value: widget.autoNext,
                      onChanged: widget.onAutoNextChanged,
                      activeThumbColor: Colors.white,
                      activeTrackColor:
                          ForjaShellColors.brandGreen.withValues(alpha: 0.55),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFF3A3A3A),
                      trackOutlineColor:
                          const WidgetStatePropertyAll(Colors.transparent),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodePanelCloseButton extends StatelessWidget {
  const _EpisodePanelCloseButton({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ForjaShellColors.sectionIconBg,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onClose,
        hoverColor: ForjaShellColors.inkHover,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Icons.close_rounded,
            size: 20,
            color: ForjaShellColors.cinematic.textSecondary,
          ),
        ),
      ),
    );
  }
}
