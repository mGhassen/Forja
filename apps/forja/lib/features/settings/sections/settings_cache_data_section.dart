import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/playback/settings_data_cleaner.dart';

/// Clear stream caches, images, provider scores, and local watch data.
class SettingsCacheDataSection extends StatefulWidget {
  const SettingsCacheDataSection({super.key});

  @override
  State<SettingsCacheDataSection> createState() =>
      _SettingsCacheDataSectionState();
}

class _SettingsCacheDataSectionState extends State<SettingsCacheDataSection> {
  _ClearBusy? _busy;

  @override
  Widget build(BuildContext context) {
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
              subtitle:
                  'Saved webstreaming and anime stream URLs, torrent temp files, '
                  'and seek buffers. Next play re-resolves. Settings and watch history stay.',
              onTap: () => _run(
                kind: _ClearBusy.streams,
                title: 'Clear stream cache?',
                body:
                    'Clears saved stream extracts, torrent download cache, and '
                    'temporary seek buffers on this device.\n\n'
                    'Watch history, provider scores, and settings are not affected.',
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

enum _ClearBusy { streams, images, scores, continueWatching, watched }

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
          : const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFF87171),
            ),
      onTap: onTap,
      destructive: false,
    );
  }
}
