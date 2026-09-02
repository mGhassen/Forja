import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/settings_visibility.dart';
import 'package:forja/features/settings/widgets/p2p_streaming_ack_dialog.dart';
import 'package:forja/features/settings/widgets/settings_focus_controls.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:rust/rust.dart';

/// Direct torrent / Stremio / Nuvio play-source toggles under Sources → Forja addons.
class SettingsForjaAddonsPlayToggles extends ConsumerStatefulWidget {
  const SettingsForjaAddonsPlayToggles({super.key, required this.visibility});

  final SettingsVisibility visibility;

  @override
  ConsumerState<SettingsForjaAddonsPlayToggles> createState() =>
      _SettingsForjaAddonsPlayTogglesState();
}

class _SettingsForjaAddonsPlayTogglesState
    extends ConsumerState<SettingsForjaAddonsPlayToggles> {
  final SettingsService _settings = SettingsService();
  bool _p2pPromptQueued = false;

  SettingsPlaybackNotifier get _playback =>
      ref.read(settingsPlaybackProvider.notifier);

  String _playSourceSubtitle({required String native, required String atv}) {
    if (PlatformPlayback.capabilities.localTorrentEngine) return native;
    return atv;
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

  @override
  Widget build(BuildContext context) {
    final v = widget.visibility;
    final async = ref.watch(settingsPlaybackProvider);
    final snap = async.valueOrNull;
    if (snap == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (!_p2pPromptQueued &&
        !snap.p2pAcknowledged &&
        (v.showPlaySourceTorrentToggle ||
            v.showPlaySourceStremioToggle ||
            v.showPlaySourceNuvioToggle) &&
        (snap.playSourceTorrent ||
            snap.playSourceStremio ||
            snap.playSourceNuvio)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _p2pPromptQueued) return;
        _p2pPromptQueued = true;
        unawaited(_maybePromptP2pAck(snap));
      });
    }

    final showAnyToggle = v.showPlaySourceTorrentToggle ||
        v.showPlaySourceStremioToggle ||
        v.showPlaySourceNuvioToggle;
    if (!showAnyToggle) return const SizedBox.shrink();

    return SettingsGroup(
      label: 'Forja addons',
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
              await showP2pStreamingAckDialog(context, reviewOnly: true);
            } else {
              await _confirmP2pIfNeeded();
            }
          },
        ),
        if (v.showPlaySourceTorrentToggle)
          settingsFocusableToggle(
            context,
            'Direct torrent',
            _playSourceSubtitle(
              native: 'Search Forja indexers (Jackett / Prowlarr) below.',
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
              if (val && PlatformPlayback.capabilities.localTorrentEngine) {
                debugPrint('[Init] TorrentStream start (settings toggle)');
                await TorrentStreamService().start();
              }
            },
            enabled: v.lanPlaySourcesEditable,
          ),
        if (v.showPlaySourceStremioToggle)
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
            enabled: v.lanPlaySourcesEditable,
          ),
        if (v.showPlaySourceNuvioToggle)
          settingsFocusableToggle(
            context,
            'Nuvio',
            _playSourceSubtitle(
              native: 'Play from installed Nuvio scraper addons below.',
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
              if (val && PlatformPlayback.capabilities.playSourceNuvio) {
                debugPrint('[Init] Nuvio refresh (settings toggle)');
                unawaited(NuvioService.instance.refreshAllInstalled());
              }
            },
            enabled: v.lanPlaySourcesEditable,
          ),
      ],
    );
  }
}
