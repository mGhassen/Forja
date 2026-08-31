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
      child: tracks.isEmpty
          ? const Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Text(
                'No audio tracks found',
                style: TextStyle(color: PlayerPopupTokens.muted),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              children: [
                for (var i = 0; i < tracks.length; i++)
                  _tile(
                    track: tracks[i],
                    index: i + 1,
                    selected: tracks[i].id == selectedId,
                    onTrackSelected: onTrackSelected,
                    player: player,
                  ),
              ],
            ),
    );
  }

  static Widget _tile({
    required AudioTrack track,
    required int index,
    required bool selected,
    required VoidCallback? onTrackSelected,
    required Player player,
  }) {
    final label = formatPlayerTrackLabel(
      id: track.id,
      title: track.title,
      language: track.language,
      index: index,
    );
    return PlayerPopupListTile(
      label: label,
      subtitle: formatPlayerAudioFormatSubtitle(
        languageLabel: label,
        title: track.title,
        language: track.language,
        codec: track.codec,
        channels: track.channels,
        channelscount: track.channelscount,
        samplerate: track.samplerate,
        bitrate: track.bitrate,
      ),
      selected: selected,
      onTap: () async {
        PlayerPopupPanel.dismiss();
        if (!selected) {
          onTrackSelected?.call();
          await selectPlayerAudioTrack(player, track);
        }
      },
    );
  }
}
