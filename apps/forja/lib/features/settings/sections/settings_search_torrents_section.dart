import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/shared/design/design.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/settings/widgets/settings_focus_controls.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';

/// Torrent engine and sort order settings.
class SettingsSearchTorrentsSection extends ConsumerStatefulWidget {
  const SettingsSearchTorrentsSection({super.key});

  @override
  ConsumerState<SettingsSearchTorrentsSection> createState() =>
      _SettingsSearchTorrentsSectionState();
}

class _SettingsSearchTorrentsSectionState
    extends ConsumerState<SettingsSearchTorrentsSection> {
  final _flareSolverrController = TextEditingController();

  @override
  void dispose() {
    _flareSolverrController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    if (_flareSolverrController.text != snap.flareSolverrUrl) {
      _flareSolverrController.text = snap.flareSolverrUrl;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: 'Torrent search',
          children: [
            if (!TorrentSearchCatalog.hasInstalled)
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 12),
                child: Text(
                  'Install the ForjaHQ Torrent pack under Settings → Forja Packs '
                  'and enable indexers per plugin.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ForjaShellColors.textSecondary,
                      ),
                ),
              ),
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
            const SizedBox(height: 16),
            SettingsTextField(
              controller: _flareSolverrController,
              label: 'FlareSolverr / Byparr URL',
              hint: 'http://127.0.0.1:8191',
              onSubmitted: (val) async {
                await settings.setFlareSolverrUrl(val);
                notifier.patch((s) => s.copyWith(flareSolverrUrl: val.trim()));
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
              child: Text(
                'UIndex is Cloudflare-protected. Point this at a local FlareSolverr '
                'or Byparr instance (same /v1 API) — same setup as Prowlarr indexers.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ForjaShellColors.textSecondary,
                    ),
              ),
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
