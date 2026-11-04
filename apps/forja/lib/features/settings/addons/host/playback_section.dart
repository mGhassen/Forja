import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/shell/visibility_provider.dart';
import 'package:forja/features/settings/shell/visibility.dart';
import 'package:forja/features/settings/ui/focus_controls.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/l10n/l10n.dart';
import 'package:forja/shared/player/resolvers/track_auto_select.dart';
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
          label: context.l10n.addonsHostPlayerGroupLabel,
          children: [
            if (Platform.isAndroid)
              settingsFocusableDropdown(
                context,
                context.l10n.addonsHostPlaybackEngineTitle,
                context.l10n.addonsHostPlaybackEngineSubtitle,
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
              context.l10n.addonsHostPlaybackAudioLangTitle,
              context.l10n.addonsHostPlaybackAudioLangSubtitle,
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
              context.l10n.addonsHostPlaybackSubtitleLangTitle,
              context.l10n.addonsHostPlaybackSubtitleLangSubtitle,
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
              context.l10n.addonsHostPlaybackAvoidAudioTitle,
              context.l10n.addonsHostPlaybackAvoidAudioSubtitle,
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
                context.l10n.addonsHostPlaybackAutoNextTitle,
                context.l10n.addonsHostPlaybackAutoNextSubtitle,
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
              context.l10n.addonsHostPlaybackAutoSkipIntroTitle,
              context.l10n.addonsHostPlaybackAutoSkipIntroSubtitle,
              snap.autoSkipIntro,
              (val) async {
                await _settings.setAutoSkipIntro(val);
                await _playback.patch((s) => s.copyWith(autoSkipIntro: val));
                schedulePreferencesSyncPush();
              },
            ),
            settingsFocusableToggle(
              context,
              context.l10n.addonsHostPlaybackContentWarningsTitle,
              context.l10n.addonsHostPlaybackContentWarningsSubtitle,
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
                context.l10n.addonsHostPlaybackBackgroundTitle,
                SettingsService.platformProfile == PlatformProfile.desktop
                    ? context.l10n.addonsHostPlaybackBackgroundDesktopSubtitle
                    : context.l10n.addonsHostPlaybackBackgroundMobileSubtitle,
                snap.playInBackground,
                (val) async {
                  await _settings.setPlayInBackground(val);
                  await _playback.patch(
                    (s) => s.copyWith(playInBackground: val),
                  );
                },
              ),
            if (SettingsService.platformProfile == PlatformProfile.androidTv)
              settingsFocusableToggle(
                context,
                context.l10n.addonsHostPlaybackRemoteSoundsTitle,
                context.l10n.addonsHostPlaybackRemoteSoundsSubtitle,
                snap.tvNavSound,
                (val) async {
                  await _settings.setTvNavSound(val);
                  await _playback.patch((s) => s.copyWith(tvNavSound: val));
                },
              ),
            if (!kIsWeb &&
                SettingsService.platformProfile == PlatformProfile.desktop)
              settingsFocusableToggle(
                context,
                context.l10n.addonsHostPlaybackAutoPipTitle,
                context.l10n.addonsHostPlaybackAutoPipSubtitle,
                snap.autoPipOnDesktopSwitch,
                (val) async {
                  await _settings.setAutoPipOnDesktopSwitch(val);
                  await _playback.patch(
                    (s) => s.copyWith(autoPipOnDesktopSwitch: val),
                  );
                  schedulePreferencesSyncPush();
                },
              ),
            // Desktop-only (RFC-083). Hidden on Android TV / phone.
            if (!kIsWeb &&
                SettingsService.platformProfile == PlatformProfile.desktop)
              settingsFocusableToggle(
                context,
                context.l10n.addonsHostPlaybackMiniPlayerTitle,
                context.l10n.addonsHostPlaybackMiniPlayerSubtitle,
                snap.inAppMiniPlayer,
                (val) async {
                  await _settings.setInAppMiniPlayer(val);
                  await _playback.patch(
                    (s) => s.copyWith(inAppMiniPlayer: val),
                  );
                  schedulePreferencesSyncPush();
                },
              ),
            if (widget.visibility.vodTab)
              settingsFocusableDropdown(
                context,
                context.l10n.addonsHostPlaybackMaxQualityTitle,
                context.l10n.addonsHostPlaybackMaxQualitySubtitle,
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
          ],
        ),
      ],
    );
  }
}
