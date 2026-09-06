import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/widgets/settings_focus_controls.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:rust/rust.dart';

/// IPTV player prefs that used to live under Settings → Playback.
class SettingsIptvPlayerPrefs extends ConsumerWidget {
  const SettingsIptvPlayerPrefs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(accountFeaturesProvider);
    final snap = ref.watch(settingsPlaybackProvider).valueOrNull;
    if (snap == null) return const SizedBox.shrink();

    final settings = SettingsService();
    final playback = ref.read(settingsPlaybackProvider.notifier);

    return SettingsGroup(
      label: 'Player',
      children: [
        if (Platform.isAndroid)
          settingsFocusableDropdown(
            context,
            'IPTV engine',
            'Live channels only. Does not change Movies & series or Live Matches.',
            snap.builtInEngineIptv.displayName,
            builtInPlayerEngineOptionsForUi.map((e) => e.displayName).toList(),
            (val) async {
              if (val == null) return;
              final match = builtInPlayerEngineOptionsForUi
                  .where((e) => e.displayName == val)
                  .toList();
              if (match.isEmpty) return;
              await settings.setBuiltInPlayerEngine(
                match.first,
                context: BuiltInPlayerContext.iptv,
              );
              await playback.patch(
                (s) => s.copyWith(builtInEngineIptv: match.first),
              );
            },
          ),
        settingsFocusableToggle(
          context,
          'IPTV programme guide (EPG)',
          'Show NOW and NEXT programme info in the player and channel browser.',
          snap.iptvEpgEnabled,
          (val) async {
            await settings.setIptvEpgEnabled(val);
            await playback.patch((s) => s.copyWith(iptvEpgEnabled: val));
            schedulePreferencesSyncPush();
          },
        ),
        settingsFocusableDropdown(
          context,
          'IPTV live max quality',
          'ExoPlayer only. Auto uses the portal’s full quality. Cap at 1080p, 720p, or 480p only on weak devices.',
          snap.iptvLiveMaxHeightLabel,
          SettingsService.iptvLiveMaxHeightOptions.keys.toList(),
          (val) async {
            if (val == null) return;
            final height = SettingsService.iptvLiveMaxHeightOptions[val] ?? 0;
            await settings.setIptvLiveMaxHeight(height);
            await playback.patch(
              (s) => s.copyWith(iptvLiveMaxHeightLabel: val),
            );
            schedulePreferencesSyncPush();
          },
        ),
        settingsFocusableDropdown(
          context,
          'IPTV live recovery',
          'How live channels reconnect after a stall. Auto picks per source (Xtream, Stalker, Forja Live, Stremio). Stable forces one policy. Classic uses freeze timers. Applies the next time you open the player.',
          snap.iptvLiveRecoveryModeLabel,
          SettingsService.iptvLiveRecoveryModeOptions.keys.toList(),
          (val) async {
            if (val == null) return;
            final String mode;
            if (val == SettingsService.iptvLiveRecoveryAutoLabel) {
              mode = SettingsService.iptvLiveRecoveryAuto;
            } else if (val == SettingsService.iptvLiveRecoveryClassicLabel) {
              mode = SettingsService.iptvLiveRecoveryClassic;
            } else {
              mode = SettingsService.composeIptvLiveRecoveryMode(
                classic: false,
                stallReopen: snap.iptvLiveRecoveryStallReopen,
              );
            }
            await settings.setIptvLiveRecoveryMode(mode);
            await playback.patch(
              (s) => s.copyWith(
                iptvLiveRecoveryModeLabel: val,
                iptvLiveRecoveryStallReopen:
                    SettingsService.iptvLiveRecoveryStallReopen(mode),
              ),
            );
          },
        ),
        if (snap.iptvLiveRecoveryModeLabel ==
            SettingsService.iptvLiveRecoveryStableLabel)
          settingsFocusableToggle(
            context,
            'Reopen on buffer stall',
            'Stable mode only. Reconnect when the picture freezes even if cache still reports data. Can drop a healthy Stalker buffer. Leave off unless you need it. Applies the next time you open the player.',
            snap.iptvLiveRecoveryStallReopen,
            (val) async {
              await settings.setIptvLiveRecoveryMode(
                SettingsService.composeIptvLiveRecoveryMode(
                  classic: false,
                  stallReopen: val,
                ),
              );
              await playback.patch(
                (s) => s.copyWith(iptvLiveRecoveryStallReopen: val),
              );
            },
          ),
        if (AccountFeatures.instance.isAdmin &&
            SettingsService.platformProfile == PlatformProfile.androidTv) ...[
          settingsFocusableToggle(
            context,
            'IPTV match display refresh',
            'MediaKit only. Match the TV refresh rate to the channel (for example 50 Hz for 50 fps). Helps 4K stutter. May briefly blink HDMI after the first frame. Applies the next time you open the player.',
            snap.iptvMatchDisplayRefresh,
            (val) async {
              await settings.setIptvMatchDisplayRefresh(val);
              await playback.patch(
                (s) => s.copyWith(iptvMatchDisplayRefresh: val),
              );
              schedulePreferencesSyncPush();
            },
            adminOnly: true,
          ),
          settingsFocusableDropdown(
            context,
            'IPTV live buffer',
            'MediaKit only. Live buffer ahead of playback. Auto: HD 15s, FHD/UHD 20s. Manual 15–30s also raises demuxer RAM. 30s (~150 MB) can crash 4K on weak boxes. Helps underruns, not frame judder. Applies the next time you open the player.',
            snap.iptvLiveBufferSecsLabel,
            SettingsService.iptvLiveBufferSecsOptions.keys.toList(),
            (val) async {
              if (val == null) return;
              final secs = SettingsService.iptvLiveBufferSecsOptions[val] ?? 0;
              await settings.setIptvLiveBufferSecs(secs);
              await playback.patch(
                (s) => s.copyWith(iptvLiveBufferSecsLabel: val),
              );
              schedulePreferencesSyncPush();
            },
            adminOnly: true,
          ),
        ],
      ],
    );
  }
}
