import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/settings/webstreamr_settings_screen.dart';
import 'package:forja/features/settings/widgets/settings_expandable_section.dart';
import 'package:forja/features/settings/widgets/settings_focus_controls.dart';
import 'package:forja/shared/theme/app_theme.dart';

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
    return SettingsExpandableSection(
      id: 'search',
      icon: Icons.search_rounded,
      title: PlatformPlayback.capabilities.builtinTorrentSearch
          ? 'Search & Torrents'
          : 'Stream Extractors',
      children: [
                  if (PlatformPlayback.capabilities.builtinTorrentSearch) ...[
                    settingsFocusableDropdown(context, 
                      'Default Sort Order',
                      'How torrent results are sorted automatically.',
                      _sortPreference,
                      [
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
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'TORRENT ENGINE',
                        style: TextStyle(
                          color: AppTheme.current.primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    settingsFocusableDropdown(context, 
                      'Cache Type',
                      'Where torrent data is cached during streaming.',
                      _torrentCacheType == 'ram' ? 'RAM' : 'Disk',
                      ['RAM', 'Disk'],
                      (val) async {
                        if (val != null) {
                          final type = val == 'RAM' ? 'ram' : 'disk';
                          await _settings.setTorrentCacheType(type);
                          setState(() => _torrentCacheType = type);
                        }
                      },
                    ),
                    if (_torrentCacheType == 'ram')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 4,
                              top: 8,
                              bottom: 4,
                            ),
                            child: Text(
                              'RAM Cache Size: $_torrentRamCacheMb MB',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Slider(
                            value: _torrentRamCacheMb.toDouble(),
                            min: 50,
                            max: 2048,
                            divisions: 39,
                            activeColor: Colors.deepPurpleAccent,
                            inactiveColor: Colors.white12,
                            label: '$_torrentRamCacheMb MB',
                            onChanged: (val) => setState(
                              () => _torrentRamCacheMb = val.round(),
                            ),
                            onChangeEnd: (val) async => await _settings
                                .setTorrentRamCacheMb(val.round()),
                          ),
                        ],
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 4,
                            top: 8,
                            bottom: 0,
                          ),
                          child: Text(
                            'Connections per torrent: $_torrentConnectionsLimit',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 4),
                          child: Text(
                            'Lower (5–25) often streams better on high-seed swarms.',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Slider(
                          value: _torrentConnectionsLimit.toDouble().clamp(
                            5,
                            200,
                          ),
                          min: 5,
                          max: 200,
                          divisions: 39,
                          activeColor: Colors.deepPurpleAccent,
                          inactiveColor: Colors.white12,
                          label: '$_torrentConnectionsLimit',
                          onChanged: (val) => setState(
                            () => _torrentConnectionsLimit = val.round(),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'WEBSTREAMR (LOCAL)',
                      style: TextStyle(
                        color: AppTheme.current.primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.language),
                      title: const Text('WebStreamr Settings'),
                      subtitle: const Text(
                        'Country toggles, MFP, FlareSolverr, TMDB token',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const WebStreamrSettingsScreen(),
                        ),
                      ),
                    ),
                  ),
      ],
    );
  }
}
