import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/anime/catalog/anime_stream_providers.dart';
import 'package:forja/features/settings/widgets/provider_priority_table.dart';
import 'package:forja/features/settings/widgets/settings_expandable_section.dart';
import 'package:forja/features/settings/widgets/settings_focus_controls.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/playback/playback_cache_service.dart';
import 'package:forja/shared/player/track_auto_select.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// Playback sources, scoring, audio prefs, and cache reset.
class SettingsPlaybackSection extends StatefulWidget {
  const SettingsPlaybackSection({super.key});

  @override
  State<SettingsPlaybackSection> createState() => _SettingsPlaybackSectionState();
}

class _SettingsPlaybackSectionState extends State<SettingsPlaybackSection> {
  final SettingsService _settings = SettingsService();

  bool _playSourceTorrent = true;
  bool _playSourceStremio = true;
  bool _playSourceWebstreaming = true;
  BuiltInPlayerEngine _builtInEngine = BuiltInPlayerEngine.platformDefault();
  String _preferredAudioLang = 'None';
  bool _avoidUnsupportedAudio = true;
  bool _iptvEpgEnabled = true;
  String _maxPlaybackHeightLabel = 'Auto';
  List<String> _streamProviderOrder = [];
  List<String> _animeProviderOrder = [];
  bool _isClearingPlaybackCache = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final playSourceTorrent = await _settings.isPlaySourceTorrentEnabled();
    final playSourceStremio = await _settings.isPlaySourceStremioEnabled();
    final playSourceWebstreaming = await _settings.isPlaySourceWebstreamingEnabled();
    final builtInEngine = await _settings.getBuiltInPlayerEngine();
    final streamOrder = await _settings.getStreamProviderOrder();
    final animeOrder = await _settings.getAnimeProviderOrder();
    final preferredAudio = await _settings.getPreferredAudioLanguage();
    final avoidUnsupported = await _settings.getAvoidUnsupportedAudio();
    final iptvEpgEnabled = await _settings.isIptvEpgEnabled();
    SettingsService.iptvEpgEnabledNotifier.value = iptvEpgEnabled;
    final maxPlaybackHeight = await _settings.getMaxPlaybackHeight();
    if (!mounted) return;
    setState(() {
      _playSourceTorrent = playSourceTorrent;
      _playSourceStremio = playSourceStremio;
      _playSourceWebstreaming = playSourceWebstreaming;
      _builtInEngine = builtInEngine;
      _streamProviderOrder = streamOrder;
      _animeProviderOrder = animeOrder;
      _preferredAudioLang = kTrackLanguageDisplayNames.contains(preferredAudio)
          ? preferredAudio
          : 'None';
      _avoidUnsupportedAudio = avoidUnsupported;
      _iptvEpgEnabled = iptvEpgEnabled;
      _maxPlaybackHeightLabel = SettingsService.maxPlaybackHeightLabel(maxPlaybackHeight);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsExpandableSection(
      id: 'playback',
      icon: Icons.play_circle_outline_rounded,
      title: 'Playback',
      children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'PLAY SOURCES',
                      style: TextStyle(
                        color: AppTheme.current.primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  settingsFocusableToggle(context, 
                    'Direct torrent',
                    'Search Forja indexers and Nuvio scrapers in Sources.',
                    _playSourceTorrent,
                    (val) async {
                      await _settings.setPlaySourceTorrentEnabled(val);
                      setState(() => _playSourceTorrent = val);
                    },
                  ),
                  settingsFocusableToggle(context, 
                    'Stremio',
                    'Play from installed Stremio addon streams.',
                    _playSourceStremio,
                    (val) async {
                      await _settings.setPlaySourceStremioEnabled(val);
                      setState(() => _playSourceStremio = val);
                    },
                  ),
                  settingsFocusableToggle(context, 
                    'Webstreaming',
                    'Play from web stream extractors (Videasy, WebStreamr, …).',
                    _playSourceWebstreaming,
                    (val) async {
                      await _settings.setPlaySourceWebstreamingEnabled(val);
                      setState(() => _playSourceWebstreaming = val);
                    },
                  ),
                  _buildProviderScoringSection(),
                  if (Platform.isAndroid)
                    settingsFocusableDropdown(context, 
                      'Built-in engine',
                      'Decoder when Video Player is Built-in.',
                      _builtInEngine.displayName,
                      builtInPlayerEngineOptions
                          .map((e) => e.displayName)
                          .toList(),
                      (val) async {
                        if (val == null) return;
                        final match = builtInPlayerEngineOptions
                            .where((e) => e.displayName == val)
                            .toList();
                        if (match.isEmpty) return;
                        await _settings.setBuiltInPlayerEngine(match.first);
                        setState(() => _builtInEngine = match.first);
                      },
                    ),
                  settingsFocusableDropdown(context, 
                    'Preferred Audio Language',
                    'When a video starts, automatically switch to a matching audio track. Pick "None" to leave the default.',
                    _preferredAudioLang,
                    kTrackLanguageDisplayNames,
                    (val) async {
                      if (val != null) {
                        await _settings.setPreferredAudioLanguage(val);
                        setState(() => _preferredAudioLang = val);
                      }
                    },
                  ),
                  settingsFocusableToggle(context, 
                    'Avoid unsupported audio (Atmos / TrueHD / 7.1)',
                    'Switch to AC-3 / E-AC-3 / AAC when the original track\'s codec or channel layout isn\'t supported.',
                    _avoidUnsupportedAudio,
                    (val) async {
                      await _settings.setAvoidUnsupportedAudio(val);
                      setState(() => _avoidUnsupportedAudio = val);
                    },
                  ),
                  settingsFocusableToggle(context, 
                    'IPTV programme guide (EPG)',
                    'Load and show NOW / NEXT programme info in the IPTV player and channel browser.',
                    _iptvEpgEnabled,
                    (val) async {
                      await _settings.setIptvEpgEnabled(val);
                      setState(() => _iptvEpgEnabled = val);
                    },
                  ),
                  settingsFocusableDropdown(context, 
                    'Max stream quality',
                    'Cap automatic stream selection. Auto uses the best your device supports.',
                    _maxPlaybackHeightLabel,
                    SettingsService.maxPlaybackHeightOptions.keys.toList(),
                    (val) async {
                      if (val == null) return;
                      final height =
                          SettingsService.maxPlaybackHeightOptions[val] ?? 0;
                      await _settings.setMaxPlaybackHeight(height);
                      setState(() => _maxPlaybackHeightLabel = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'CACHE',
                      style: TextStyle(
                        color: AppTheme.current.primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildResetPlaybackCacheTile(),
      ],
    );
  }

  Widget _buildProviderScoringSection() {
    final streamCatalog = <String, String>{
      for (final entry in StreamProviders.providers.entries)
        entry.key: (entry.value['name'] as String?) ?? entry.key,
    };
    final streamOrder = <String>[
      ..._streamProviderOrder.where(streamCatalog.containsKey),
      ...streamCatalog.keys.where((k) => !_streamProviderOrder.contains(k)),
    ];
    final animeCatalog = AnimeStreamProviders.catalog;
    final animeOrder = SettingsService.mergeProviderOrder(
      _animeProviderOrder,
      animeCatalog.keys,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Source scoring',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Drag to set baseline order. Domain scores may adjust each provider '
            'by up to ±2 positions before checking. Stream quality is scored '
            'after resolve.',
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 16),
          ProviderPriorityTable(
            domain: SourceDomain.movies,
            title: 'Films',
            subtitle: 'Webstreaming providers for movies.',
            catalog: streamCatalog,
            order: streamOrder,
            onOrderChanged: (next) async {
              setState(() => _streamProviderOrder = next);
              await _settings.setStreamProviderOrder(next);
            },
            onReset: () async {
              final defaults = List<String>.from(
                SettingsService.defaultStreamProviderOrder,
              );
              await _settings.setStreamProviderOrder(defaults);
              setState(() => _streamProviderOrder = defaults);
            },
          ),
          const SizedBox(height: 20),
          ProviderPriorityTable(
            domain: SourceDomain.series,
            title: 'Series',
            subtitle:
                'Same baseline list as films; series domain scores differ.',
            catalog: streamCatalog,
            order: streamOrder,
            onOrderChanged: (next) async {
              setState(() => _streamProviderOrder = next);
              await _settings.setStreamProviderOrder(next);
            },
            onReset: () async {
              final defaults = List<String>.from(
                SettingsService.defaultStreamProviderOrder,
              );
              await _settings.setStreamProviderOrder(defaults);
              setState(() => _streamProviderOrder = defaults);
            },
          ),
          const SizedBox(height: 20),
          ProviderPriorityTable(
            domain: SourceDomain.anime,
            title: 'Anime',
            subtitle: 'Anime player source baseline and effective order.',
            catalog: animeCatalog,
            order: animeOrder,
            onOrderChanged: (next) async {
              setState(() => _animeProviderOrder = next);
              await _settings.setAnimeProviderOrder(next);
            },
            onReset: () async {
              final defaults = List<String>.from(
                SettingsService.defaultAnimeProviderOrder,
              );
              await _settings.setAnimeProviderOrder(defaults);
              setState(() => _animeProviderOrder = defaults);
            },
          ),
          const SizedBox(height: 20),
          ProviderPriorityTable(
            domain: SourceDomain.asianDrama,
            title: 'Asian Drama',
            subtitle:
                'Single KissKH source today — same pipeline as other types.',
            catalog: const {'kisskh': 'KissKH'},
            order: const ['kisskh'],
            onOrderChanged: (_) {},
            onReset: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildResetPlaybackCacheTile() {
    return shellFocusableTap(
      context: context,
      onTap: _isClearingPlaybackCache ? null : _resetPlaybackCache,
      scaleOnFocus: 1.0,
      navLeftAlways: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.cached_rounded, color: Colors.orangeAccent),
          title: const Text('Reset playback cache'),
          subtitle: const Text(
            'Clears saved webstreaming extracts and torrent stream data. Watch history is kept.',
          ),
          trailing: _isClearingPlaybackCache
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

  Future<void> _resetPlaybackCache() async {
    if (_isClearingPlaybackCache) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text(
          'Reset playback cache',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Clears saved webstreaming stream URLs and torrent download cache on this device. '
          'Your watch history and settings are not affected.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _isClearingPlaybackCache = true);
    try {
      await PlaybackCacheService.clearAll();
      if (mounted) {
        ForjaToast.success('Playback cache cleared');
      }
    } catch (e) {
      if (mounted) {
        ForjaToast.error('Failed to clear cache: $e');
      }
    } finally {
      if (mounted) setState(() => _isClearingPlaybackCache = false);
    }
  }
}
