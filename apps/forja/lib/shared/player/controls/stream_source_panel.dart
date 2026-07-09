import 'package:flutter/material.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:rust/rust.dart';

class StreamSourcePanel {
  static void show(
    BuildContext context, {
    required List<StreamSource> sources,
    required String? currentUrl,
    required String? current111477FileUrl,
    required bool is111477,
    required Future<void> Function(StreamSource source, int index) onSelect,
    Alignment alignment = Alignment.bottomRight,
    EdgeInsets margin = const EdgeInsets.only(right: 16, bottom: 88),
  }) {
    if (sources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No sources available'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    PlayerPopupPanel.show(
      context: context,
      title: 'Sources',
      leadingIcon: Icons.dns_outlined,
      alignment: alignment,
      margin: margin,
      child: ListView(
        padding: const EdgeInsets.all(8),
        shrinkWrap: true,
        children: sources.asMap().entries.map((entry) {
          final index = entry.key;
          final source = entry.value;
          final isCurrent = is111477
              ? source.url == current111477FileUrl
              : source.url == currentUrl;
          return PlayerPopupListTile(
            badge: source.type.toUpperCase(),
            label: source.title,
            selected: isCurrent,
            onTap: () async {
              PlayerPopupPanel.dismiss();
              if (!isCurrent) await onSelect(source, index);
            },
          );
        }).toList(),
      ),
    );
  }
}
