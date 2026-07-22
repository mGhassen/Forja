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
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerPopupOptionChip(
                      label: playbackQualityLabel,
                      selected: true,
                      expanded: true,
                    ),
                  ],
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
    final active = qualityAuto
        ? matchActiveHlsVariant(qualities, playerState)
        : null;

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
          // While Auto/ABR is active, hide Auto and highlight the variant
          // currently playing. Auto reappears once a fixed quality is locked.
          children: qualities
              .where((q) => !q.isAuto || !qualityAuto)
              .map((q) {
            final selected = q.isAuto
                ? false
                : (qualityAuto
                    ? (active != null &&
                        (active.url == q.url || active.label == q.label))
                    : q.url == currentQualityUrl);
            return PlayerPopupOptionChip(
              label: q.isAuto ? 'Auto' : q.label,
              selected: selected,
              onTap: () async {
                PlayerPopupPanel.dismiss();
                if (q.isAuto) {
                  if (qualityAuto) return;
                  await onSelect(q);
                  return;
                }
                // Lock even if this variant is the Auto pick (selected visually).
                if (!qualityAuto && q.url == currentQualityUrl) return;
                await onSelect(q);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
