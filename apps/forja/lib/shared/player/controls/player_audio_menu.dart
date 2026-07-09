import 'package:flutter/material.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:media_kit/media_kit.dart';

class PlayerAudioMenu {
  static void show(
    BuildContext context, {
    required Player player,
    BuildContext? anchorContext,
    Alignment alignment = Alignment.bottomLeft,
    EdgeInsets margin = const EdgeInsets.only(left: 16, bottom: 88),
  }) {
    final tracks = player.state.tracks.audio.where((t) => t.id != 'no').toList();
    final current = player.state.track.audio;

    PlayerPopupPanel.show(
      context: context,
      title: 'Audio',
      leadingIcon: Icons.audiotrack_rounded,
      alignment: alignment,
      margin: margin,
      anchorContext: anchorContext,
      child: ListView(
        padding: const EdgeInsets.all(8),
        shrinkWrap: true,
        children: tracks.isEmpty
            ? const [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No audio tracks found',
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
              ]
            : tracks.map((track) {
                final label = track.title ?? track.language ?? 'Track ${track.id}';
                final lang = track.language?.trim();
                return PlayerPopupListTile(
                  badge: (lang != null && lang.isNotEmpty) ? lang.toUpperCase() : null,
                  label: label,
                  selected: track.id == current.id,
                  onTap: () {
                    PlayerPopupPanel.dismiss();
                    if (track.id != current.id) {
                      player.setAudioTrack(track);
                    }
                  },
                );
              }).toList(),
      ),
    );
  }
}
