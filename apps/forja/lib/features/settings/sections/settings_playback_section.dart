import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/providers/settings_visibility_provider.dart';
import 'package:forja/features/settings/settings_visibility.dart';
import 'package:forja/features/settings/widgets/p2p_streaming_ack_dialog.dart';
import 'package:forja/features/settings/widgets/settings_focus_controls.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
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
  bool _p2pPromptQueued = false;

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

  Future<bool> _confirmP2pIfNeeded() async {
    final snap = ref.read(settingsPlaybackProvider).valueOrNull;
    if (snap?.p2pAcknowledged == true) return true;
    final ok = await ensureP2pStreamingAcknowledged(context);
    if (!ok || !mounted) return false;
    await _playback.patch((s) => s.copyWith(p2pAcknowledged: true));
    return true;
  }

  Future<void> _maybePromptP2pAck(SettingsPlaybackSnapshot snap) async {
    if (snap.p2pAcknowledged || !mounted) return;
    final ok = await _confirmP2pIfNeeded();
    if (!mounted) return;
    if (ok) return;
    await _settings.setPlaySourceTorrentEnabled(false);
    await _settings.setPlaySourceStremioEnabled(false);
    await _settings.setPlaySourceNuvioEnabled(false);
    await _playback.patch(
      (s) => s.copyWith(
        playSourceTorrent: false,
        playSourceStremio: false,
        playSourceNuvio: false,
      ),
    );
    schedulePreferencesSyncPush();
  }

  String _playSourceSubtitle({required String native, required String atv}) {
    if (PlatformPlayback.capabilities.localTorrentEngine) return native;
    return atv;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(accountFeaturesProvider);
    final async = ref.watch(settingsPlaybackProvider);
    final snap = async.valueOrNull;
    if (snap != null &&
        !_p2pPromptQueued &&
        !snap.p2pAcknowledged &&
        (widget.visibility.showPlaySourceTorrentToggle ||
            widget.visibility.showPlaySourceStremioToggle ||
            widget.visibility.showPlaySourceNuvioToggle) &&
        (snap.playSourceTorrent ||
            snap.playSourceStremio ||
            snap.playSourceNuvio)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _p2pPromptQueued) return;
        _p2pPromptQueued = true;
        unawaited(_maybePromptP2pAck(snap));
      });
    }
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
        if (widget.visibility.showPlaySources) ...[
          if (widget.visibility.showPlaySourceTorrentToggle ||
              widget.visibility.showPlaySourceStremioToggle ||
              widget.visibility.showPlaySourceNuvioToggle)
            SettingsGroup(
              children: [
                SettingsActionRow(
                  title: snap.p2pAcknowledged
                      ? 'You are aware of P2P streaming'
                      : 'Confirm you are aware of P2P streaming',
                  subtitle: snap.p2pAcknowledged
                      ? 'Direct torrent, Stremio, and Nuvio can be used. Tap to review.'
                      : 'Required once before turning on Direct torrent, Stremio, or Nuvio.',
                  trailing: snap.p2pAcknowledged
                      ? const Icon(
                          Icons.check_rounded,
                          color: ForjaShellColors.brandGreen,
                        )
                      : const SizedBox.shrink(),
                  onTap: () async {
                    if (snap.p2pAcknowledged) {
                      await showP2pStreamingAckDialog(
                        context,
                        reviewOnly: true,
                      );
                    } else {
                      await _confirmP2pIfNeeded();
                    }
                  },
                ),
              ],
            ),
          SettingsGroup(
            label: 'Play sources',
            children: [
              if (widget.visibility.showPlaySourceEngineToggle)
                settingsFocusableToggle(
                  context,
                  'Forja',
                  'Play from plugins in Sources → Forja. Auto = green Play races them.',
                  snap.playSourceEngine,
                  (val) async {
                    await _settings.setPlaySourceEngineEnabled(val);
                    await _playback.patch(
                      (s) => s.copyWith(playSourceEngine: val),
                    );
                    schedulePreferencesSyncPush();
                    if (val) {
                      unawaited(
                        EngineService.instance.ensureOfficialInstalled(),
                      );
                    }
                  },
                  enabled: widget.visibility.lanPlaySourcesEditable,
                  leadingCheckValue: snap.playSourceEngineAutoStart,
                  onLeadingCheckChanged: (val) async {
                    await _settings.setPlaySourceEngineAutoStartEnabled(val);
                    await _playback.patch(
                      (s) => s.copyWith(playSourceEngineAutoStart: val),
                    );
                    schedulePreferencesSyncPush();
                  },
                ),
              if (widget.visibility.showPlaySourceTorrentToggle)
                settingsFocusableToggle(
                  context,
                  'Direct torrent',
                  _playSourceSubtitle(
                    native:
                        'Search Forja indexers (Jackett / Prowlarr) in Sources.',
                    atv:
                        'Search torrents here. Playing a magnet needs a paired desktop (Settings → LAN).',
                  ),
                  snap.playSourceTorrent,
                  (val) async {
                    if (val && !await _confirmP2pIfNeeded()) return;
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
                  enabled: widget.visibility.lanPlaySourcesEditable,
                ),
              if (widget.visibility.showPlaySourceStremioToggle)
                settingsFocusableToggle(
                  context,
                  'Stremio',
                  _playSourceSubtitle(
                    native: 'Play from installed Stremio addon streams.',
                    atv:
                        'Direct HTTP plays on this TV. Magnets need a paired desktop (Settings → LAN).',
                  ),
                  snap.playSourceStremio,
                  (val) async {
                    if (val && !await _confirmP2pIfNeeded()) return;
                    await _settings.setPlaySourceStremioEnabled(val);
                    await _playback.patch(
                      (s) => s.copyWith(playSourceStremio: val),
                    );
                    schedulePreferencesSyncPush();
                  },
                  enabled: widget.visibility.lanPlaySourcesEditable,
                ),
              if (widget.visibility.showPlaySourceNuvioToggle)
                settingsFocusableToggle(
                  context,
                  'Nuvio',
                  _playSourceSubtitle(
                    native:
                        'Play from installed Nuvio scraper addons in Sources.',
                    atv:
                        'Direct HTTP plays on this TV. Magnets need a paired desktop (Settings → LAN).',
                  ),
                  snap.playSourceNuvio,
                  (val) async {
                    if (val && !await _confirmP2pIfNeeded()) return;
                    await _settings.setPlaySourceNuvioEnabled(val);
                    await _playback.patch(
                      (s) => s.copyWith(playSourceNuvio: val),
                    );
                    schedulePreferencesSyncPush();
                    if (val &&
                        PlatformPlayback.capabilities.playSourceNuvio) {
                      debugPrint('[Init] Nuvio refresh (settings toggle)');
                      unawaited(NuvioService.instance.refreshAllInstalled());
                    }
                  },
                  enabled: widget.visibility.lanPlaySourcesEditable,
                ),
              if (AccountFeatures.instance.isAdmin)
                settingsFocusableToggle(
                  context,
                  'Webstreaming',
                  'Play from web stream extractors (Videasy, WebStreamr, …). '
                  'Also gates Anime VidLink sniff and Asian Drama third-party embeds on green Play.',
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
                  adminOnly: true,
                ),
              if (snap.playSourceWebstreaming &&
                  AccountFeatures.instance.isAdmin) ...[
                settingsFocusableToggle(
                  context,
                  'Simple resolve (experimental)',
                  'One provider at a time in Tries order: filter streams, probe, then open the player once. Leaves the old race path off.',
                  snap.simpleStreamingResolve,
                  (val) async {
                    await _settings.setSimpleStreamingResolveEnabled(val);
                    await _playback.patch(
                      (s) => s.copyWith(simpleStreamingResolve: val),
                    );
                    schedulePreferencesSyncPush();
                  },
                  adminOnly: true,
                ),
                settingsFocusableDropdown(
                  context,
                  'STREAMCRYPTO decrypt',
                  'enc=2 player family (Videasy, VidSrc.sbs 4K, …). WebView is the current JS host; Native is Dart and skips that WebView.',
                  snap.streamCryptoDecryptLabel,
                  SettingsService.streamCryptoDecryptOptions.keys.toList(),
                  (val) async {
                    if (val == null) return;
                    final stored =
                        SettingsService.streamCryptoDecryptOptions[val] ??
                        SettingsService.streamCryptoDecryptWebview;
                    await _settings.setStreamCryptoDecrypt(stored);
                    await _playback.patch(
                      (s) => s.copyWith(streamCryptoDecryptLabel: val),
                    );
                    schedulePreferencesSyncPush();
                  },
                ),
              ],
            ],
          ),
        ],
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
            if (widget.visibility.showIptvSettings) ...[
              if (Platform.isAndroid)
                settingsFocusableDropdown(
                  context,
                  'IPTV engine',
                  'Live channels only. Does not change Movies & series or Live Matches.',
                  snap.builtInEngineIptv.displayName,
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
                      context: BuiltInPlayerContext.iptv,
                    );
                    await _playback.patch(
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
                  await _settings.setIptvEpgEnabled(val);
                  await _playback.patch((s) => s.copyWith(iptvEpgEnabled: val));
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
                  final height =
                      SettingsService.iptvLiveMaxHeightOptions[val] ?? 0;
                  await _settings.setIptvLiveMaxHeight(height);
                  await _playback.patch(
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
                  } else if (val ==
                      SettingsService.iptvLiveRecoveryClassicLabel) {
                    mode = SettingsService.iptvLiveRecoveryClassic;
                  } else {
                    mode = SettingsService.composeIptvLiveRecoveryMode(
                      classic: false,
                      stallReopen: snap.iptvLiveRecoveryStallReopen,
                    );
                  }
                  await _settings.setIptvLiveRecoveryMode(mode);
                  await _playback.patch(
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
                    await _settings.setIptvLiveRecoveryMode(
                      SettingsService.composeIptvLiveRecoveryMode(
                        classic: false,
                        stallReopen: val,
                      ),
                    );
                    await _playback.patch(
                      (s) => s.copyWith(iptvLiveRecoveryStallReopen: val),
                    );
                  },
                ),
              if (AccountFeatures.instance.isAdmin &&
                  SettingsService.platformProfile ==
                      PlatformProfile.androidTv)
                settingsFocusableToggle(
                  context,
                  'IPTV match display refresh',
                  'MediaKit only. On by default. When on, asks the TV to switch refresh rate to match the channel (e.g. 50 Hz for 50 fps) — test for 4K stutter. Brief HDMI blink on open; next open of the player picks it up.',
                  snap.iptvMatchDisplayRefresh,
                  (val) async {
                    await _settings.setIptvMatchDisplayRefresh(val);
                    await _playback.patch(
                      (s) => s.copyWith(iptvMatchDisplayRefresh: val),
                    );
                    schedulePreferencesSyncPush();
                  },
                  adminOnly: true,
                ),
            ],
            if (widget.visibility.showPlaySources)
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
