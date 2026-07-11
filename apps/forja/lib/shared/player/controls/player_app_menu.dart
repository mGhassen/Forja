import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/services/external_player_service.dart';
import 'package:rust/rust.dart';

typedef PlayerSwitchHandler = Future<void> Function(
  Duration resumePosition, {
  BuiltInPlayerEngine? builtInEngine,
  String? externalPlayer,
});

typedef PlayerMenuSelectHandler = Future<void> Function({
  BuiltInPlayerEngine? builtInEngine,
  String? externalPlayer,
});

/// In-player picker: built-in engine (Android) + external apps.
class PlayerAppMenu {
  static void show(
    BuildContext context, {
    required bool usingBuiltIn,
    required BuiltInPlayerEngine builtInEngine,
    String? externalPlayerName,
    required PlayerMenuSelectHandler onSelect,
    BuildContext? anchorContext,
  }) {
    PlayerPopupPanel.show(
      context: context,
      title: 'Player',
      leadingIcon: Icons.smart_display_outlined,
      anchorContext: anchorContext,
      child: ListView(
        padding: const EdgeInsets.all(8),
        shrinkWrap: true,
        children: [
          if (Platform.isAndroid) ...[
            const _SectionLabel('Built-in engine'),
            ...builtInPlayerEngineOptions.map(
              (engine) => PlayerPopupListTile(
                label: engine.displayName,
                selected: usingBuiltIn && engine == builtInEngine,
                onTap: () async {
                  PlayerPopupPanel.dismiss();
                  if (usingBuiltIn && engine == builtInEngine) return;
                  await onSelect(builtInEngine: engine);
                },
              ),
            ),
            const SizedBox(height: 8),
            const _SectionLabel('External app'),
          ] else ...[
            const _SectionLabel('Built-in'),
            PlayerPopupListTile(
              label: 'Built-in Player',
              selected: usingBuiltIn,
              onTap: () {
                PlayerPopupPanel.dismiss();
              },
            ),
            const SizedBox(height: 8),
            const _SectionLabel('External app'),
          ],
          ...ExternalPlayerService.availablePlayers.map(
            (player) => PlayerPopupListTile(
              label: player.displayName,
              selected: !usingBuiltIn && externalPlayerName == player.displayName,
              onTap: () async {
                PlayerPopupPanel.dismiss();
                if (!usingBuiltIn && externalPlayerName == player.displayName) {
                  return;
                }
                await onSelect(externalPlayer: player.displayName);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
