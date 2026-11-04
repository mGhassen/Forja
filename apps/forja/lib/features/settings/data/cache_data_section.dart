import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/l10n/l10n.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shared/playback/cache/settings_data_cleaner.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:rust/rust.dart';

/// Clear stream caches, images, provider scores, and local watch data.
class SettingsCacheDataSection extends StatefulWidget {
  const SettingsCacheDataSection({
    super.key,
    this.showPortalCache = true,
  });

  final bool showPortalCache;

  @override
  State<SettingsCacheDataSection> createState() =>
      _SettingsCacheDataSectionState();
}

class _SettingsCacheDataSectionState extends State<SettingsCacheDataSection> {
  _ClearBusy? _busy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mentionTorrent =
        !PlatformInfo.isAndroidTv &&
        PlatformPlayback.capabilities.localTorrentEngine;
    final streamSubtitle = mentionTorrent
        ? l.dataStreamSubtitleTorrent
        : l.dataStreamSubtitle;
    final streamBody = mentionTorrent
        ? l.dataStreamBodyTorrent
        : l.dataStreamBody;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: l.dataGroupSafeToClear,
          children: [
            _ClearTile(
              busy: _busy == _ClearBusy.streams,
              icon: Icons.cached_rounded,
              iconColor: const Color(0xFFFB923C),
              title: l.dataStreamCacheTitle,
              subtitle: streamSubtitle,
              onTap: () => _run(
                kind: _ClearBusy.streams,
                title: l.dataStreamClearTitle,
                body: streamBody,
                confirmLabel: l.dataClear,
                success: l.dataStreamCleared,
                action: SettingsDataCleaner.clearStreamCaches,
              ),
            ),
            _ClearTile(
              busy: _busy == _ClearBusy.images,
              icon: Icons.image_outlined,
              iconColor: const Color(0xFF38BDF8),
              title: l.dataImagesTitle,
              subtitle: l.dataImagesSubtitle,
              onTap: () => _run(
                kind: _ClearBusy.images,
                title: l.dataImagesClearTitle,
                body: l.dataImagesClearBody,
                confirmLabel: l.dataClear,
                success: l.dataImagesCleared,
                action: SettingsDataCleaner.clearImageAndWebViewCaches,
              ),
            ),
            if (widget.showPortalCache)
              _ClearTile(
                busy: _busy == _ClearBusy.iptvPortals,
                icon: Icons.live_tv_outlined,
                iconColor: const Color(0xFF34D399),
                title: l.dataPortalTitle,
                subtitle: l.dataPortalSubtitle,
                onTap: () => _run(
                  kind: _ClearBusy.iptvPortals,
                  title: l.dataPortalClearTitle,
                  body: l.dataPortalClearBody,
                  confirmLabel: l.dataClear,
                  success: l.dataPortalCleared,
                  action: SettingsDataCleaner.clearPortalCaches,
                ),
              ),
            if (Platform.isMacOS || Platform.isWindows || Platform.isLinux)
              _ClearTile(
                busy: _busy == _ClearBusy.updates,
                icon: Icons.system_update_alt_outlined,
                iconColor: const Color(0xFFA78BFA),
                title: l.dataUpdatesTitle,
                subtitle: l.dataUpdatesSubtitle,
                onTap: () => _run(
                  kind: _ClearBusy.updates,
                  title: l.dataUpdatesClearTitle,
                  body: l.dataUpdatesClearBody,
                  confirmLabel: l.dataClear,
                  success: l.dataUpdatesCleared,
                  action: SettingsDataCleaner.clearDownloadedUpdates,
                ),
              ),
          ],
        ),
        SettingsGroup(
          label: l.dataGroupLearned,
          children: [
            _ClearTile(
              busy: _busy == _ClearBusy.scores,
              icon: Icons.insights_outlined,
              iconColor: const Color(0xFFFBBF24),
              title: l.dataScoresTitle,
              subtitle: l.dataScoresSubtitle,
              onTap: () => _run(
                kind: _ClearBusy.scores,
                title: l.dataScoresResetTitle,
                body: l.dataScoresResetBody,
                confirmLabel: l.dataScoresResetConfirm,
                success: l.dataScoresReset,
                action: SettingsDataCleaner.clearProviderScores,
              ),
            ),
          ],
        ),
        SettingsGroup(
          label: l.dataGroupWatchData,
          children: [
            _ClearTile(
              busy: _busy == _ClearBusy.continueWatching,
              icon: Icons.history_rounded,
              iconColor: const Color(0xFFF87171),
              title: l.dataContinueTitle,
              subtitle: l.dataContinueSubtitle,
              onTap: () => _run(
                kind: _ClearBusy.continueWatching,
                title: l.dataContinueClearTitle,
                body: l.dataContinueClearBody,
                confirmLabel: l.dataContinueClearConfirm,
                success: l.dataContinueCleared,
                action: SettingsDataCleaner.clearContinueWatching,
                destructive: true,
              ),
            ),
            _ClearTile(
              busy: _busy == _ClearBusy.watched,
              icon: Icons.check_circle_outline_rounded,
              iconColor: const Color(0xFFF87171),
              title: l.dataWatchedTitle,
              subtitle: l.dataWatchedSubtitle,
              onTap: () => _run(
                kind: _ClearBusy.watched,
                title: l.dataWatchedClearTitle,
                body: l.dataWatchedClearBody,
                confirmLabel: l.dataWatchedClearConfirm,
                success: l.dataWatchedCleared,
                action: SettingsDataCleaner.clearWatchedEpisodes,
                destructive: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _run({
    required _ClearBusy kind,
    required String title,
    required String body,
    required String confirmLabel,
    required String success,
    required Future<void> Function() action,
    bool destructive = false,
  }) async {
    if (_busy != null) return;
    final confirm = await showSettingsConfirmDialog(
      context: context,
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      destructive: destructive,
    );
    if (!confirm || !mounted) return;
    setState(() => _busy = kind);
    try {
      await action();
      if (mounted) ForjaToast.success(success);
    } catch (e) {
      if (mounted) ForjaToast.error(context.l10n.dataFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }
}

enum _ClearBusy {
  streams,
  images,
  iptvPortals,
  updates,
  scores,
  continueWatching,
  watched,
}

class _ClearTile extends StatelessWidget {
  const _ClearTile({
    required this.busy,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool busy;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsActionRow(
      busy: busy,
      leading: Icon(icon, color: iconColor),
      title: title,
      subtitle: subtitle,
      trailing: busy
          ? null
          : const Icon(Icons.delete_outline_rounded, color: Color(0xFFF87171)),
      onTap: onTap,
      destructive: false,
    );
  }
}
