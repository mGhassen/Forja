import 'package:flutter/material.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:media_kit/media_kit.dart';
import 'package:rust/rust.dart';

class PlayerQualityMenu {
  static void show(
    BuildContext context, {
    required List<HlsQuality> qualities,
    required String? currentQualityUrl,
    required String? masterUrl,
    required PlayerState playerState,
    required Future<void> Function(HlsQuality quality) onSelect,
    String? playbackQualityLabel,
    String? playbackQualityDetail,
    BuildContext? anchorContext,
    Alignment alignment = Alignment.bottomLeft,
    EdgeInsets margin = const EdgeInsets.only(left: 16, bottom: 88),
  }) {
    if (qualities.isEmpty) {
      PlayerPopupPanel.show(
        context: context,
        title: 'Quality',
        leadingIcon: Icons.hd_outlined,
        alignment: alignment,
        margin: margin,
        anchorContext: anchorContext,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: playbackQualityLabel != null
              ? PlayerPopupOptionChip(
                  label: playbackQualityLabel,
                  selected: true,
                  expanded: true,
                )
              : const Text(
                  'Quality not available yet',
                  style: TextStyle(color: PlayerPopupTokens.muted),
                ),
        ),
      );
      return;
    }

    final qualityAuto = isHlsQualityAuto(currentQualityUrl, masterUrl);

    PlayerPopupPanel.show(
      context: context,
      title: 'Quality',
      leadingIcon: Icons.hd_outlined,
      alignment: alignment,
      margin: margin,
      anchorContext: anchorContext,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: qualities.map((q) {
            final selected = q.isAuto
                ? qualityAuto
                : (!qualityAuto && q.url == currentQualityUrl);
            return PlayerPopupOptionChip(
              label: q.isAuto ? 'Auto' : q.label,
              selected: selected,
              onTap: () async {
                PlayerPopupPanel.dismiss();
                if (!selected) await onSelect(q);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
