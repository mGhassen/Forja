import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_expandable_section.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/playback/settings_data_cleaner.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

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
    return SettingsExpandableSection(
      id: 'cache_data',
      icon: Icons.cleaning_services_rounded,
      title: 'Cache & data',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'SAFE TO CLEAR',
            style: TextStyle(
              color: AppTheme.current.primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        _ClearTile(
          busy: _busy == _ClearBusy.streams,
          icon: Icons.cached_rounded,
          iconColor: Colors.orangeAccent,
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
          iconColor: Colors.lightBlueAccent,
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
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'LEARNED',
            style: TextStyle(
              color: AppTheme.current.primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        _ClearTile(
          busy: _busy == _ClearBusy.scores,
          icon: Icons.insights_outlined,
          iconColor: Colors.amberAccent,
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
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'WATCH DATA',
            style: TextStyle(
              color: AppTheme.current.primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        _ClearTile(
          busy: _busy == _ClearBusy.continueWatching,
          icon: Icons.history_rounded,
          iconColor: Colors.redAccent,
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
          iconColor: Colors.redAccent,
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(body, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: destructive ? Colors.redAccent : Colors.orangeAccent,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
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
    return shellFocusableTap(
      context: context,
      onTap: busy ? null : onTap,
      scaleOnFocus: 1.0,
      navLeftAlways: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      child: Card(
        child: ListTile(
          leading: Icon(icon, color: iconColor),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline, color: Colors.redAccent),
        ),
      ),
    );
  }
}
