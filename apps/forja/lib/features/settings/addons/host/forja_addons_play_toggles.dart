import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/shell/visibility.dart';
import 'package:forja/features/settings/ui/p2p_streaming_ack_dialog.dart';
import 'package:forja/features/settings/ui/focus_controls.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/l10n/l10n.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:rust/rust.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

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
      label: context.l10n.addonsHostPlayTogglesGroupLabel,
      children: [
        SettingsActionRow(
          title: snap.p2pAcknowledged
              ? context.l10n.addonsHostPlayTogglesP2pAckedTitle
              : context.l10n.addonsHostPlayTogglesP2pConfirmTitle,
          subtitle: snap.p2pAcknowledged
              ? context.l10n.addonsHostPlayTogglesP2pAckedSubtitle
              : context.l10n.addonsHostPlayTogglesP2pConfirmSubtitle,
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
            context.l10n.addonsHostPlayTogglesTorrentTitle,
            _playSourceSubtitle(
              native: context.l10n.addonsHostPlayTogglesTorrentNativeSubtitle,
              atv: context.l10n.addonsHostPlayTogglesTorrentAtvSubtitle,
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
            context.l10n.addonsHostPlayTogglesStremioTitle,
            _playSourceSubtitle(
              native: context.l10n.addonsHostPlayTogglesStremioNativeSubtitle,
              atv: context.l10n.addonsHostPlayTogglesDirectHttpAtvSubtitle,
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
            context.l10n.addonsHostPlayTogglesNuvioTitle,
            _playSourceSubtitle(
              native: context.l10n.addonsHostPlayTogglesNuvioNativeSubtitle,
              atv: context.l10n.addonsHostPlayTogglesDirectHttpAtvSubtitle,
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
                debugPrint('[Init] Nuvio enabled (settings toggle) — no auto-refresh');
              }
            },
            enabled: v.lanPlaySourcesEditable,
          ),
      ],
    );
  }
}
