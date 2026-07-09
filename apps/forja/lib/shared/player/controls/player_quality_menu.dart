import 'package:flutter/material.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:rust/rust.dart';

class PlayerQualityMenu {
  static void show(
    BuildContext context, {
    required List<HlsQuality> qualities,
    required String? currentQualityUrl,
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
        child: playbackQualityLabel != null
            ? ListView(
                padding: const EdgeInsets.all(8),
                shrinkWrap: true,
                children: [
                  PlayerPopupListTile(
                    label: playbackQualityLabel,
                    subtitle: playbackQualityDetail,
                    selected: true,
                  ),
                ],
              )
            : const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Quality not available yet',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
      );
      return;
    }

    PlayerPopupPanel.show(
      context: context,
      title: 'Quality',
      leadingIcon: Icons.hd_outlined,
      alignment: alignment,
      margin: margin,
      anchorContext: anchorContext,
      child: ListView(
        padding: const EdgeInsets.all(8),
        shrinkWrap: true,
        children: qualities.map((q) {
          final isCurrent = q.url == currentQualityUrl;
          final subtitle = q.bandwidth != null
              ? '${(q.bandwidth! / 1000).round()} kbps'
              : null;
          return PlayerPopupListTile(
            badge: q.isAuto ? 'AUTO' : null,
            label: q.label,
            subtitle: subtitle,
            selected: isCurrent,
            onTap: () async {
              PlayerPopupPanel.dismiss();
              if (!isCurrent) await onSelect(q);
            },
          );
        }).toList(),
      ),
    );
  }
}
