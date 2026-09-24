import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/shared/downloads/download_path_helper.dart';
import 'package:forja/shared/downloads/download_service.dart';
import 'package:forja/shared/downloads/download_task.dart';
import 'package:forja/shared/downloads/storage_space_helper.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shell/routing/app_router.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:rust/rust.dart';

/// Settings → Downloads — Active queue + Completed offline library.
class SettingsDownloadsPageBody extends StatefulWidget {
  const SettingsDownloadsPageBody({super.key});

  @override
  State<SettingsDownloadsPageBody> createState() =>
      _SettingsDownloadsPageBodyState();
}

class _SettingsDownloadsPageBodyState extends State<SettingsDownloadsPageBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  StorageSpaceInfo? _space;
  String? _downloadsDir;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    unawaited(_loadSpace());
    unawaited(DownloadService.instance.initialize());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadSpace() async {
    try {
      final dir = await DownloadPathHelper.getDownloadsDirectoryPath();
      final space = await StorageSpaceHelper.getAvailableSpace(dir);
      if (!mounted) return;
      setState(() {
        _downloadsDir = dir;
        _space = space;
      });
    } catch (e) {
      debugPrint('[SettingsDownloads] space check failed: $e');
    }
  }

  Future<void> _confirmDeleteAllCompleted() async {
    final ok = await showSettingsConfirmDialog(
      context: context,
      title: 'Delete all completed?',
      body:
          'Removes every finished download from this device and frees the disk space.',
      confirmLabel: 'Delete all',
      destructive: true,
    );
    if (!ok) return;
    await DownloadService.instance.deleteAllCompleted();
    await _loadSpace();
    if (mounted) ForjaToast.success('Completed downloads deleted');
  }

  Future<void> _playOffline(DownloadTask task) async {
    final path = task.targetFilePath.trim();
    if (path.isEmpty) {
      ForjaToast.error('Download file is missing');
      return;
    }
    final streamUrl =
        path.startsWith('file://') ? path : Uri.file(path).toString();
    if (!mounted) return;
    await AppRouter.openPlayer(
      context,
      streamUrl: streamUrl,
      title: task.title,
      movie: Movie(
        id: int.tryParse(task.mediaId) ?? 0,
        title: task.title,
        mediaType: task.type == 'series' ? 'tv' : task.type,
        posterPath: task.posterUrl ?? '',
        backdropPath: task.backdropUrl ?? '',
        voteAverage: 0,
        releaseDate: task.year ?? '',
      ),
      selectedSeason: task.season,
      selectedEpisode: task.episode,
      activeProvider: 'offline',
      streamsPrevalidated: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<DownloadTask>>(
      valueListenable: DownloadService.instance.tasksNotifier,
      builder: (context, tasks, _) {
        final active = [
          for (final t in tasks)
            if (t.status == DownloadStatus.queued ||
                t.status == DownloadStatus.downloading ||
                t.status == DownloadStatus.paused ||
                t.status == DownloadStatus.failed)
              t,
        ];
        final completed = [
          for (final t in tasks)
            if (t.isCompleted) t,
        ];
        final used = DownloadService.instance.totalUsedBytes;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StorageHeader(
              usedBytes: used,
              freeBytes: _space?.freeBytes,
              downloadsDir: _downloadsDir,
              onRefreshSpace: _loadSpace,
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: ForjaShellColors.brandGreen,
              labelColor: ForjaShellColors.textPrimary,
              unselectedLabelColor: ForjaShellColors.textSecondary,
              dividerColor: ForjaShellColors.borderSubtle,
              labelStyle: TextStyle(
                fontSize: SettingsTokens.typeSizeOf(context, 13),
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: SettingsTokens.typeSizeOf(context, 13),
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(text: 'Active (${active.length})'),
                Tab(text: 'Completed (${completed.length})'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _TaskList(
                    tasks: active,
                    emptyLabel: 'No active downloads',
                    trailing: null,
                    itemBuilder: (task) => _ActiveTile(
                      task: task,
                      onChanged: _loadSpace,
                    ),
                  ),
                  _TaskList(
                    tasks: completed,
                    emptyLabel: 'No offline downloads yet',
                    trailing: completed.isEmpty
                        ? null
                        : Button(
                            variant: ButtonVariant.ghost,
                            onPressed: () =>
                                unawaited(_confirmDeleteAllCompleted()),
                            child: Text(
                              'Delete all',
                              style: TextStyle(
                                color: ForjaShellColors.textSecondary,
                                fontSize:
                                    SettingsTokens.typeSizeOf(context, 12),
                              ),
                            ),
                          ),
                    itemBuilder: (task) => _CompletedTile(
                      task: task,
                      onPlay: () => unawaited(_playOffline(task)),
                      onDeleted: _loadSpace,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StorageHeader extends StatelessWidget {
  const _StorageHeader({
    required this.usedBytes,
    required this.freeBytes,
    required this.downloadsDir,
    required this.onRefreshSpace,
  });

  final int usedBytes;
  final int? freeBytes;
  final String? downloadsDir;
  final VoidCallback onRefreshSpace;

  @override
  Widget build(BuildContext context) {
    final usedLabel = DownloadTask.formatBytes(usedBytes);
    final freeLabel = freeBytes == null
        ? '…'
        : DownloadTask.formatBytes(freeBytes!);
    return SettingsGroup(
      label: 'Storage',
      children: [
        Padding(
          padding: SettingsTokens.rowPaddingOf(context),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$usedLabel used · $freeLabel free',
                      style: TextStyle(
                        color: ForjaShellColors.textPrimary,
                        fontSize: SettingsTokens.rowTitleSizeOf(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (downloadsDir != null) ...[
                      SizedBox(
                        height: SettingsTokens.rowTitleSubtitleGapOf(context),
                      ),
                      Text(
                        downloadsDir!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ForjaShellColors.textSecondary,
                          fontSize: SettingsTokens.rowSubtitleSizeOf(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Button(
                variant: ButtonVariant.plainIcon,
                size: ButtonSize.icon,
                onPressed: onRefreshSpace,
                child: Icon(
                  Icons.refresh_rounded,
                  size: SettingsTokens.iconButtonIconSizeOf(context),
                  color: ForjaShellColors.iconMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.tasks,
    required this.emptyLabel,
    required this.itemBuilder,
    this.trailing,
  });

  final List<DownloadTask> tasks;
  final String emptyLabel;
  final Widget Function(DownloadTask task) itemBuilder;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: TextStyle(
            color: ForjaShellColors.textSecondary,
            fontSize: SettingsTokens.typeSizeOf(context, 14),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (trailing != null)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: trailing!,
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.only(
              top: trailing == null ? 12 : 0,
              bottom: SettingsTokens.pagePaddingOf(context),
            ),
            itemCount: tasks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => itemBuilder(tasks[i]),
          ),
        ),
      ],
    );
  }
}

class _ActiveTile extends StatelessWidget {
  const _ActiveTile({required this.task, required this.onChanged});

  final DownloadTask task;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final svc = DownloadService.instance;
    final statusLabel = switch (task.status) {
      DownloadStatus.queued => 'Queued',
      DownloadStatus.downloading => task.speedLabel,
      DownloadStatus.paused => 'Paused',
      DownloadStatus.failed => task.error?.trim().isNotEmpty == true
          ? task.error!
          : 'Failed',
      _ => task.status.name,
    };

    return _DownloadCard(
      title: task.title,
      subtitle: [
        if (task.sourceName.trim().isNotEmpty) task.sourceName,
        task.sizeLabel,
        statusLabel,
        if (task.isDownloading && task.etaLabel != '--') 'ETA ${task.etaLabel}',
      ].join(' · '),
      progress: task.isDownloading || task.isPaused
          ? task.progressPercent
          : null,
      actions: [
        if (task.isDownloading)
          _IconAction(
            icon: Icons.pause_rounded,
            tooltip: 'Pause',
            onTap: () => unawaited(svc.pauseDownload(task.id)),
          ),
        if (task.isPaused || task.status == DownloadStatus.queued)
          _IconAction(
            icon: Icons.play_arrow_rounded,
            tooltip: 'Resume',
            onTap: () => unawaited(svc.resumeDownload(task.id)),
          ),
        if (task.isFailed)
          _IconAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Retry',
            onTap: () => unawaited(svc.resumeDownload(task.id)),
          ),
        _IconAction(
          icon: Icons.close_rounded,
          tooltip: 'Cancel',
          onTap: () async {
            await svc.cancelDownload(task.id);
            await svc.deleteDownload(task.id);
            onChanged();
          },
        ),
      ],
    );
  }
}

class _CompletedTile extends StatelessWidget {
  const _CompletedTile({
    required this.task,
    required this.onPlay,
    required this.onDeleted,
  });

  final DownloadTask task;
  final VoidCallback onPlay;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final size = DownloadTask.formatBytes(
      task.totalBytes > 0 ? task.totalBytes : task.receivedBytes,
    );
    return _DownloadCard(
      title: task.title,
      subtitle: [
        if (task.sourceName.trim().isNotEmpty) task.sourceName,
        size,
      ].join(' · '),
      actions: [
        _IconAction(
          icon: Icons.play_arrow_rounded,
          tooltip: 'Play offline',
          onTap: onPlay,
        ),
        _IconAction(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Delete',
          onTap: () async {
            final ok = await showSettingsConfirmDialog(
              context: context,
              title: 'Delete download?',
              body: 'Removes “${task.title}” from this device.',
              confirmLabel: 'Delete',
              destructive: true,
            );
            if (!ok) return;
            await DownloadService.instance.deleteDownload(task.id);
            onDeleted();
          },
        ),
      ],
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({
    required this.title,
    required this.subtitle,
    required this.actions,
    this.progress,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: SettingsTokens.rowPaddingOf(context),
      decoration: BoxDecoration(
        color: ForjaShellColors.surfaceElevated,
        borderRadius: BorderRadius.circular(SettingsTokens.categoryTileRadius),
        border: Border.all(color: ForjaShellColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ForjaShellColors.textPrimary,
                        fontSize: SettingsTokens.rowTitleSizeOf(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(
                      height: SettingsTokens.rowTitleSubtitleGapOf(context),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ForjaShellColors.textSecondary,
                        fontSize: SettingsTokens.rowSubtitleSizeOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: ForjaShellColors.borderSubtle,
                color: ForjaShellColors.brandGreen,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = SettingsTokens.iconButtonHitSizeOf(context);
    final iconSize = SettingsTokens.iconButtonIconSizeOf(context);
    return Tooltip(
      message: tooltip,
      child: shellFocusableTap(
        context: context,
        onTap: onTap,
        borderRadius: size / 2,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: ForjaShellColors.iconMuted),
        ),
      ),
    );
  }
}
