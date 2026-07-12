import 'package:flutter/material.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:media_kit/media_kit.dart';

class PlayerAudioMenu {
  static Future<void> show(
    BuildContext context, {
    required Player player,
    VoidCallback? onTrackSelected,
    BuildContext? anchorContext,
    Alignment alignment = Alignment.bottomLeft,
    EdgeInsets margin = const EdgeInsets.only(left: 16, bottom: 88),
  }) async {
    final tracks =
        player.state.tracks.audio.where((t) => t.id != 'no' && t.id != 'auto').toList();
    final current = player.state.track.audio;
    final active = await resolveActiveAudioTrack(player);
    final selectedId = active?.id ?? current.id;

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
                selected: track.id == selectedId,
                onTap: () {
                  PlayerPopupPanel.dismiss();
                  if (track.id != selectedId) {
                    onTrackSelected?.call();
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
