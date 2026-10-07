import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:rust/rust.dart';

/// Torrents in the local engine — progress, peers, speed, Stop / Stop all.
class SettingsTorrentSessionSection extends StatefulWidget {
  const SettingsTorrentSessionSection({super.key});

  @override
  State<SettingsTorrentSessionSection> createState() =>
      _SettingsTorrentSessionSectionState();
}

class _SettingsTorrentSessionSectionState
    extends State<SettingsTorrentSessionSection> {
  static const _pollInterval = Duration(seconds: 2);

  List<TorrentSessionEntry> _entries = const [];
  bool _loading = true;
  bool _stoppingAll = false;
  String? _stoppingHash;
  Timer? _poll;
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(_pollInterval, (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final gen = ++_loadGen;
    final entries = await TorrentStreamService().listSessionTorrents();
    if (!mounted || gen != _loadGen) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _stop(TorrentSessionEntry entry) async {
    if (_stoppingHash != null || _stoppingAll) return;
    setState(() => _stoppingHash = entry.infoHash);
    try {
      final ok = await TorrentStreamService().removeSessionTorrent(entry);
      if (!mounted) return;
      if (ok) {
        ForjaToast.success('Stopped ${entry.displayName}');
      } else {
        ForjaToast.error('Could not stop ${entry.displayName}');
      }
    } finally {
      if (mounted) setState(() => _stoppingHash = null);
      await _load();
    }
  }

  Future<void> _stopAll() async {
    if (_stoppingAll || _stoppingHash != null) return;
    setState(() => _stoppingAll = true);
    try {
      final removed = await TorrentStreamService().removeAllSessionTorrents();
      if (!mounted) return;
      ForjaToast.success(
        removed == 1 ? 'Stopped 1 torrent' : 'Stopped $removed torrents',
      );
    } finally {
      if (mounted) setState(() => _stoppingAll = false);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformPlayback.capabilities.localTorrentEngine) {
      return const SizedBox.shrink();
    }
    final noteStyle = TextStyle(
      color: ForjaShellColors.textSecondary,
      fontSize: SettingsTokens.rowSubtitleSizeOf(context),
      height: 1.35,
    );

    return SettingsGroup(
      label: 'Torrents',
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_entries.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 12),
            child: Text(
              'No torrents are downloading. A torrent you play shows here '
              'with its progress until you stop it or close the player.',
              style: noteStyle,
            ),
          )
        else ...[
          for (final entry in _entries)
            SettingsActionRow(
              title: entry.displayName,
              subtitle: entry.statusLine,
              leading: Icon(
                entry.active
                    ? Icons.play_circle_rounded
                    : Icons.downloading_rounded,
                color: entry.active
                    ? ForjaShellColors.brandGreen
                    : ForjaShellColors.iconMuted,
              ),
              trailing: const Icon(
                Icons.stop_circle_rounded,
                color: ForjaShellColors.textSecondary,
              ),
              busy: _stoppingHash == entry.infoHash,
              onTap: () => _stop(entry),
            ),
          SettingsActionRow(
            title: 'Stop all torrents',
            subtitle: 'Stops every torrent above and deletes its files.',
            destructive: true,
            leading: const Icon(
              Icons.stop_rounded,
              color: ForjaShellColors.iconMuted,
            ),
            trailing: const SizedBox.shrink(),
            busy: _stoppingAll,
            onTap: _stopAll,
          ),
        ],
      ],
    );
  }
}
