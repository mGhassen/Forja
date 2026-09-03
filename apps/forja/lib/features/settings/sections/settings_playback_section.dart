import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/providers/settings_visibility_provider.dart';
import 'package:forja/features/settings/settings_visibility.dart';
import 'package:forja/features/settings/widgets/settings_focus_controls.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/player/track_auto_select.dart';
import 'package:forja/shared/sync/sync.dart';

/// Playback sources and player prefs.
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
  void initState() {
    super.initState();
    // Re-check desktop /health so offline→online restores LAN play sources.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshLanPlaySourceGates());
    });
  }

  Future<void> _refreshLanPlaySourceGates() async {
    final caps = PlatformPlayback.capabilities;
    if (caps.playSourceTorrent ||
        caps.playSourceStremio ||
        caps.playSourceNuvio) {
      return;
    }
    SettingsService.playSourceChangeNotifier.value++;
    ref.invalidate(settingsVisibilityProvider);
    await _playback.reload();
  }

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
        SettingsGroup(
          label: 'Player',
          children: [
            if (Platform.isAndroid)
              settingsFocusableDropdown(
                context,
                'Movies & series engine',
                'Home, Search, Anime, Asian Drama, and IPTV Movies/Series. Live IPTV has its own row under IPTV settings.',
                snap.builtInEngine.displayName,
                builtInPlayerEngineOptionsForUi
                    .map((e) => e.displayName)
                    .toList(),
                (val) async {
                  if (val == null) return;
                  final match = builtInPlayerEngineOptionsForUi
                      .where((e) => e.displayName == val)
                      .toList();
                  if (match.isEmpty) return;
                  await _settings.setBuiltInPlayerEngine(
                    match.first,
                    context: BuiltInPlayerContext.vod,
                  );
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
            settingsFocusableDropdown(
              context,
              'Preferred Subtitle Language',
              'When a video starts, pick in-stream or online subtitles in this language. In-stream mux tracks win when they match. Pick "None" to start with subs off.',
              snap.preferredSubtitleLang,
              kTrackLanguageDisplayNames,
              (val) async {
                if (val != null) {
                  await _settings.setPreferredSubtitleLanguage(val);
                  await _playback.patch(
                    (s) => s.copyWith(preferredSubtitleLang: val),
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
            settingsFocusableToggle(
              context,
              'Content warnings',
              'Show nudity, violence, and other IMDb parents-guide ratings when a movie or episode starts.',
              snap.contentWarnings,
              (val) async {
                await _settings.setContentWarnings(val);
                await _playback.patch((s) => s.copyWith(contentWarnings: val));
                schedulePreferencesSyncPush();
              },
            ),
            ],
            // Android TV always pauses on Home/app switch (device-local; not synced).
            if (SettingsService.platformProfile != PlatformProfile.androidTv)
              settingsFocusableToggle(
                context,
                'Play in background',
                SettingsService.platformProfile == PlatformProfile.desktop
                    ? 'Keep movies, series, and IPTV playing when Forja leaves the foreground. On by default on desktop — turn off to pause until you return.'
                    : 'Keep movies, series, and IPTV playing when Forja leaves the foreground. Off by default — playback pauses until you return (app stays in memory for a quick resume).',
                snap.playInBackground,
                (val) async {
                  await _settings.setPlayInBackground(val);
                  await _playback.patch(
                    (s) => s.copyWith(playInBackground: val),
                  );
                },
              ),
            if (!kIsWeb && (Platform.isMacOS || Platform.isWindows))
              settingsFocusableToggle(
                context,
                'Auto picture-in-picture',
                'On Space (macOS) or virtual-desktop (Windows) switch while playing, shrink into PiP automatically. Off by default — use the player PiP button anytime.',
                snap.autoPipOnDesktopSwitch,
                (val) async {
                  await _settings.setAutoPipOnDesktopSwitch(val);
                  await _playback.patch(
                    (s) => s.copyWith(autoPipOnDesktopSwitch: val),
                  );
                  schedulePreferencesSyncPush();
                },
              ),
            if (widget.visibility.vodTab)
              settingsFocusableDropdown(
                context,
                'Max stream quality',
                'Cap Auto stream ranking and HLS start bitrate. Auto uses a mid-high soft ceiling for a faster first frame; pick 4K for the top ladder rung.',
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
}
