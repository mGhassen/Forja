import 'package:flutter/material.dart';
import 'package:forja/shared/player/controls/player_menus.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';
import 'package:forja/shared/player/player/utils.dart';

/// Minimalist Exo track / settings menus — [PlayerPopupPanel] chips & list tiles.
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
      child: _trackChipColumn(
        tracks: tracks.audio,
        emptyLabel: 'None available',
        labelOf: (t) => formatPlayerTrackLabel(
          id: t.id,
          title: t.label,
          language: t.language,
        ),
        onSelect: onSelect,
      ),
    );
  }

  static Future<void> showSubtitles({
    required BuildContext context,
    required ExoTracksSnapshot tracks,
    required Future<void> Function(String? trackId) onSelect,
    BuildContext? anchorContext,
  }) {
    return PlayerPopupPanel.show(
      context: context,
      title: 'Subtitles',
      leadingIcon: Icons.subtitles_outlined,
      anchorContext: anchorContext,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerPopupOptionChip(
              label: 'Off',
              selected: tracks.textOff ||
                  tracks.text.every((t) => !t.selected),
              expanded: true,
              onTap: () async {
                PlayerPopupPanel.dismiss();
                await onSelect(null);
              },
            ),
            if (tracks.text.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'None available',
                  style: TextStyle(color: PlayerPopupTokens.muted),
                ),
              )
            else
              for (final t in tracks.text) ...[
                const SizedBox(height: 8),
                PlayerPopupOptionChip(
                  label: formatPlayerTrackLabel(
                    id: t.id,
                    title: t.label,
                    language: t.language,
                  ),
                  selected: !tracks.textOff && t.selected,
                  expanded: true,
                  onTap: () async {
                    PlayerPopupPanel.dismiss();
                    await onSelect(t.id);
                  },
                ),
              ],
          ],
        ),
      ),
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
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PlayerPopupOptionChip(
              label: 'Auto',
              selected: tracks.videoAuto,
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
                  selected: !tracks.videoAuto && t.selected,
                  onTap: () async {
                    PlayerPopupPanel.dismiss();
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
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
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
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (mode, label) in options)
                      PlayerPopupOptionChip(
                        label: label,
                        selected: current == mode,
                        onTap: () async {
                          await onResize(mode);
                          setPage(() {});
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ];
      },
    );
  }

  static Widget _trackChipColumn({
    required List<ExoTrackInfo> tracks,
    required String emptyLabel,
    required String Function(ExoTrackInfo) labelOf,
    required Future<void> Function(String trackId) onSelect,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: tracks.isEmpty
          ? Text(
              emptyLabel,
              style: const TextStyle(color: PlayerPopupTokens.muted),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < tracks.length; i++) ...[
                  if (i != 0) const SizedBox(height: 8),
                  PlayerPopupOptionChip(
                    label: labelOf(tracks[i]),
                    selected: tracks[i].selected,
                    expanded: true,
                    onTap: () async {
                      PlayerPopupPanel.dismiss();
                      if (!tracks[i].selected) {
                        await onSelect(tracks[i].id);
                      }
                    },
                  ),
                ],
              ],
            ),
    );
  }
}
