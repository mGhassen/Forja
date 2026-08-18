import 'package:flutter/material.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:rust/rust.dart';

class PlayerProviderMenu {
  static void show(
    BuildContext context, {
    required Map<String, dynamic> providers,
    required String? currentProviderId,
    required Future<void> Function(String providerId) onSelect,
    Alignment alignment = Alignment.bottomRight,
    EdgeInsets margin = const EdgeInsets.only(right: 16, bottom: 88),
    BuildContext? anchorContext,
  }) {
    if (providers.isEmpty) return;

    final entries = providers.entries.toList();

    PlayerPopupPanel.show(
      context: context,
      title: 'Servers',
      leadingIcon: Icons.cloud_outlined,
      alignment: alignment,
      margin: margin,
      anchorContext: anchorContext,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          children: [
            for (var i = 0; i < entries.length; i++)
              Builder(
                builder: (_) {
                  final key = entries[i].key;
                  final fallbackName = entries[i].value['name']?.toString();
                  final isCurrent = key == currentProviderId;
                  return PlayerPopupOptionChip(
                    label: StreamProviderDisplay.playerLabel(
                      key,
                      fallbackName: fallbackName,
                    ),
                    selected: isCurrent,
                    expanded: true,
                    onTap: () async {
                      PlayerPopupPanel.dismiss();
                      if (!isCurrent) await onSelect(key);
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  static String snackbarLabel(String providerId, dynamic provider) {
    if (provider is AnimeEmbed) {
      return provider.label;
    }
    final fallbackName = switch (provider) {
      final Map<String, dynamic> map => map['name']?.toString(),
      _ => null,
    };
    return StreamProviderDisplay.playerLabel(
      providerId,
      fallbackName: fallbackName,
    );
  }
}
