import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/shared/downloads/download_guards.dart';
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
    // Ensure queue is visible even if bootstrap init raced an early enqueue.
    unawaited(DownloadService.instance.ensureQueueVisible());
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
    final file = File(path.startsWith('file://') ? Uri.parse(path).toFilePath() : path);
    if (!await file.exists()) {
      ForjaToast.error('Download file is missing');
      return;
    }
    try {
      final raf = await file.open();
      try {
        final head = await raf.read(512);
        if (!looksLikeMediaContainerBytes(head)) {
          ForjaToast.error(
            'Downloaded file can’t be played — delete it and download again',
          );
          return;
        }
      } finally {
        await raf.close();
      }
    } catch (_) {
      ForjaToast.error('Downloaded file can’t be played');
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
      pinSource: true,
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
              totalBytes: _space?.totalBytes,
              downloadsDir: _downloadsDir,
              onRefreshSpace: _loadSpace,
            ),
            SizedBox(height: SettingsTokens.storageBlockGapOf(context)),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: ForjaShellColors.brandGreen,
              indicatorWeight: 3,
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
                    emptyHint: 'Start one from details, Sources, or the player.',
                    trailing: null,
                    itemBuilder: (task) => _ActiveTile(
                      task: task,
                      onChanged: _loadSpace,
                    ),
                  ),
                  _TaskList(
                    tasks: completed,
                    emptyLabel: 'No offline downloads yet',
                    emptyHint:
                        'Finished titles show up here — play anytime without a network.',
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
    required this.totalBytes,
    required this.downloadsDir,
    required this.onRefreshSpace,
  });

  final int usedBytes;
  final int? freeBytes;
  final int? totalBytes;
  final String? downloadsDir;
  final VoidCallback onRefreshSpace;

  @override
  Widget build(BuildContext context) {
    final gap = SettingsTokens.storageBlockGapOf(context);
    final usedLabel = DownloadTask.formatBytes(usedBytes);
    final free = freeBytes ?? 0;
    final total = totalBytes ?? 0;
    final freeLabel =
        freeBytes == null ? '…' : DownloadTask.formatBytes(free);
    final totalLabel =
        totalBytes == null ? '…' : DownloadTask.formatBytes(total);

    // Volume breakdown: offline library · other used · available.
    final offline = usedBytes.clamp(0, total > 0 ? total : usedBytes);
    final other = total > 0
        ? (total - free - offline).clamp(0, total)
        : 0;
    final available = free.clamp(0, total > 0 ? total : free);
    final sum = offline + other + available;
    final denom = total > 0
        ? total.toDouble()
        : (sum > 0 ? sum : 1).toDouble();

    return Padding(
      padding: SettingsTokens.storageBlockPadOf(context),
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
                      'Storage',
                      style: TextStyle(
                        color: ForjaShellColors.textPrimary,
                        fontSize: SettingsTokens.typeSizeOf(context, 18),
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(
                      height: SettingsTokens.rowTitleSubtitleGapOf(context),
                    ),
                    Text(
                      'Offline library on this device.',
                      style: TextStyle(
                        color: ForjaShellColors.textSecondary,
                        fontSize: SettingsTokens.rowSubtitleSizeOf(context),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Button(
                variant: ButtonVariant.outline,
                size: ButtonSize.sm,
                onPressed: onRefreshSpace,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: SettingsTokens.typeSizeOf(context, 14),
                      color: ForjaShellColors.iconActive,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Refresh',
                      style: TextStyle(
                        color: ForjaShellColors.textSecondary,
                        fontSize: SettingsTokens.typeSizeOf(context, 12),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: gap + 4),
          Text.rich(
            TextSpan(
              style: TextStyle(
                color: ForjaShellColors.textPrimary,
                fontSize: SettingsTokens.rowTitleSizeOf(context),
                height: 1.3,
              ),
              children: [
                TextSpan(
                  text: usedLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: ' used of '),
                TextSpan(
                  text: totalLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: '  ·  $freeLabel free',
                  style: TextStyle(
                    color: ForjaShellColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: SettingsTokens.rowSubtitleSizeOf(context),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: gap),
          _StorageMeter(
            offlineFraction: offline / denom,
            otherFraction: other / denom,
          ),
          SizedBox(height: gap),
          Wrap(
            spacing: SettingsTokens.storageLegendGapOf(context),
            runSpacing: 8,
            children: const [
              _StorageLegendDot(
                color: ForjaShellColors.storageOffline,
                label: 'Offline',
                hatched: true,
              ),
              _StorageLegendDot(
                color: ForjaShellColors.storageOther,
                label: 'Other',
              ),
              _StorageLegendDot(
                color: ForjaShellColors.storageAvailable,
                label: 'Available',
              ),
            ],
          ),
          if (downloadsDir != null) ...[
            SizedBox(height: gap),
            Text(
              downloadsDir!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ForjaShellColors.iconMuted,
                fontSize: SettingsTokens.typeSizeOf(context, 11.5),
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StorageMeter extends StatelessWidget {
  const _StorageMeter({
    required this.offlineFraction,
    required this.otherFraction,
  });

  final double offlineFraction;
  final double otherFraction;

  @override
  Widget build(BuildContext context) {
    final height = SettingsTokens.storageMeterHeightOf(context);
    final radius = SettingsTokens.storageMeterRadiusOf(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: ForjaShellColors.borderSubtle,
          width: SettingsTokens.storageMeterBorderWidth,
        ),
        color: ForjaShellColors.storageAvailable,
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final offlineW = (w * offlineFraction.clamp(0.0, 1.0));
          final otherW = (w * otherFraction.clamp(0.0, 1.0));
          return Row(
            children: [
              if (offlineW > 0.5)
                SizedBox(
                  width: offlineW,
                  height: height,
                  child: CustomPaint(
                    painter: _HatchedSegmentPainter(
                      fill: ForjaShellColors.storageOffline,
                      hatch: ForjaShellColors.iconMuted.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              if (otherW > 0.5)
                Container(
                  width: otherW,
                  height: height,
                  color: ForjaShellColors.storageOther,
                ),
              const Expanded(child: SizedBox.expand()),
            ],
          );
        },
      ),
    );
  }
}

class _HatchedSegmentPainter extends CustomPainter {
  _HatchedSegmentPainter({required this.fill, required this.hatch});

  final Color fill;
  final Color hatch;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = fill);
    final paint = Paint()
      ..color = hatch
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const step = 6.0;
    for (var x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HatchedSegmentPainter old) =>
      old.fill != fill || old.hatch != hatch;
}

class _StorageLegendDot extends StatelessWidget {
  const _StorageLegendDot({
    required this.color,
    required this.label,
    this.hatched = false,
  });

  final Color color;
  final String label;
  final bool hatched;

  @override
  Widget build(BuildContext context) {
    final size = SettingsTokens.storageLegendDotSizeOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: hatched
                ? Border.all(
                    color: ForjaShellColors.iconMuted.withValues(alpha: 0.5),
                    width: 0.8,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: ForjaShellColors.textSecondary,
            fontSize: SettingsTokens.rowSubtitleSizeOf(context),
            fontWeight: FontWeight.w500,
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
    required this.emptyHint,
    required this.itemBuilder,
    this.trailing,
  });

  final List<DownloadTask> tasks;
  final String emptyLabel;
  final String emptyHint;
  final Widget Function(DownloadTask task) itemBuilder;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.download_outlined,
                size: SettingsTokens.typeSizeOf(context, 36),
                color: ForjaShellColors.iconMuted,
              ),
              SizedBox(height: SettingsTokens.storageBlockGapOf(context)),
              Text(
                emptyLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ForjaShellColors.textPrimary,
                  fontSize: SettingsTokens.rowTitleSizeOf(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(
                height: SettingsTokens.rowTitleSubtitleGapOf(context) + 2,
              ),
              Text(
                emptyHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: SettingsTokens.rowSubtitleSizeOf(context),
                  height: 1.4,
                ),
              ),
            ],
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
            separatorBuilder: (_, _) =>
                SizedBox(height: SettingsTokens.storageBlockGapOf(context) - 2),
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
    final radius = SettingsTokens.storageMeterRadiusOf(context) + 2;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SettingsTokens.rowPadH + 10,
        vertical: SettingsTokens.rowPadV - 2,
      ),
      decoration: BoxDecoration(
        color: ForjaShellColors.surfaceElevated,
        borderRadius: BorderRadius.circular(radius),
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
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: ForjaShellColors.storageAvailable,
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
