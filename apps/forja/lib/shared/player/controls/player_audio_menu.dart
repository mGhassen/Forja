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
    final tracks = player.state.tracks.audio
        .where((t) => t.id != 'no' && t.id != 'auto')
        .toList();
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: tracks.isEmpty
            ? const Text(
                'No audio tracks found',
                style: TextStyle(color: PlayerPopupTokens.muted),
              )
            : Column(
                children: [
                  for (var i = 0; i < tracks.length; i++) ...[
                    if (i != 0) const SizedBox(height: 8),
                    PlayerPopupOptionChip(
                      label: formatPlayerTrackLabel(
                        id: tracks[i].id,
                        title: tracks[i].title,
                        language: tracks[i].language,
                      ),
                      selected: tracks[i].id == selectedId,
                      expanded: true,
                      onTap: () {
                        PlayerPopupPanel.dismiss();
                        if (tracks[i].id != selectedId) {
                          onTrackSelected?.call();
                          player.setAudioTrack(tracks[i]);
                        }
                      },
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
