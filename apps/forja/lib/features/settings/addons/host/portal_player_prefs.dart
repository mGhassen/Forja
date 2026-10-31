import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/ui/focus_controls.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/l10n/l10n.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:rust/rust.dart';

/// IPTV player prefs that used to live under Settings → Playback.
class SettingsPortalPlayerPrefs extends ConsumerWidget {
  const SettingsPortalPlayerPrefs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(accountFeaturesProvider);
    final snap = ref.watch(settingsPlaybackProvider).valueOrNull;
    if (snap == null) return const SizedBox.shrink();

    final settings = SettingsService();
    final playback = ref.read(settingsPlaybackProvider.notifier);

    return SettingsGroup(
      label: context.l10n.addonsHostPlayerGroupLabel,
      children: [
        if (!kIsWeb &&
            (Platform.isAndroid ||
                Platform.isMacOS ||
                Platform.isWindows ||
                Platform.isLinux))
          settingsFocusableDropdown(
            context,
            context.l10n.addonsHostPortalEngineTitle,
            Platform.isAndroid
                ? context.l10n.addonsHostPortalEngineAndroidSubtitle
                : context.l10n.addonsHostPortalEngineDesktopSubtitle,
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
          context.l10n.addonsHostPortalEpgTitle,
          context.l10n.addonsHostPortalEpgSubtitle,
          snap.iptvEpgEnabled,
          (val) async {
            await settings.setIptvEpgEnabled(val);
            await playback.patch((s) => s.copyWith(iptvEpgEnabled: val));
            schedulePreferencesSyncPush();
          },
        ),
        settingsFocusableDropdown(
          context,
          context.l10n.addonsHostPortalMaxQualityTitle,
          context.l10n.addonsHostPortalMaxQualitySubtitle,
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
        // MediaKit live uses ffmpeg reconnect + grace/goLive (RFC-113) — these
        // modes only drive Exo soft-reopen. Hide when IPTV engine is not Exo.
        if (!kIsWeb &&
            Platform.isAndroid &&
            snap.builtInEngineIptv == BuiltInPlayerEngine.exoPlayer) ...[
          settingsFocusableDropdown(
            context,
            context.l10n.addonsHostPortalRecoveryTitle,
            context.l10n.addonsHostPortalRecoverySubtitle,
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
              context.l10n.addonsHostPortalReopenStallTitle,
              context.l10n.addonsHostPortalReopenStallSubtitle,
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
        ],
        if (AccountFeatures.instance.isAdmin &&
            SettingsService.platformProfile == PlatformProfile.androidTv) ...[
          settingsFocusableToggle(
            context,
            context.l10n.addonsHostPortalMatchRefreshTitle,
            context.l10n.addonsHostPortalMatchRefreshSubtitle,
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
            context.l10n.addonsHostPortalLiveBufferTitle,
            context.l10n.addonsHostPortalLiveBufferSubtitle,
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
