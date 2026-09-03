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
          'Load and show NOW / NEXT programme info in the IPTV player and channel browser.',
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
          'ExoPlayer only. Auto keeps full portal quality. Pick 1080p / 720p / 480p only if a weak device needs a lower adaptive variant — never applied automatically.',
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
          'How live channels reconnect. Auto (default) picks the policy per source — stall reopen for Xtream, buffer hold without stall for Stalker / Forja Live / Stremio — so you do not change settings per channel. Stable lets you force one policy. Classic reconnects on freeze timers. Takes effect next time you open the player.',
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
            'Stable only. Off by default under Auto. If the picture freezes or Buffering sticks with no playback progress, reconnect even when the demuxer still reports cache. Can kill a healthy buffer on Stalker — leave off unless you need it. Takes effect next time you open the player.',
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
            'MediaKit only. On by default. When on, asks the TV to switch refresh rate to match the channel (e.g. 50 Hz for 50 fps) — test for 4K stutter. Brief HDMI blink after the first frame (4K waits so the decoder can finish init); next open of the player picks it up.',
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
            'MediaKit only. How many seconds of live demuxer cushion to keep ahead of the playhead. Auto picks by resolution (HD 15 s / FHD+UHD 20 s, 96 MiB). Manual 15–30 also scales demuxer RAM. 30 s is 150 MB — can force-close 4K on weak boxes. Helps underrun experiments — not cadence judder. Next open of the player.',
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
