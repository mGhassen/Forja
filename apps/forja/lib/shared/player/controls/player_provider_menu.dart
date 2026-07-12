import 'package:flutter/material.dart';
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

    PlayerPopupPanel.show(
      context: context,
      title: 'Servers',
      leadingIcon: Icons.cloud_outlined,
      alignment: alignment,
      margin: margin,
      anchorContext: anchorContext,
      child: ListView(
        padding: const EdgeInsets.all(8),
        shrinkWrap: true,
        children: providers.entries.map((entry) {
          final key = entry.key;
          final provider = entry.value;
          final isCurrent = key == currentProviderId;
          final fallbackName = provider['name']?.toString();
          final contentLanguage = _contentLanguage(provider);
          final flags = StreamProviderDisplay.countryFlags(
            key,
            contentLanguage: contentLanguage,
          );
          return PlayerPopupListTile(
            badge: flags.isEmpty ? null : flags,
            label: StreamProviderDisplay.playerLabel(
              key,
              fallbackName: fallbackName,
              contentLanguage: contentLanguage,
            ),
            selected: isCurrent,
            onTap: () async {
              PlayerPopupPanel.dismiss();
              if (!isCurrent) await onSelect(key);
            },
          );
        }).toList(),
      ),
    );
  }

  static String snackbarLabel(String providerId, dynamic provider) {
    final fallbackName = switch (provider) {
      final Map<String, dynamic> map => map['name']?.toString(),
      _ => null,
    };
    return StreamProviderDisplay.playerListLabel(
      providerId,
      fallbackName: fallbackName,
      contentLanguage: provider is Map<String, dynamic>
          ? _contentLanguage(provider)
          : null,
    );
  }

  static List<String>? _contentLanguage(Map<String, dynamic> provider) {
    final raw = provider['contentLanguage'];
    if (raw is! List) return null;
    return raw.map((e) => e.toString()).toList();
  }
}
