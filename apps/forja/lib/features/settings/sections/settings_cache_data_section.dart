import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/playback/settings_data_cleaner.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:rust/rust.dart';

/// Clear stream caches, images, provider scores, and local watch data.
class SettingsCacheDataSection extends StatefulWidget {
  const SettingsCacheDataSection({
    super.key,
    this.showIptvPortalCache = true,
  });

  final bool showIptvPortalCache;

  @override
  State<SettingsCacheDataSection> createState() =>
      _SettingsCacheDataSectionState();
}

class _SettingsCacheDataSectionState extends State<SettingsCacheDataSection> {
  _ClearBusy? _busy;

  @override
  Widget build(BuildContext context) {
    final mentionTorrent =
        !PlatformInfo.isAndroidTv &&
        PlatformPlayback.capabilities.localTorrentEngine;
    final streamSubtitle = mentionTorrent
        ? 'Saved webstreaming and anime stream URLs, torrent temp files, '
            'and seek buffers. Next play re-resolves. Settings and watch history stay.'
        : 'Saved webstreaming and anime stream URLs and seek buffers. '
            'Next play re-resolves. Settings and watch history stay.';
    final streamBody = mentionTorrent
        ? 'Clears saved stream extracts, torrent download cache, and '
            'temporary seek buffers on this device.\n\n'
            'Watch history, provider scores, and settings are not affected.'
        : 'Clears saved stream extracts and temporary seek buffers on this '
            'device.\n\n'
            'Watch history, provider scores, and settings are not affected.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: 'Safe to clear',
          children: [
            _ClearTile(
              busy: _busy == _ClearBusy.streams,
              icon: Icons.cached_rounded,
              iconColor: const Color(0xFFFB923C),
              title: 'Stream cache',
              subtitle: streamSubtitle,
              onTap: () => _run(
                kind: _ClearBusy.streams,
                title: 'Clear stream cache?',
                body: streamBody,
                confirmLabel: 'Clear',
                success: 'Stream cache cleared',
                action: SettingsDataCleaner.clearStreamCaches,
              ),
            ),
            _ClearTile(
              busy: _busy == _ClearBusy.images,
              icon: Icons.image_outlined,
              iconColor: const Color(0xFF38BDF8),
              title: 'Images & WebView',
              subtitle:
                  'Poster thumbnails and extractor WebView caches. Frees disk; '
                  'images re-download when needed.',
              onTap: () => _run(
                kind: _ClearBusy.images,
                title: 'Clear images & WebView?',
                body:
                    'Clears cached posters and WebView extract data on this device. '
                    'Your lists and watch history are not affected.',
                confirmLabel: 'Clear',
                success: 'Images & WebView cache cleared',
                action: SettingsDataCleaner.clearImageAndWebViewCaches,
              ),
            ),
            if (widget.showIptvPortalCache)
              _ClearTile(
                busy: _busy == _ClearBusy.iptvPortals,
                icon: Icons.live_tv_outlined,
                iconColor: const Color(0xFF34D399),
                title: 'IPTV portal cache',
                subtitle:
                    'Catalogs, alive checks, and channel scans. '
                    'Portals and favorites stay; next open re-fetches.',
                onTap: () => _run(
                  kind: _ClearBusy.iptvPortals,
                  title: 'Clear IPTV portal cache?',
                  body:
                      'Clears saved catalogs, alive-channel checks, and channel '
                      'scan hits for all IPTV portals on this device.\n\n'
                      'Saved portals, favorites, and M3U playlists are not affected.',
                  confirmLabel: 'Clear',
                  success: 'IPTV portal cache cleared',
                  action: SettingsDataCleaner.clearIptvPortalCaches,
                ),
              ),
            if (Platform.isMacOS || Platform.isWindows || Platform.isLinux)
              _ClearTile(
                busy: _busy == _ClearBusy.updates,
                icon: Icons.system_update_alt_outlined,
                iconColor: const Color(0xFFA78BFA),
                title: 'Downloaded updates',
                subtitle:
                    'Installer files saved by in-app update (.dmg, .exe, AppImage). '
                    'Safe to remove after you install or if you downloaded again.',
                onTap: () => _run(
                  kind: _ClearBusy.updates,
                  title: 'Clear downloaded updates?',
                  body:
                      'Removes update installers Forja saved in Downloads, app storage, '
                      'or temp while downloading.\n\n'
                      'Your installed app version and settings are not affected.',
                  confirmLabel: 'Clear',
                  success: 'Downloaded update files cleared',
                  action: SettingsDataCleaner.clearDownloadedUpdates,
                ),
              ),
          ],
        ),
        SettingsGroup(
          label: 'Learned',
          children: [
            _ClearTile(
              busy: _busy == _ClearBusy.scores,
              icon: Icons.insights_outlined,
              iconColor: const Color(0xFFFBBF24),
              title: 'Provider scores',
              subtitle:
                  'Reliability totals used for Settings Score and Auto order. '
                  'Your drag order is kept; scores start over.',
              onTap: () => _run(
                kind: _ClearBusy.scores,
                title: 'Reset provider scores?',
                body:
                    'Clears learned reliability for all providers on this device. '
                    'Settings Score goes back to 0 and Auto re-learns from new checks.\n\n'
                    'Your preferred drag order is not changed.',
                confirmLabel: 'Reset scores',
                success: 'Provider scores reset',
                action: SettingsDataCleaner.clearProviderScores,
              ),
            ),
          ],
        ),
        SettingsGroup(
          label: 'Watch data',
          children: [
            _ClearTile(
              busy: _busy == _ClearBusy.continueWatching,
              icon: Icons.history_rounded,
              iconColor: const Color(0xFFF87171),
              title: 'Continue watching',
              subtitle:
                  'Home, Anime, Asian Drama, and Anime Arabic resume rows. '
                  'Cannot be undone on this device.',
              onTap: () => _run(
                kind: _ClearBusy.continueWatching,
                title: 'Clear continue watching?',
                body:
                    'Removes all resume / continue-watching entries for movies, TV, '
                    'anime, Asian drama, and anime Arabic on this device.\n\n'
                    'Trakt or Simkl cloud history is not deleted. My List and liked '
                    'items are kept.',
                confirmLabel: 'Clear history',
                success: 'Continue watching cleared',
                action: SettingsDataCleaner.clearContinueWatching,
                destructive: true,
              ),
            ),
            _ClearTile(
              busy: _busy == _ClearBusy.watched,
              icon: Icons.check_circle_outline_rounded,
              iconColor: const Color(0xFFF87171),
              title: 'Watched episode marks',
              subtitle:
                  'Local “watched” checkmarks on TV episode lists. '
                  'Trakt / Simkl online history stays.',
              onTap: () => _run(
                kind: _ClearBusy.watched,
                title: 'Clear watched marks?',
                body:
                    'Removes local episode watched checkmarks on this device. '
                    'Continue watching progress is kept unless you clear it separately.\n\n'
                    'Trakt / Simkl may show episodes as watched again after sync.',
                confirmLabel: 'Clear marks',
                success: 'Watched marks cleared',
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
      if (mounted) ForjaToast.error('Failed: $e');
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
