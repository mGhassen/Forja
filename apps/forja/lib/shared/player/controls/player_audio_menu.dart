import 'package:flutter/material.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:media_kit/media_kit.dart';

class PlayerAudioMenu {
  static Future<void> show(
    BuildContext context, {
    required Player player,
    required bool audioPinned,
    required Future<void> Function() onSelectAuto,
    required VoidCallback onManualSelect,
    BuildContext? anchorContext,
    Alignment alignment = Alignment.bottomLeft,
    EdgeInsets margin = const EdgeInsets.only(left: 16, bottom: 88),
  }) async {
    final tracks =
        player.state.tracks.audio.where((t) => t.id != 'no' && t.id != 'auto').toList();
    final current = player.state.track.audio;
    final audioAuto = !audioPinned;
    final active = await resolveActiveAudioTrack(player);
    final activeLabel = active == null
        ? null
        : formatPlayerTrackLabel(
            id: active.id,
            title: active.title,
            language: active.language,
          );

    if (!context.mounted) return;

    await PlayerPopupPanel.show(
      context: context,
      title: 'Audio',
      leadingIcon: Icons.audiotrack_rounded,
      alignment: alignment,
      margin: margin,
      anchorContext: anchorContext,
      child: ListView(
        padding: const EdgeInsets.all(8),
        shrinkWrap: true,
        children: [
          PlayerPopupListTile(
            badge: 'AUTO',
            label: 'Auto',
            subtitle: audioAuto ? activeLabel : null,
            selected: audioAuto,
            onTap: () async {
              PlayerPopupPanel.dismiss();
              if (!audioAuto) await onSelectAuto();
            },
          ),
          if (tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No audio tracks found',
                style: TextStyle(color: Colors.white38),
              ),
            )
          else
            ...tracks.map((track) {
              final label = formatPlayerTrackLabel(
                id: track.id,
                title: track.title,
                language: track.language,
              );
              final lang = track.language?.trim();
              return PlayerPopupListTile(
                badge: (lang != null && lang.isNotEmpty) ? lang.toUpperCase() : null,
                label: label,
                selected: audioPinned && track.id == current.id,
                onTap: () {
                  PlayerPopupPanel.dismiss();
                  if (!audioPinned || track.id != current.id) {
                    onManualSelect();
                    player.setAudioTrack(track);
                  }
                },
              );
            }),
        ],
      ),
    );
  }
}
