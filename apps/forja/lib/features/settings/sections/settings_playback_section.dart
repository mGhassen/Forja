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
                'Used for Home, Search, Anime, Asian Drama, and IPTV Movies/Series. Live IPTV has its own setting under IPTV.',
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
              'Switch to a matching audio track when playback starts. Pick "None" to keep the stream default.',
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
              'Prefer this language for in-stream or online subtitles. In-stream tracks win when they match. Pick "None" to start with subs off.',
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
              'Fall back to AC-3, E-AC-3, or AAC when Atmos, TrueHD, or 7.1 is not supported.',
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
                'Start the next episode when one ends. Also available in the player Episodes panel.',
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
              'Skip intro and recap segments automatically when timestamps are available.',
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
              'Show IMDb content ratings (nudity, violence, and similar) when playback starts.',
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
                    ? 'Keep movies, series, and IPTV playing when Forja is in the background. On by default on desktop.'
                    : 'Keep movies, series, and IPTV playing when Forja is in the background. Off by default (playback pauses until you return).',
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
                'Enter picture-in-picture when you switch Space (macOS) or virtual desktop (Windows) while playing. You can still use the player PiP button anytime.',
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
                'Limit Auto stream quality and HLS start bitrate. Auto aims for a faster first frame. Pick 4K for the highest ladder.',
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
                'Title language in the Anime hub, details, and player. Default is Romaji. Stream matching still tries romaji, then English, native, and synonyms.',
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
