import 'package:flutter/material.dart';
import 'package:forja/shared/player/controls/player_menus.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_subtitle_dialog.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';
import 'package:forja/shared/player/player/utils.dart';

/// Minimalist Exo track / settings menus - [PlayerPopupPanel] chips & list tiles.
abstract final class ExoPlayerMenus {
  static Future<void> showAudio({
    required BuildContext context,
    required ExoTracksSnapshot tracks,
    required Future<void> Function(String trackId) onSelect,
    BuildContext? anchorContext,
  }) {
    return PlayerPopupPanel.show(
      context: context,
      title: 'Audio',
      leadingIcon: Icons.audiotrack_rounded,
      anchorContext: anchorContext,
      child: _audioTrackColumn(
        tracks: tracks.audio,
        onSelect: onSelect,
      ),
    );
  }

  /// Two-panel Subtitles dialog (groups | tracks) — same shape as Sources.
  static Future<void> showSubtitles({
    required BuildContext context,
    required ExoTracksSnapshot tracks,
    required Future<void> Function(ExoTrackInfo? track) onSelectEmbedded,
    required Future<void> Function() onOff,
    List<Map<String, dynamic>> externalSubtitles = const [],
    String? selectedExternalSubUrl,
    bool isFetchingSubs = false,
    Future<void> Function(Map<String, dynamic> sub)? onSelectExternal,
    /// Local SRT/VTT file (ASS/SSA need MediaKit/libass).
    Future<void> Function({required String path, required String name})?
        onLoadFromFile,
    VoidCallback? onSubtitleSettings,
    BuildContext? anchorContext,
  }) {
    return PlayerSubtitleDialog.show(
      context,
      tracks: tracks,
      onOff: onOff,
      externalSubtitles: externalSubtitles,
      selectedExternalSubUrl: selectedExternalSubUrl,
      isFetchingSubs: isFetchingSubs,
      onSelectExternal: onSelectExternal,
      onLoadFromFile: onLoadFromFile,
      onSubtitleSettings: onSubtitleSettings,
      onSelectEmbedded: (track) => onSelectEmbedded(track),
    );
  }

  static Future<void> showQuality({
    required BuildContext context,
    required ExoTracksSnapshot tracks,
    required Future<void> Function(String? trackId) onSelect,
    BuildContext? anchorContext,
  }) {
    return PlayerPopupPanel.show(
      context: context,
      title: 'Quality',
      leadingIcon: Icons.hd_outlined,
      anchorContext: anchorContext,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // While Auto/ABR is active, hide Auto and highlight the playing
            // track. Auto reappears once a fixed quality is locked.
            if (!tracks.videoAuto)
              PlayerPopupOptionChip(
                label: 'Auto',
                selected: false,
                expanded: true,
                onTap: () async {
                  PlayerPopupPanel.dismiss();
                  await onSelect(null);
                },
              ),
            if (tracks.video.isEmpty && !tracks.videoAuto)
              const Text(
                'None available',
                style: TextStyle(color: PlayerPopupTokens.muted),
              )
            else
              for (final t in tracks.video)
                PlayerPopupOptionChip(
                  label: t.label,
                  selected: t.selected,
                  expanded: true,
                  onTap: () async {
                    PlayerPopupPanel.dismiss();
                    // Lock even if this track is the Auto pick.
                    if (!tracks.videoAuto && t.selected) return;
                    await onSelect(t.id);
                  },
                ),
          ],
        ),
      ),
    );
  }

  static void showSettings({
    required BuildContext context,
    required double Function() rateOf,
    required String Function() resizeModeOf,
    required Future<void> Function(double rate) onRate,
    required Future<void> Function(String mode) onResize,
    BuildContext? anchorContext,
  }) {
    showPlayerSettingsMenu(
      context: context,
      anchorContext: anchorContext,
      buildEntries: () {
        final rate = rateOf();
        final resizeMode = resizeModeOf();
        return [
          PlayerSettingsEntry(
            icon: Icons.speed_rounded,
            title: 'Playback speed',
            value: rate == 1.0 ? 'Normal' : '${rate}x',
            pageBuilder: (_) => StatefulBuilder(
              builder: (context, setPage) {
                final current = rateOf();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    0.25,
                    0.5,
                    0.75,
                    1.0,
                    1.25,
                    1.5,
                    1.75,
                    2.0,
                  ].map((speed) {
                    return PlayerPopupOptionChip(
                      label: speed == 1.0 ? 'Normal' : '${speed}x',
                      selected: speed == current,
                      expanded: true,
                      onTap: () async {
                        await onRate(speed);
                        setPage(() {});
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
          PlayerSettingsEntry(
            icon: Icons.aspect_ratio_rounded,
            title: 'Fit',
            subtitle: 'How video fills the frame',
            value: switch (resizeMode) {
              'fill' => 'Fill',
              'zoom' => 'Zoom',
              _ => 'Fit',
            },
            pageBuilder: (_) => StatefulBuilder(
              builder: (context, setPage) {
                final current = resizeModeOf();
                const options = [
                  ('fit', 'Fit'),
                  ('fill', 'Fill'),
                  ('zoom', 'Zoom'),
                ];
                return playerPopupChipRow([
                  for (final (mode, label) in options)
                    PlayerPopupOptionChip(
                      label: label,
                      selected: current == mode,
                      expanded: true,
                      grouped: true,
                      onTap: () async {
                        await onResize(mode);
                        setPage(() {});
                      },
                    ),
                ]);
              },
            ),
          ),
        ];
      },
    );
  }

  static Widget _audioTrackColumn({
    required List<ExoTrackInfo> tracks,
    required Future<void> Function(String trackId) onSelect,
  }) {
    if (tracks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Text(
          'None available',
          style: TextStyle(color: PlayerPopupTokens.muted),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      children: [
        for (var i = 0; i < tracks.length; i++)
          _audioTile(track: tracks[i], index: i + 1, onSelect: onSelect),
      ],
    );
  }

  static Widget _audioTile({
    required ExoTrackInfo track,
    required int index,
    required Future<void> Function(String trackId) onSelect,
  }) {
    final label = formatPlayerTrackLabel(
      id: track.id,
      title: track.label,
      language: track.language,
      index: index,
    );
    return PlayerPopupListTile(
      label: label,
      subtitle: formatPlayerAudioFormatSubtitle(
        languageLabel: label,
        title: track.label,
        language: track.language,
        bitrate: track.bitrate > 0 ? track.bitrate : null,
      ),
      selected: track.selected,
      onTap: () async {
        PlayerPopupPanel.dismiss();
        if (!track.selected) {
          await onSelect(track.id);
        }
      },
    );
  }
}

