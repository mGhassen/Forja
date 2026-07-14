import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/settings/webstreamr_settings_screen.dart';
import 'package:forja/features/settings/widgets/settings_focus_controls.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';

/// Torrent engine, sort order, and WebStreamr local settings.
class SettingsSearchTorrentsSection extends StatefulWidget {
  const SettingsSearchTorrentsSection({super.key});

  @override
  State<SettingsSearchTorrentsSection> createState() =>
      _SettingsSearchTorrentsSectionState();
}

class _SettingsSearchTorrentsSectionState
    extends State<SettingsSearchTorrentsSection> {
  final SettingsService _settings = SettingsService();

  String _sortPreference = 'Seeders (High to Low)';
  String _torrentCacheType = 'ram';
  int _torrentRamCacheMb = 200;
  int _torrentConnectionsLimit = 25;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sort = await _settings.getSortPreference();
    final cacheType = await _settings.getTorrentCacheType();
    final ramCacheMb = await _settings.getTorrentRamCacheMb();
    final connLimit = await _settings.getTorrentConnectionsLimit();
    if (!mounted) return;
    setState(() {
      _sortPreference = sort;
      _torrentCacheType = cacheType;
      _torrentRamCacheMb = ramCacheMb;
      _torrentConnectionsLimit = connLimit;
    });
  }

  @override
  Widget build(BuildContext context) {
    final torrent = PlatformPlayback.capabilities.builtinTorrentSearch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (torrent) ...[
          SettingsGroup(
            label: 'Torrent search',
            children: [
              settingsFocusableDropdown(
                context,
                'Default Sort Order',
                'How torrent results are sorted automatically.',
                _sortPreference,
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
                    _settings.setSortPreference(val);
                    setState(() => _sortPreference = val);
                  }
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
                _torrentCacheType == 'ram' ? 'RAM' : 'Disk',
                const ['RAM', 'Disk'],
                (val) async {
                  if (val != null) {
                    final type = val == 'RAM' ? 'ram' : 'disk';
                    await _settings.setTorrentCacheType(type);
                    setState(() => _torrentCacheType = type);
                  }
                },
              ),
              if (_torrentCacheType == 'ram')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RAM Cache Size: $_torrentRamCacheMb MB',
                        style: const TextStyle(
                          color: ForjaShellColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      Slider(
                        value: _torrentRamCacheMb.toDouble(),
                        min: 50,
                        max: 2048,
                        divisions: 39,
                        activeColor: ForjaShellColors.brandGreen,
                        inactiveColor: ForjaShellColors.borderSubtle,
                        label: '$_torrentRamCacheMb MB',
                        onChanged: (val) => setState(
                          () => _torrentRamCacheMb = val.round(),
                        ),
                        onChangeEnd: (val) async =>
                            await _settings.setTorrentRamCacheMb(val.round()),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connections per torrent: $_torrentConnectionsLimit',
                      style: const TextStyle(
                        color: ForjaShellColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Lower (5–25) often streams better on high-seed swarms.',
                      style: TextStyle(
                        color: ForjaShellColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    Slider(
                      value: _torrentConnectionsLimit.toDouble().clamp(5, 200),
                      min: 5,
                      max: 200,
                      divisions: 39,
                      activeColor: ForjaShellColors.brandGreen,
                      inactiveColor: ForjaShellColors.borderSubtle,
                      label: '$_torrentConnectionsLimit',
                      onChanged: (val) => setState(
                        () => _torrentConnectionsLimit = val.round(),
                      ),
                      onChangeEnd: (val) async {
                        await TorrentStreamService()
                            .applyConnectionsLimit(val.round());
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        SettingsGroup(
          label: 'WebStreamr',
          children: [
            SettingsActionRow(
              leading: const Icon(
                Icons.language_rounded,
                color: ForjaShellColors.iconActive,
              ),
              title: 'WebStreamr Settings',
              subtitle: 'Country toggles, MFP, FlareSolverr, TMDB token',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WebStreamrSettingsScreen(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
