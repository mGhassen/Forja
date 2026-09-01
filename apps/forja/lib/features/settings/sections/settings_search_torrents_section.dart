import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/playback/torrent_js_search.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/settings/widgets/settings_focus_controls.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';

/// Torrent engine and sort order settings.
class SettingsSearchTorrentsSection extends ConsumerWidget {
  const SettingsSearchTorrentsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final torrent = PlatformPlayback.capabilities.builtinTorrentSearch;
    if (!torrent) return const SizedBox.shrink();

    final settings = SettingsService();
    final notifier = ref.read(settingsTorrentProvider.notifier);
    final snap = ref.watch(settingsTorrentProvider).valueOrNull;
    if (snap == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: 'Torrent search',
          children: [
            settingsFocusableDropdown(
              context,
              'Default Sort Order',
              'How torrent results are sorted automatically.',
              snap.sortPreference,
              const [
                'Seeders (High to Low)',
                'Seeders (Low to High)',
                'Quality (High to Low)',
                'Quality (Low to High)',
                'Size (High to Low)',
                'Size (Low to High)',
              ],
              (val) {
                if (val != null) {
                  settings.setSortPreference(val);
                  notifier.patch((s) => s.copyWith(sortPreference: val));
                }
              },
            ),
          ],
        ),
        SettingsGroup(
          label: 'Torrent providers',
          children: [
            if (!TorrentSearchCatalog.hasInstalled)
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 12),
                child: Text(
                  'Install the ForjaHQ Torrent pack under Settings → Sources → Forja '
                  '(plugins/torrent/manifest.json) to enable indexer search.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ForjaShellColors.textSecondary,
                      ),
                ),
              )
            else
              for (final id in TorrentSearchProviders.all)
                settingsFocusableToggle(
                  context,
                  TorrentSearchProviders.label(id),
                  id == TorrentSearchProviders.torrentio
                      ? 'IMDb search when available on details.'
                      : 'Include results from this indexer.',
                  snap.enabledProviders.contains(id),
                  (val) async {
                    await settings.setTorrentProviderEnabled(id, val);
                    final next = List<String>.from(snap.enabledProviders);
                    if (val) {
                      if (!next.contains(id)) next.add(id);
                    } else {
                      next.remove(id);
                    }
                    notifier.patch((s) => s.copyWith(enabledProviders: next));
                  },
                ),
          ],
        ),
        SettingsGroup(
          label: 'Torrent engine',
          children: [
            settingsFocusableSlider(
              title: 'Disk cache: ${snap.diskCacheGb} GB',
              subtitle:
                  'Max torrent data kept on disk. Playing now is never deleted; oldest idle downloads are removed when over this size.',
              value: snap.diskCacheGb.toDouble().clamp(
                SettingsService.minTorrentDiskCacheGb.toDouble(),
                SettingsService.maxTorrentDiskCacheGb.toDouble(),
              ),
              min: SettingsService.minTorrentDiskCacheGb.toDouble(),
              max: SettingsService.maxTorrentDiskCacheGb.toDouble(),
              divisions: SettingsService.maxTorrentDiskCacheGb -
                  SettingsService.minTorrentDiskCacheGb,
              label: '${snap.diskCacheGb} GB',
              onChanged: (val) => notifier.patch(
                (s) => s.copyWith(diskCacheGb: val.round()),
              ),
              onChangeEnd: (val) async {
                await TorrentStreamService().applyDiskCacheGb(val.round());
              },
            ),
            settingsFocusableSlider(
              title: 'Connections per torrent: ${snap.connectionsLimit}',
              subtitle:
                  'Lower (5–25) often streams better on high-seed swarms.',
              value: snap.connectionsLimit.toDouble().clamp(5, 200),
              min: 5,
              max: 200,
              divisions: 39,
              label: '${snap.connectionsLimit}',
              onChanged: (val) => notifier.patch(
                (s) => s.copyWith(connectionsLimit: val.round()),
              ),
              onChangeEnd: (val) async {
                await TorrentStreamService().applyConnectionsLimit(
                  val.round(),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
