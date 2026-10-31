import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/settings/ui/focus_controls.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/l10n/l10n.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

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
          label: context.l10n.addonsHostTorrentSearchGroupLabel,
          children: [
            if (!TorrentSearchCatalog.hasInstalled)
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 12),
                child: Text(
                  context.l10n.addonsHostTorrentInstallPackHint,
                  style: TextStyle(
                    color: ForjaShellColors.textSecondary,
                    fontSize: SettingsTokens.rowSubtitleSizeOf(context),
                    height: 1.35,
                  ),
                ),
              ),
            settingsFocusableDropdown(
              context,
              context.l10n.addonsHostTorrentSortTitle,
              context.l10n.addonsHostTorrentSortSubtitle,
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
                context.l10n.addonsHostTorrentFlareSolverrNote,
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: SettingsTokens.rowSubtitleSizeOf(context),
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        SettingsGroup(
          label: context.l10n.addonsHostTorrentEngineGroupLabel,
          children: [
            settingsFocusableSlider(
              title: context.l10n.addonsHostTorrentDiskCacheTitle(
                snap.diskCacheGb,
              ),
              subtitle: context.l10n.addonsHostTorrentDiskCacheSubtitle,
              value: snap.diskCacheGb.toDouble().clamp(
                SettingsService.minTorrentDiskCacheGb.toDouble(),
                SettingsService.maxTorrentDiskCacheGb.toDouble(),
              ),
              min: SettingsService.minTorrentDiskCacheGb.toDouble(),
              max: SettingsService.maxTorrentDiskCacheGb.toDouble(),
              divisions: SettingsService.maxTorrentDiskCacheGb -
                  SettingsService.minTorrentDiskCacheGb,
              label: context.l10n.addonsHostTorrentGbLabel(snap.diskCacheGb),
              onChanged: (val) => notifier.patch(
                (s) => s.copyWith(diskCacheGb: val.round()),
              ),
              onChangeEnd: (val) async {
                await TorrentStreamService().applyDiskCacheGb(val.round());
              },
            ),
            settingsFocusableSlider(
              title: context.l10n.addonsHostTorrentConnectionsTitle(
                snap.connectionsLimit,
              ),
              subtitle: context.l10n.addonsHostTorrentConnectionsSubtitle,
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
