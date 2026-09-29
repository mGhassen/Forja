import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/downloads/download_enqueue.dart';
import 'package:forja/shared/downloads/download_page_store.dart';
import 'package:forja/shared/downloads/download_play.dart';
import 'package:forja/shared/downloads/download_service.dart';
import 'package:forja/shared/downloads/download_task.dart';
import 'package:forja/shared/engine/runtime/open/meta_movie.dart';
import 'package:forja/shared/playback/sources_request_context.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/components/select.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Docked details for a saved title. The open poster stays selected in the
/// grid; this panel is that film, with Play on the art and the sources below.
class DownloadLibrarySidePanel extends StatefulWidget {
  const DownloadLibrarySidePanel({
    super.key,
    required this.seed,
    required this.onClosed,
  });

  final MetaItem seed;
  final VoidCallback onClosed;

  @override
  State<DownloadLibrarySidePanel> createState() =>
      _DownloadLibrarySidePanelState();
}

class _DownloadLibrarySidePanelState extends State<DownloadLibrarySidePanel> {
  late MetaItem _meta;
  int? _season;

  @override
  void initState() {
    super.initState();
    _meta = widget.seed;
    DownloadService.instance.tasksNotifier.addListener(_onTasks);
    unawaited(_loadSnapshot());
  }

