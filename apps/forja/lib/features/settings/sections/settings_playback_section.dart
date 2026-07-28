import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/anime/catalog/anime_stream_providers.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/settings_visibility.dart';
import 'package:forja/features/settings/widgets/provider_priority_table.dart';
import 'package:forja/features/settings/widgets/settings_focus_controls.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/player/track_auto_select.dart';
import 'package:forja/shared/sync/sync.dart';

/// Playback sources, scoring, and audio prefs.
class SettingsPlaybackSection extends ConsumerStatefulWidget {
  const SettingsPlaybackSection({super.key, required this.visibility});

  final SettingsVisibility visibility;

  @override
  ConsumerState<SettingsPlaybackSection> createState() =>
      _SettingsPlaybackSectionState();
}

class _SettingsPlaybackSectionState
    extends ConsumerState<SettingsPlaybackSection> {
  final SettingsService _settings = SettingsService();

  SettingsPlaybackNotifier get _playback =>
      ref.read(settingsPlaybackProvider.notifier);

  @override
  Widget build(BuildContext context) {
    ref.watch(accountFeaturesProvider);
    final async = ref.watch(settingsPlaybackProvider);
    final snap = async.valueOrNull;
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
        if (widget.visibility.showPlaySources)
          SettingsGroup(
            label: 'Play sources',
            children: [
              if (PlatformPlayback.capabilities.playSourceTorrent)
                settingsFocusableToggle(
                  context,
                  'Direct torrent',
                  'Search Forja indexers (Jackett / Prowlarr) in Sources.',
                  snap.playSourceTorrent,
                  (val) async {
                    await _settings.setPlaySourceTorrentEnabled(val);
                    await _playback.patch(
                      (s) => s.copyWith(playSourceTorrent: val),
                    );
                    schedulePreferencesSyncPush();
                    if (val &&
                        PlatformPlayback.capabilities.localTorrentEngine) {
                      debugPrint('[Init] TorrentStream start (settings toggle)');
                      await TorrentStreamService().start();
                    }
                  },
                ),
              if (PlatformPlayback.capabilities.playSourceStremio)
                settingsFocusableToggle(
                  context,
                  'Stremio',
                  'Play from installed Stremio addon streams.',
                  snap.playSourceStremio,
                  (val) async {
                    await _settings.setPlaySourceStremioEnabled(val);
                    await _playback.patch(
                      (s) => s.copyWith(playSourceStremio: val),
                    );
                    schedulePreferencesSyncPush();
                  },
                ),
              if (PlatformPlayback.capabilities.playSourceNuvio)
                settingsFocusableToggle(
                  context,
                  'Nuvio',
                  'Play from installed Nuvio scraper addons in Sources.',
                  snap.playSourceNuvio,
                  (val) async {
                    await _settings.setPlaySourceNuvioEnabled(val);
                    await _playback.patch(
                      (s) => s.copyWith(playSourceNuvio: val),
                    );
                    schedulePreferencesSyncPush();
                    if (val) {
                      debugPrint('[Init] Nuvio refresh (settings toggle)');
                      unawaited(NuvioService.instance.refreshAllInstalled());
                    }
                  },
                ),
              settingsFocusableToggle(
                context,
                'Webstreaming',
                'Play from web stream extractors (Videasy, WebStreamr, …).',
                snap.playSourceWebstreaming,
                (val) async {
                  await _settings.setPlaySourceWebstreamingEnabled(val);
                  await _playback.patch(
                    (s) => s.copyWith(playSourceWebstreaming: val),
                  );
                  schedulePreferencesSyncPush();
                  if (val) {
                    debugPrint('[Init] LocalServer start (settings toggle)');
                    await LocalServerService().start();
                    debugPrint('[Init] WebStreamr start (settings toggle)');
                    await WebStreamrService.init();
                  }
                },
              ),
              if (snap.playSourceWebstreaming &&
                  AccountFeatures.instance.isAdmin)
                settingsFocusableToggle(
                  context,
                  'Simple resolve (experimental)',
                  'One provider at a time: filter streams, probe, then open the player once. Leaves the old race path off.',
                  snap.simpleStreamingResolve,
                  (val) async {
                    await _settings.setSimpleStreamingResolveEnabled(val);
                    await _playback.patch(
                      (s) => s.copyWith(simpleStreamingResolve: val),
                    );
                    schedulePreferencesSyncPush();
                  },
                ),
            ],
          ),
        if (widget.visibility.showProviderScoring)
          _buildProviderScoringSection(snap),
        SettingsGroup(
          label: 'Player',
          children: [
            if (Platform.isAndroid)
              settingsFocusableDropdown(
                context,
                'Built-in engine',
                'Decoder when Video Player is Built-in.',
                snap.builtInEngine.displayName,
                builtInPlayerEngineOptions.map((e) => e.displayName).toList(),
                (val) async {
                  if (val == null) return;
                  final match = builtInPlayerEngineOptions
                      .where((e) => e.displayName == val)
                      .toList();
                  if (match.isEmpty) return;
                  await _settings.setBuiltInPlayerEngine(match.first);
                  await _playback.patch(
                    (s) => s.copyWith(builtInEngine: match.first),
                  );
                },
              ),
            settingsFocusableDropdown(
              context,
              'Preferred Audio Language',
              'When a video starts, automatically switch to a matching audio track. Pick "None" to leave the default.',
              snap.preferredAudioLang,
              kTrackLanguageDisplayNames,
              (val) async {
                if (val != null) {
                  await _settings.setPreferredAudioLanguage(val);
                  await _playback.patch(
                    (s) => s.copyWith(preferredAudioLang: val),
                  );
                  schedulePreferencesSyncPush();
                }
              },
            ),
            settingsFocusableToggle(
              context,
              'Avoid unsupported audio (Atmos / TrueHD / 7.1)',
              'Switch to AC-3 / E-AC-3 / AAC when the original track\'s codec or channel layout isn\'t supported.',
              snap.avoidUnsupportedAudio,
              (val) async {
                await _settings.setAvoidUnsupportedAudio(val);
                await _playback.patch(
                  (s) => s.copyWith(avoidUnsupportedAudio: val),
                );
                schedulePreferencesSyncPush();
              },
            ),
            if (widget.visibility.showVodPlayerExtras) ...[
              settingsFocusableToggle(
                context,
                'Auto next episode',
                'When an episode finishes, start the next one automatically. Also available in the player Episodes panel.',
                snap.autoNextEpisode,
                (val) async {
                  await _settings.setAutoNextEpisode(val);
                  await _playback.patch(
                    (s) => s.copyWith(autoNextEpisode: val),
                  );
                  schedulePreferencesSyncPush();
                },
              ),
              settingsFocusableToggle(
                context,
                'Auto skip intro',
                'When IntroDB has intro or recap timestamps, skip them without tapping Skip.',
                snap.autoSkipIntro,
                (val) async {
                  await _settings.setAutoSkipIntro(val);
                  await _playback.patch((s) => s.copyWith(autoSkipIntro: val));
                  schedulePreferencesSyncPush();
                },
              ),
            ],
            if (widget.visibility.showIptvSettings)
              settingsFocusableToggle(
                context,
                'IPTV programme guide (EPG)',
                'Load and show NOW / NEXT programme info in the IPTV player and channel browser.',
                snap.iptvEpgEnabled,
                (val) async {
                  await _settings.setIptvEpgEnabled(val);
                  await _playback.patch((s) => s.copyWith(iptvEpgEnabled: val));
                  schedulePreferencesSyncPush();
                },
              ),
            if (widget.visibility.showPlaySources)
              settingsFocusableDropdown(
                context,
                'Max stream quality',
                'Cap automatic stream selection. Auto uses the best your device supports.',
                snap.maxPlaybackHeightLabel,
                SettingsService.maxPlaybackHeightOptions.keys.toList(),
                (val) async {
                  if (val == null) return;
                  final height =
                      SettingsService.maxPlaybackHeightOptions[val] ?? 0;
                  await _settings.setMaxPlaybackHeight(height);
                  await _playback.patch(
                    (s) => s.copyWith(maxPlaybackHeightLabel: val),
                  );
                  schedulePreferencesSyncPush();
                },
              ),
            if (widget.visibility.showVodPlayerExtras)
              settingsFocusableDropdown(
                context,
                'Anime title language',
                'How anime titles appear in the Anime hub, details, and player. Default Romaji. Stream matching always tries romaji first, then English, native, and AniList synonyms.',
                snap.animeTitleLanguageLabel,
                SettingsService.animeTitleLanguageOptions,
                (val) async {
                  if (val == null) return;
                  await _settings.setAnimeTitleLanguage(
                    SettingsService.animeTitleLanguageStored(val),
                  );
                  await _playback.patch(
                    (s) => s.copyWith(animeTitleLanguageLabel: val),
                  );
                  schedulePreferencesSyncPush();
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildProviderScoringSection(SettingsPlaybackSnapshot snap) {
    final streamCatalog = <String, String>{
      for (final entry in StreamProviders.providers.entries)
        entry.key: (entry.value['name'] as String?) ?? entry.key,
    };
    final streamOrder = <String>[
      ...snap.streamProviderOrder.where(streamCatalog.containsKey),
      ...streamCatalog.keys
          .where((k) => !snap.streamProviderOrder.contains(k)),
    ];
    final animeCatalog = AnimeStreamProviders.catalog;
    final animeOrder = SettingsService.mergeProviderOrder(
      snap.animeProviderOrder,
      animeCatalog.keys,
    );
    final asianDramaCatalog = KissKhService.settingsCatalog;
    final asianDramaOrder = <String>[
      KissKhService.activeMirrorHost,
      ...asianDramaCatalog.keys.where(
        (host) => host != KissKhService.activeMirrorHost,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: ProviderScoringPanel(
        streamCatalog: streamCatalog,
        streamOrder: streamOrder,
        onStreamOrderChanged: (next) async {
          await _playback.patch((s) => s.copyWith(streamProviderOrder: next));
          await _settings.setStreamProviderOrder(next);
          scheduleProvidersSyncPush();
        },
        onStreamOrderReset: () async {
          final defaults = List<String>.from(
            SettingsService.defaultStreamProviderOrder,
          );
          await _settings.setStreamProviderOrder(defaults);
          await _playback.patch(
            (s) => s.copyWith(streamProviderOrder: defaults),
          );
          scheduleProvidersSyncPush();
        },
        animeCatalog: animeCatalog,
        animeOrder: animeOrder,
        onAnimeOrderChanged: (next) async {
          await _playback.patch((s) => s.copyWith(animeProviderOrder: next));
          await _settings.setAnimeProviderOrder(next);
          scheduleProvidersSyncPush();
        },
        onAnimeOrderReset: () async {
          final defaults = List<String>.from(
            SettingsService.defaultAnimeProviderOrder,
          );
          await _settings.setAnimeProviderOrder(defaults);
          await _playback.patch(
            (s) => s.copyWith(animeProviderOrder: defaults),
          );
          scheduleProvidersSyncPush();
        },
        asianDramaCatalog: asianDramaCatalog,
        asianDramaOrder: asianDramaOrder,
        disabledAsianDramaProviders: KissKhService.disabledMirrorHosts,
        onAsianDramaOrderChanged: (_) {},
        onAsianDramaOrderReset: () {},
      ),
    );
  }
}
