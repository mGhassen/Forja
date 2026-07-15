import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/anime/catalog/anime_stream_providers.dart';
import 'package:forja/features/settings/widgets/provider_priority_table.dart';
import 'package:forja/features/settings/widgets/settings_focus_controls.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/player/track_auto_select.dart';

/// Playback sources, scoring, and audio prefs.
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
  bool _autoNextEpisode = true;
  bool _autoSkipIntro = false;
  bool _iptvEpgEnabled = true;
  String _maxPlaybackHeightLabel = 'Auto';
  List<String> _streamProviderOrder = [];
  List<String> _animeProviderOrder = [];
  List<String> _asianDramaProviderOrder = List<String>.from(
    _kAsianDramaProviderOrder,
  );

  static const Map<String, String> _kAsianDramaCatalog = {
    'kisskh': 'KissKH',
  };
  static const List<String> _kAsianDramaProviderOrder = ['kisskh'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final playSourceTorrent = await _settings.isPlaySourceTorrentEnabled();
    final playSourceStremio = await _settings.isPlaySourceStremioEnabled();
    final playSourceWebstreaming =
        await _settings.isPlaySourceWebstreamingEnabled();
    final builtInEngine = await _settings.getBuiltInPlayerEngine();
    final streamOrder = await _settings.getStreamProviderOrder();
    final animeOrder = await _settings.getAnimeProviderOrder();
    final preferredAudio = await _settings.getPreferredAudioLanguage();
    final avoidUnsupported = await _settings.getAvoidUnsupportedAudio();
    final autoNextEpisode = await _settings.getAutoNextEpisode();
    final autoSkipIntro = await _settings.getAutoSkipIntro();
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
      _autoNextEpisode = autoNextEpisode;
      _autoSkipIntro = autoSkipIntro;
      _iptvEpgEnabled = iptvEpgEnabled;
      _maxPlaybackHeightLabel =
          SettingsService.maxPlaybackHeightLabel(maxPlaybackHeight);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: 'Play sources',
          children: [
            settingsFocusableToggle(
              context,
              'Direct torrent',
              'Search Forja indexers and Nuvio scrapers in Sources.',
              _playSourceTorrent,
              (val) async {
                await _settings.setPlaySourceTorrentEnabled(val);
                setState(() => _playSourceTorrent = val);
              },
            ),
            settingsFocusableToggle(
              context,
              'Stremio',
              'Play from installed Stremio addon streams.',
              _playSourceStremio,
              (val) async {
                await _settings.setPlaySourceStremioEnabled(val);
                setState(() => _playSourceStremio = val);
              },
            ),
            settingsFocusableToggle(
              context,
              'Webstreaming',
              'Play from web stream extractors (Videasy, WebStreamr, …).',
              _playSourceWebstreaming,
              (val) async {
                await _settings.setPlaySourceWebstreamingEnabled(val);
                setState(() => _playSourceWebstreaming = val);
              },
            ),
          ],
        ),
        _buildProviderScoringSection(),
        SettingsGroup(
          label: 'Player',
          children: [
            if (Platform.isAndroid)
              settingsFocusableDropdown(
                context,
                'Built-in engine',
                'Decoder when Video Player is Built-in.',
                _builtInEngine.displayName,
                builtInPlayerEngineOptions.map((e) => e.displayName).toList(),
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
            settingsFocusableDropdown(
              context,
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
            settingsFocusableToggle(
              context,
              'Avoid unsupported audio (Atmos / TrueHD / 7.1)',
              'Switch to AC-3 / E-AC-3 / AAC when the original track\'s codec or channel layout isn\'t supported.',
              _avoidUnsupportedAudio,
              (val) async {
                await _settings.setAvoidUnsupportedAudio(val);
                setState(() => _avoidUnsupportedAudio = val);
              },
            ),
            settingsFocusableToggle(
              context,
              'Auto next episode',
              'When an episode finishes, start the next one automatically. Also available in the player Episodes panel.',
              _autoNextEpisode,
              (val) async {
                await _settings.setAutoNextEpisode(val);
                setState(() => _autoNextEpisode = val);
              },
            ),
            settingsFocusableToggle(
              context,
              'Auto skip intro',
              'When IntroDB has intro or recap timestamps, skip them without tapping Skip.',
              _autoSkipIntro,
              (val) async {
                await _settings.setAutoSkipIntro(val);
                setState(() => _autoSkipIntro = val);
              },
            ),
            settingsFocusableToggle(
              context,
              'IPTV programme guide (EPG)',
              'Load and show NOW / NEXT programme info in the IPTV player and channel browser.',
              _iptvEpgEnabled,
              (val) async {
                await _settings.setIptvEpgEnabled(val);
                setState(() => _iptvEpgEnabled = val);
              },
            ),
            settingsFocusableDropdown(
              context,
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
          ],
        ),
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
    final asianDramaOrder = SettingsService.mergeProviderOrder(
      _asianDramaProviderOrder,
      _kAsianDramaCatalog.keys,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: ProviderScoringPanel(
        streamCatalog: streamCatalog,
        streamOrder: streamOrder,
        onStreamOrderChanged: (next) async {
          setState(() => _streamProviderOrder = next);
          await _settings.setStreamProviderOrder(next);
        },
        onStreamOrderReset: () async {
          final defaults = List<String>.from(
            SettingsService.defaultStreamProviderOrder,
          );
          await _settings.setStreamProviderOrder(defaults);
          setState(() => _streamProviderOrder = defaults);
        },
        animeCatalog: animeCatalog,
        animeOrder: animeOrder,
        onAnimeOrderChanged: (next) async {
          setState(() => _animeProviderOrder = next);
          await _settings.setAnimeProviderOrder(next);
        },
        onAnimeOrderReset: () async {
          final defaults = List<String>.from(
            SettingsService.defaultAnimeProviderOrder,
          );
          await _settings.setAnimeProviderOrder(defaults);
          setState(() => _animeProviderOrder = defaults);
        },
        asianDramaCatalog: _kAsianDramaCatalog,
        asianDramaOrder: asianDramaOrder,
        onAsianDramaOrderChanged: (next) {
          setState(() => _asianDramaProviderOrder = next);
        },
        onAsianDramaOrderReset: () {
          setState(
            () => _asianDramaProviderOrder = List<String>.from(
              _kAsianDramaProviderOrder,
            ),
          );
        },
      ),
    );
  }
}
