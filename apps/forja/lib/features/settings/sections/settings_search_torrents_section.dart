import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
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
            settingsFocusableDropdown(
              context,
              'Cache Type',
              'Where torrent data is cached during streaming.',
              snap.cacheType == 'ram' ? 'RAM' : 'Disk',
              const ['RAM', 'Disk'],
              (val) async {
                if (val != null) {
                  final type = val == 'RAM' ? 'ram' : 'disk';
                  await settings.setTorrentCacheType(type);
                  notifier.patch((s) => s.copyWith(cacheType: type));
                }
              },
            ),
            if (snap.cacheType == 'ram')
              settingsFocusableSlider(
                title: 'RAM Cache Size: ${snap.ramCacheMb} MB',
                value: snap.ramCacheMb.toDouble(),
                min: 50,
                max: 2048,
                divisions: 39,
                label: '${snap.ramCacheMb} MB',
                onChanged: (val) => notifier.patch(
                  (s) => s.copyWith(ramCacheMb: val.round()),
                ),
                onChangeEnd: (val) async =>
                    await settings.setTorrentRamCacheMb(val.round()),
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
