import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
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
      builder: (overlayContext) => _EpisodePanelOverlay(
        movie: movie,
        initialSeason: currentSeason,
        currentSeason: currentSeason,
        currentEpisode: currentEpisode,
        onEpisodeSelected: onEpisodeSelected,
        onClose: dismiss,
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

class _EpisodePanelOverlayState extends State<_EpisodePanelOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slide = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = screenWidth < 700 ? screenWidth * 0.92 : 420.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: widget.onClose,
          behavior: HitTestBehavior.opaque,
          child: const ColoredBox(color: Colors.black54),
        ),
        SlideTransition(
          position: _slide,
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: panelWidth,
              child: Material(
                color: ForjaShellColors.cinematic.menuSurface,
                child: SafeArea(
                  left: false,
                  child: _EpisodePanelBody(
                    movie: widget.movie,
                    initialSeason: widget.initialSeason,
                    currentSeason: widget.currentSeason,
                    currentEpisode: widget.currentEpisode,
                    onEpisodeSelected: widget.onEpisodeSelected,
                    onClose: widget.onClose,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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

    final count = _seasonCount ?? await _tmdb.getTvSeasonCount(widget.movie.id);
    if (!mounted) return;

    final data = await _tmdb.getTvSeasonDetails(widget.movie.id, _selectedSeason);
    if (!mounted) return;

    final episodes = (data['episodes'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final progress = <String, Map<String, dynamic>>{};
    for (final ep in episodes) {
      final n = ep['episode_number'] as int? ?? 0;
      if (n <= 0) continue;
      final p = await WatchHistoryService().getProgress(
        widget.movie.id,
        season: _selectedSeason,
        episode: n,
      );
      if (p != null) progress['S${_selectedSeason}_E$n'] = p;
    }

    if (!mounted) return;
    setState(() {
      _seasonCount = count;
      _episodes = episodes;
      _episodeProgress = progress;
      _loading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  void _scrollToCurrent() {
    if (!_scrollController.hasClients) return;
    if (_selectedSeason != widget.currentSeason) return;

    final index = _episodes.indexWhere(
      (ep) => (ep['episode_number'] as int? ?? 0) == widget.currentEpisode,
    );
    if (index < 0) return;

    const rowHeight = 112.0;
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
    setState(() => _selectedSeason = season);
    await _load();
  }

  Future<void> _selectEpisode(int season, int episode) async {
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Episodes',
                  style: TextStyle(
                    color: ForjaShellColors.cinematic.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              if ((_seasonCount ?? 0) > 1)
                _SeasonDropdown(
                  seasonCount: _seasonCount!,
                  selectedSeason: _selectedSeason,
                  onSelected: _selectSeason,
                ),
              ForjaCloseButton(
                color: ForjaShellColors.cinematic.textSecondary,
                onTap: widget.onClose,
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: ForjaShellColors.cinematic.borderSubtle,
        ),
        Expanded(
          child: _loading
              ? Center(
                  child: CircularProgressIndicator(
                    color: ForjaShellColors.sectionAccent,
                    strokeWidth: 2,
                  ),
                )
              : _episodes.isEmpty
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
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      itemCount: _episodes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (_, i) {
                        final ep = _episodes[i];
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

                        return _EpisodeRow(
                          episodeNumber: num,
                          title: name,
                          overview: overview,
                          runtime: runtime,
                          thumbnail: thumbnail,
                          selected: selected,
                          positionMs: pos,
                          durationMs: dur,
                          onTap: () => _selectEpisode(_selectedSeason, num),
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
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      menuChildren: List.generate(seasonCount, (i) {
        final n = i + 1;
        final isSelected = n == selectedSeason;
        return MenuItemButton(
          onPressed: () => onSelected(n),
          style: ButtonStyle(
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
          ),
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

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.episodeNumber,
    required this.title,
    required this.overview,
    required this.runtime,
    required this.thumbnail,
    required this.selected,
    required this.positionMs,
    required this.durationMs,
    required this.onTap,
  });

  final int episodeNumber;
  final String title;
  final String overview;
  final int runtime;
  final dynamic thumbnail;
  final bool selected;
  final int positionMs;
  final int durationMs;
  final VoidCallback onTap;

  static const _thumbWidth = 128.0;
  static const _thumbRadius = 8.0;

  @override
  Widget build(BuildContext context) {
    final thumbHeight = _thumbWidth * 9 / 16;
    final durationLabel = runtime > 0 ? '${runtime}m' : null;
    final showProgress =
        WatchProgressBar.isResumable(positionMs, durationMs);

    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: _thumbWidth,
                height: thumbHeight,
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
                      if (thumbnail != null)
                        CachedNetworkImage(
                          imageUrl: thumbnail.toString().startsWith('http')
                              ? thumbnail.toString()
                              : TmdbApi.getStillUrl(thumbnail.toString()),
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => _thumbFallback(),
                        )
                      else
                        _thumbFallback(),
                      if (showProgress)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            value: (positionMs / durationMs).clamp(0.0, 1.0),
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
                        child: _Badge(label: 'E$episodeNumber'),
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
                    if (overview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        overview,
                        maxLines: 3,
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
