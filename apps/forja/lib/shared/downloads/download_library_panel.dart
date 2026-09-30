import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
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
        if (task.showsOnDownloadHub && keys.contains(task.mediaId)) task,
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

  Future<void> _playCloud(DownloadTask task) async {
    final movie = metaItemToMovie(_meta);
    if (!mounted) return;
    await playDownloadRemoteStream(context, task, movie: movie);
  }

  Future<void> _confirmDelete(DownloadTask task) async {
    final ok = await showSettingsConfirmDialog(
      context: context,
      title: 'Delete download?',
      body: 'Removes “${task.title}” from this device.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await DownloadService.instance.deleteDownload(task.id);
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
    }.toList()..sort();
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
                colors: [Color(0x66000000), ForjaShellColors.bgDark],
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
    if (_isSeries && season != null) {
      final cover = _meta.background.trim().isNotEmpty
          ? _meta.background.trim()
          : _meta.poster.trim();
      final episodes = savedEpisodeSlots(
        files: files,
        videos: _meta.videos,
        fallbackImage: cover,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          if (episodes.isEmpty)
            const Text(
              'No saved file',
              style: TextStyle(color: ForjaShellColors.textSecondary),
            )
          else
            for (var i = 0; i < episodes.length; i++) ...[
              if (i > 0) SizedBox(height: pad),
              _episodeBlock(episodes[i]),
            ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _filesHeading(files),
          style: const TextStyle(
            color: ForjaShellColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        if (files.isEmpty)
          const Text(
            'No saved file',
            style: TextStyle(color: ForjaShellColors.textSecondary),
          )
        else
          for (var i = 0; i < files.length; i++) ...[
            if (i > 0)
              SizedBox(
                height: ShellTokens.chromeScale(
                  6,
                  tv: ShellScope.metricsOf(context).usesTvDensity,
                ),
              ),
            _fileRow(files[i]),
          ],
      ],
    );
  }

  Widget _episodeBlock(SavedEpisodeSlot episode) {
    final gap = ShellTokens.chromeScale(
      6,
      tv: ShellScope.metricsOf(context).usesTvDensity,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SavedEpisodeHeader(episode: episode),
        SizedBox(height: gap),
        for (var i = 0; i < episode.files.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          _fileRow(episode.files[i]),
        ],
      ],
    );
  }

  String _filesHeading(List<DownloadTask> files) {
    final saving = files.where((task) => task.isActive).length;
    if (saving > 0) {
      return saving == 1 ? 'Downloading' : 'Downloading · $saving';
    }
    return files.length == 1 ? 'Saved' : 'Saved · ${files.length}';
  }

  Widget _fileRow(DownloadTask task) {
    final title = offlineDownloadRowLabel(task);
    final size = task.totalBytes > 0
        ? DownloadTask.formatBytes(task.totalBytes)
        : '';
    if (task.isActive) {
      return _DownloadActiveRow(task: task, title: title, footer: '');
    }
    return _DownloadSourceRow(
      title: title,
      size: size,
      footer: '',
      onTap: () => unawaited(_play(task)),
      onPlayCloud: downloadTaskHasRemoteStream(task)
          ? () => unawaited(_playCloud(task))
          : null,
      onDelete: () => unawaited(_confirmDelete(task)),
    );
  }
}

/// Episode row for the Downloads panel: still, number, title, and synopsis.
/// Files for that episode sit underneath.
class _SavedEpisodeHeader extends StatelessWidget {
  const _SavedEpisodeHeader({required this.episode});

  final SavedEpisodeSlot episode;

  static const _thumbWidth = 148.0;

