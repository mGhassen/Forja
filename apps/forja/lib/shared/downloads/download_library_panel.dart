import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/downloads/download_page_store.dart';
import 'package:forja/shared/downloads/download_play.dart';
import 'package:forja/shared/downloads/download_service.dart';
import 'package:forja/shared/downloads/download_task.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/hero_pill_buttons.dart';
import 'package:forja/shared/engine/runtime/open/meta_movie.dart';
import 'package:forja/shared/playback/sources_request_context.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:path/path.dart' as p;

/// Right panel for a saved title: downloaded info, episodes, play, file cards.
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
  bool _files = false;

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
      _files = false;
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

  bool get _isMovie => downloadTypeForMeta(_meta) == 'movie';

  List<({int season, int episode, String title, DownloadTask task})>
      get _episodes {
    if (_isMovie) return const [];
    final videos = _meta.videos;
    final out =
        <({int season, int episode, String title, DownloadTask task})>[];
    final seen = <String>{};
    for (final task in _filesForTitle) {
      if (task.season == null && task.episode == null) continue;
      final season = task.season ?? 1;
      final episode = task.episode ?? 1;
      if (!seen.add('$season:$episode')) continue;
      var title = task.episodeTitle?.trim() ?? '';
      if (title.isEmpty) {
        for (final video in videos) {
          if ((video.season ?? 1) == season &&
              (video.episode ?? 1) == episode &&
              video.title.trim().isNotEmpty) {
            title = video.title.trim();
            break;
          }
        }
      }
      out.add((
        season: season,
        episode: episode,
        title: title,
        task: task,
      ));
    }
    return out;
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

  @override
  Widget build(BuildContext context) {
    final pad = ShellTokens.shellProviderRailPadH;
    return ColoredBox(
      color: ForjaShellColors.bgDark,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              SizedBox(height: pad),
              if (!_files) ...[
                _playRow(),
                SizedBox(height: pad),
              ],
              Expanded(
                child: _files ? _fileList() : _info(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final title = _meta.name.trim().isEmpty ? 'Saved' : _meta.name.trim();
    return Row(
      children: [
        if (_files)
          IconButton(
            onPressed: () => setState(() => _files = false),
            icon: const Icon(Icons.arrow_back_rounded),
            color: ForjaShellColors.textPrimary,
          )
        else
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: ForjaShellColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        if (_files)
          Expanded(
            child: Text(
              'Files',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: ForjaShellColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        IconButton(
          onPressed: widget.onClosed,
          icon: const Icon(Icons.close_rounded),
          color: ForjaShellColors.textSecondary,
        ),
      ],
    );
  }

  Widget _playRow() {
    return Row(
      children: [
        HeroPillPlayButton(
          label: 'Play',
          onTap: () => unawaited(
            _play(_filesForTitle.isEmpty ? null : _filesForTitle.first),
          ),
        ),
        const SizedBox(width: 10),
        HeroPillPlayButton(
          label: 'Play',
          icon: Icons.folder_open_rounded,
          tone: HeroPillPlayTone.streaming,
          onTap: () => setState(() => _files = true),
        ),
      ],
    );
  }

  Widget _info() {
    final overview = _meta.description.trim();
    final year = _meta.releaseInfo.trim();
    final poster = _meta.poster.trim().isNotEmpty
        ? _meta.poster.trim()
        : _meta.background.trim();
    final episodes = _episodes;
    return ListView(
      children: [
        if (poster.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ShellTokens.shellHeaderTopPadding / 2),
              child: SizedBox(
                width: ShellTokens.sidePanelWidth * 0.36,
                height: ShellTokens.sidePanelWidth * 0.52,
                child: ForjaNetworkImage(url: poster),
              ),
            ),
          ),
        if (year.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            year,
            style: const TextStyle(color: ForjaShellColors.textSecondary),
          ),
        ],
        if (overview.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            overview,
            style: const TextStyle(
              color: ForjaShellColors.textPrimary,
              height: 1.35,
            ),
          ),
        ],
        if (episodes.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Episodes',
            style: TextStyle(
              color: ForjaShellColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final ep in episodes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _episodeLabel(ep.season, ep.episode, ep.title),
                style: const TextStyle(color: ForjaShellColors.textPrimary),
              ),
              onTap: () => unawaited(_play(ep.task)),
            ),
        ],
      ],
    );
  }

  Widget _fileList() {
    final files = _filesForTitle;
    if (files.isEmpty) {
      return const Center(
        child: Text(
          'No saved file',
          style: TextStyle(color: ForjaShellColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      itemCount: files.length,
      separatorBuilder: (_, _) =>
          const SizedBox(height: ShellTokens.sourcesStreamListSeparator),
      itemBuilder: (context, index) {
        final task = files[index];
        final size = task.totalBytes > 0
            ? DownloadTask.formatBytes(task.totalBytes)
            : '';
        return Material(
          color: ForjaShellColors.surfaceElevated,
          child: InkWell(
            onTap: () => unawaited(_play(task)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: ShellTokens.shellProviderRailPadH,
                vertical: ShellTokens.shellProviderRailPadV,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: ForjaShellColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fileCardTitle(task),
                    style: TextStyle(
                      color: ForjaShellColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: ShellTokens.torrentPanelRowTitleFontSizeDesktop,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      p.basename(task.targetFilePath),
                      if (size.isNotEmpty) size,
                    ].join(' · '),
                    style: const TextStyle(
                      color: ForjaShellColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _fileCardTitle(DownloadTask task) {
    if (task.season != null || task.episode != null) {
      return _episodeLabel(
        task.season ?? 1,
        task.episode ?? 1,
        task.episodeTitle?.trim() ?? '',
      );
    }
    final name = task.title.trim();
    return name.isEmpty ? 'File' : name;
  }

  String _episodeLabel(int season, int episode, String title) {
    final code =
        'S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}';
    if (title.isEmpty) return code;
    return '$code · $title';
  }
}