  @override
  void didUpdateWidget(covariant DownloadLibrarySidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed.id != widget.seed.id) {
      _meta = widget.seed;
      _season = null;
      unawaited(_loadSnapshot());
    }
  }

  @override
  void dispose() {
    DownloadService.instance.tasksNotifier.removeListener(_onTasks);
    super.dispose();
  }

  void _onTasks() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSnapshot() async {
    final id = mediaIdForMetaItem(widget.seed);
    final saved = await DownloadPageStore.readMeta(id);
    if (!mounted || saved == null) return;
    if (mediaIdForMetaItem(widget.seed) != id) return;
    setState(() => _meta = saved);
  }

  String get _mediaId => mediaIdForMetaItem(_meta);

  List<DownloadTask> get _filesForTitle {
    final movie = metaItemToMovie(_meta);
    final bag = movie == null
        ? const <String>{}
        : buildSourcesRequestContext(
            movie: movie,
            meta: _meta,
            open: _meta.open,
          ).ids.values;
    final keys = <String>{
      if (_mediaId.trim().isNotEmpty) _mediaId.trim(),
      for (final raw in bag)
        if (raw.trim().isNotEmpty) raw.trim(),
    };
    final hits = [
      for (final task in DownloadService.instance.tasksNotifier.value)
        if (task.isCompleted && keys.contains(task.mediaId)) task,
    ];
    hits.sort((a, b) {
      final season = (a.season ?? 0).compareTo(b.season ?? 0);
      if (season != 0) return season;
      final episode = (a.episode ?? 0).compareTo(b.episode ?? 0);
      if (episode != 0) return episode;
      final aAt = a.completedAt ?? a.createdAt;
      final bAt = b.completedAt ?? b.createdAt;
      return aAt.compareTo(bAt);
    });
    return hits;
  }

  Future<void> _play(DownloadTask? task) async {
    if (task == null) {
      ForjaToast.info('No saved file');
      return;
    }
    final movie = metaItemToMovie(_meta);
    if (!mounted) return;
    await playCompletedDownloadTask(context, task, movie: movie);
  }

  String? get _year {
    final raw = _meta.releaseInfo.trim();
    return RegExp(r'(?:19|20)\d{2}').firstMatch(raw)?.group(0);
  }

  String? get _runtime {
    final facts = _meta.facts;
    if (facts == null) return null;
    final raw = facts['runtimeMinutes'] ?? facts['runtime'];
    final mins = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (mins == null || mins <= 0) return null;
    final hours = mins ~/ 60;
    final rem = mins % 60;
    if (hours == 0) return '${rem}m';
    if (rem == 0) return '${hours}h';
    return '${hours}h ${rem}m';
  }

  String? get _rating {
    final value = _meta.rating;
    if (value == null || value <= 0) return null;
    return value.toStringAsFixed(1);
  }

  String get _genres {
    return _meta.genres
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty)
        .take(2)
        .join(' · ');
  }

  String get _metaLine {
    final year = _year;
    final runtime = _runtime;
    final rating = _rating;
    final genres = _genres;
    return [
      ?year,
      ?runtime,
      ?rating,
      if (genres.isNotEmpty) genres,
    ].join(' · ');
  }

  bool get _isSeries =>
      _filesForTitle.any((task) => task.season != null || task.episode != null);

  List<int> get _seasons {
    final seasons = <int>{
      for (final task in _filesForTitle)
        if (task.season != null || task.episode != null) task.season ?? 1,
    }.toList()
      ..sort();
    return seasons;
  }

  int? get _activeSeason {
    final seasons = _seasons;
    if (seasons.isEmpty) return null;
    final current = _season;
    if (current != null && seasons.contains(current)) return current;
    return seasons.first;
  }

  List<DownloadTask> get _visibleFiles {
    if (!_isSeries) return _filesForTitle;
    final season = _activeSeason;
    return [
      for (final task in _filesForTitle)
        if ((task.season ?? 1) == season) task,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pad = ShellTokens.shellProviderRailPadH;
    return ColoredBox(
      color: ForjaShellColors.bgDark,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _hero(pad),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(pad, 4, pad, pad),
                children: [
                  _overview(),
                  SizedBox(height: pad),
                  _sources(pad),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(double pad) {
    final title = _meta.name.trim().isEmpty ? 'Saved' : _meta.name.trim();
    final backdrop = _meta.background.trim().isNotEmpty
        ? _meta.background.trim()
        : _meta.poster.trim();
    final logo = _meta.logo.trim();
    const backdropH = 280.0;
    final meta = _metaLine;
    return SizedBox(
      height: backdropH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _still(backdrop),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  ForjaShellColors.bgDark,
                ],
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              onPressed: widget.onClosed,
              icon: const Icon(Icons.close_rounded),
              color: ForjaShellColors.textPrimary,
            ),
          ),
          Positioned(
            left: pad,
            right: pad,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (logo.isNotEmpty)
                  SizedBox(
                    height: 72,
                    width: 220,
                    child: ForjaNetworkImage(
                      url: logo,
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomLeft,
                    ),
                  )
                else
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: ForjaShellColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                  ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _still(String url) {
    if (url.isEmpty) {
      return const ColoredBox(color: ForjaShellColors.surfaceElevated);
    }
    return ForjaNetworkImage(url: url, fit: BoxFit.cover);
  }

  Widget _overview() {
    final overview = _meta.description.trim();
    if (overview.isEmpty) return const SizedBox.shrink();
    return Text(
      overview,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: ForjaShellColors.textPrimary,
        height: 1.4,
        fontSize: 13,
      ),
    );
  }

  Widget _sources(double pad) {
    final files = _visibleFiles;
    final seasons = _seasons;
    final season = _activeSeason;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isSeries && season != null) ...[
          Select<int>(
            value: season,
            options: [
              for (final number in seasons)
                SelectOption(value: number, label: 'Season $number'),
            ],
            onChanged: (next) {
              if (next == null || next == _season) return;
              setState(() => _season = next);
            },
          ),
          SizedBox(height: pad),
        ] else
          Text(
            files.length == 1 ? 'Saved' : 'Saved · ${files.length}',
            style: const TextStyle(
              color: ForjaShellColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        if (!_isSeries) const SizedBox(height: 8),
        if (files.isEmpty)
          const Text(
            'No saved file',
            style: TextStyle(color: ForjaShellColors.textSecondary),
          )
        else
          for (var i = 0; i < files.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _sourceRow(files[i]),
          ],
      ],
    );
  }

  Widget _sourceRow(DownloadTask task) {
    final episode = task.season != null || task.episode != null;
    final source = offlineDownloadRowLabel(task);
    final size = task.totalBytes > 0
        ? DownloadTask.formatBytes(task.totalBytes)
        : '';
    final title = episode
        ? _episodeLabel(
            task.season ?? 1,
            task.episode ?? 1,
            _episodeTitle(task),
          )
        : source;
    final subtitle = [
      if (episode && source.isNotEmpty) source,
      if (size.isNotEmpty) size,
    ].join(' · ');
    return _DownloadSourceRow(
      title: title,
      subtitle: subtitle,
      onTap: () => unawaited(_play(task)),
    );
  }

  String _episodeTitle(DownloadTask task) {
    final direct = task.episodeTitle?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    for (final video in _meta.videos) {
      if (video.season == task.season && video.episode == task.episode) {
        final title = video.title.trim();
        if (title.isNotEmpty) return title;
      }
    }
    return '';
  }

  String _episodeLabel(int season, int episode, String title) {
    final code =
        'S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}';
    if (title.isEmpty) return code;
    return '$code · $title';
  }
}

/// Same hover as a Sources row: fill and border, no size change.
class _DownloadSourceRow extends StatefulWidget {
  const _DownloadSourceRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_DownloadSourceRow> createState() => _DownloadSourceRowState();
}

class _DownloadSourceRowState extends State<_DownloadSourceRow> {
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  var _focused = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  bool _active(bool hovered) {
    return ShellInputPolicy.interactiveActive(
      ShellScope.inputPolicyOf(context),
      hovered: hovered,
      focused: _focused,
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 10,
      scaleOnFocus: 1.0,
      showFocusBorder: false,
      showFocusFill: false,
      suppressInkHover: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => _hoveredN.value = hovered,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _hoveredN.value = true,
        onExit: (_) => _hoveredN.value = false,
        child: ListenableBuilder(
          listenable: _hoveredN,
          builder: (context, _) {
            final active = _active(_hoveredN.value);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: active
                    ? ForjaShellColors.chipSelectedBg
                    : ForjaShellColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active
                      ? ForjaShellColors.chipSelectedBorder
                      : ForjaShellColors.borderSubtle,
                  width: active ? 1.5 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: ForjaShellColors.brandGreen,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ForjaShellColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                          if (widget.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              widget.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: ForjaShellColors.textSecondary,
                                fontSize: 12,
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
    );
  }
}