  @override
  Widget build(BuildContext context) {
    final tv = ShellScope.metricsOf(context).usesTvDensity;
    final thumbW = ShellTokens.chromeScale(_thumbWidth, tv: tv);
    final thumbH = thumbW * 9 / 16;
    final radius = ShellTokens.chromeScale(6, tv: tv);
    final titleSize = tv ? ShellTokens.tvBodyFontSize : 14.0;
    final metaSize = tv ? ShellTokens.tvMetaFontSize : 12.0;
    final code = 'E${episode.episode}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: thumbW,
          height: thumbH,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _still(episode.thumbnail),
                Positioned(top: 6, left: 6, child: _EpisodeBadge(label: code)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                episode.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ForjaShellColors.textPrimary,
                  fontSize: titleSize,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              if (episode.airDate.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  episode.airDate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ForjaShellColors.textSecondary,
                    fontSize: metaSize,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
              if (episode.overview.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  episode.overview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ForjaShellColors.textSecondary,
                    fontSize: metaSize,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _still(String url) {
    if (url.isEmpty) {
      return const ColoredBox(color: ForjaShellColors.surfaceElevated);
    }
    return ForjaNetworkImage(url: url, fit: BoxFit.cover);
  }
}

class _EpisodeBadge extends StatelessWidget {
  const _EpisodeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tv = ShellScope.metricsOf(context).usesTvDensity;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tv ? 4 : 6,
        vertical: tv ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(tv ? 3 : 4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: tv ? ShellTokens.tvMetaFontSize : 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// In-progress file: square row, live percent, speed, and bar.
class _DownloadActiveRow extends StatelessWidget {
  const _DownloadActiveRow({
    required this.task,
    required this.title,
    required this.footer,
  });

  final DownloadTask task;
  final String title;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final metrics = ShellScope.metricsOf(context);
    final known = task.totalBytes > 0;
    final pct = known
        ? '${(task.progressPercent * 100).clamp(0, 100).toStringAsFixed(0)}%'
        : null;
    final speed = task.isDownloading && task.speedBytesPerSec > 0
        ? task.speedLabel
        : null;
    final eta = task.isDownloading && task.etaLabel != '--'
        ? 'ETA ${task.etaLabel}'
        : null;
    final status = [
      if (task.status == DownloadStatus.queued) 'Queued',
      if (task.isPaused) 'Paused',
      ?speed,
      ?pct,
      ?eta,
      if (footer.isNotEmpty) footer,
    ].join(' · ');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      padding: EdgeInsets.fromLTRB(
        metrics.torrentPanelRowPadH,
        metrics.torrentPanelRowPadV,
        metrics.torrentPanelRowPadH,
        metrics.torrentPanelRowPadV,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ForjaShellColors.textPrimary,
              fontSize: metrics.torrentPanelRowTitleFontSize,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
          if (status.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ForjaShellColors.brandGreen,
                fontSize: metrics.torrentPanelMetaFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: known ? task.progressPercent.clamp(0.0, 1.0) : null,
              minHeight: 4,
              backgroundColor: ForjaShellColors.storageAvailable,
              color: ForjaShellColors.brandGreen,
            ),
          ),
        ],
      ),
    );
  }
}

/// Flat Sources row: square card, size badge, Offline, cloud and delete.
class _DownloadSourceRow extends StatefulWidget {
  const _DownloadSourceRow({
    required this.title,
    required this.size,
    required this.footer,
    required this.onTap,
    required this.onDelete,
    this.onPlayCloud,
  });

  final String title;
  final String size;
  final String footer;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onPlayCloud;

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
    final metrics = ShellScope.metricsOf(context);
    final tv = metrics.usesTvDensity;
    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 0,
      scaleOnFocus: 1.0,
      showFocusBorder: false,
      showFocusFill: false,
      suppressInkHover: true,
      mouseDownActivates: false,
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
            final titleSize = metrics.torrentPanelRowTitleFontSize;
            final metaSize = metrics.torrentPanelMetaFontSize;
            final padH = metrics.torrentPanelRowPadH;
            final padV = metrics.torrentPanelRowPadV;
            final titleGap = tv ? 5.0 : 8.0;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: double.infinity,
              decoration: BoxDecoration(
                color: active
                    ? ForjaShellColors.chipSelectedBg
                    : Colors.white.withValues(alpha: 0.04),
                border: Border.all(
                  color: active
                      ? ForjaShellColors.chipSelectedBorder
                      : Colors.white.withValues(alpha: 0.07),
                  width: active ? 1.5 : 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(padH, padV, 4, padV),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ForjaShellColors.textPrimary,
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.w500,
                                    height: 1.25,
                                  ),
                                ),
                                if (widget.size.isNotEmpty) ...[
                                  SizedBox(height: titleGap),
                                  _DownloadSizeBadge(
                                    label: widget.size,
                                    tv: tv,
                                  ),
                                ],
                                if (widget.footer.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.footer,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: ForjaShellColors.textSecondary,
                                      fontSize: metaSize,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(width: titleGap),
                          Text(
                            'Offline',
                            style: TextStyle(
                              color: ForjaShellColors.brandGreen,
                              fontSize: metaSize,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _DownloadRowIcon(
                      tooltip: 'Play online',
                      icon: Icons.cloud_outlined,
                      onTap: widget.onPlayCloud,
                    ),
                    _DownloadRowIcon(
                      tooltip: 'Delete',
                      icon: Icons.delete_outline_rounded,
                      onTap: widget.onDelete,
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

class _DownloadSizeBadge extends StatelessWidget {
  const _DownloadSizeBadge({required this.label, required this.tv});

  final String label;
  final bool tv;

  @override
  Widget build(BuildContext context) {
    final metrics = ShellScope.metricsOf(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tv
            ? ShellTokens.torrentPanelRowBadgePadHTv
            : ShellTokens.torrentPanelRowBadgePadHDesktop,
        vertical: tv
            ? ShellTokens.torrentPanelRowBadgePadVTv
            : ShellTokens.torrentPanelRowBadgePadVDesktop,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(
          tv
              ? ShellTokens.torrentPanelRowBadgeRadiusTv
              : ShellTokens.torrentPanelRowBadgeRadiusDesktop,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: ForjaShellColors.textPrimary,
          fontSize: metrics.torrentPanelChipFontSize,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}

class _DownloadRowIcon extends StatefulWidget {
  const _DownloadRowIcon({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<_DownloadRowIcon> createState() => _DownloadRowIconState();
}

class _DownloadRowIconState extends State<_DownloadRowIcon> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    if (!enabled) return const SizedBox.shrink();
    final tv = ShellScope.metricsOf(context).usesTvDensity;
    final hit = ShellTokens.chromeScale(40, tv: tv);
    final iconSize = ShellTokens.chromeScale(20, tv: tv);
    final color = _hovered ? ForjaShellColors.brandGreen : Colors.white60;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(
            width: hit,
            height: hit,
            child: Icon(widget.icon, size: iconSize, color: color),
          ),
        ),
      ),
    );
  }
}
