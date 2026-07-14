import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/services/external_player_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rust/rust.dart';

typedef PlayerSwitchHandler =
    Future<void> Function(
      Duration resumePosition, {
      BuiltInPlayerEngine? builtInEngine,
      String? externalPlayer,
      String? streamUrl,
      Map<String, String>? headers,
      String? activeProvider,
      List<StreamSource>? sources,
    });

typedef PlayerMenuSelectHandler =
    Future<void> Function({
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
    bool centered = false,
  }) {
    PlayerPopupPanel.show(
      context: context,
      title: 'Player',
      leadingIcon: Icons.smart_display_outlined,
      anchorContext: anchorContext,
      centered: centered,
      child: buildPickerList(
        usingBuiltIn: usingBuiltIn,
        builtInEngine: builtInEngine,
        externalPlayerName: externalPlayerName,
        onSelect: onSelect,
        onDismiss: PlayerPopupPanel.dismiss,
      ),
    );
  }

  static Widget buildPickerList({
    required bool usingBuiltIn,
    required BuiltInPlayerEngine builtInEngine,
    String? externalPlayerName,
    required PlayerMenuSelectHandler onSelect,
    VoidCallback? onDismiss,
    ScrollPhysics? physics,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      shrinkWrap: true,
      physics: physics ?? const ClampingScrollPhysics(),
      children: [
        const _SectionLabel('Built-in'),
        if (Platform.isAndroid)
          for (var i = 0; i < builtInPlayerEngineOptions.length; i++) ...[
            if (i != 0) const SizedBox(height: 6),
            PlayerPopupOptionChip(
              label: builtInPlayerEngineOptions[i].displayName,
              selected:
                  usingBuiltIn &&
                  builtInPlayerEngineOptions[i] == builtInEngine,
              expanded: true,
              onTap: () async {
                onDismiss?.call();
                if (usingBuiltIn &&
                    builtInPlayerEngineOptions[i] == builtInEngine) {
                  return;
                }
                await onSelect(builtInEngine: builtInPlayerEngineOptions[i]);
              },
            ),
          ]
        else
          PlayerPopupOptionChip(
            label: 'Built-in Player',
            selected: usingBuiltIn,
            expanded: true,
            onTap: () async {
              onDismiss?.call();
              if (usingBuiltIn) return;
              await onSelect(builtInEngine: builtInEngine);
            },
          ),
        const SizedBox(height: 14),
        const _SectionLabel('External app'),
        _InstalledExternalPlayers(
          usingBuiltIn: usingBuiltIn,
          externalPlayerName: externalPlayerName,
          onSelect: onSelect,
          onDismiss: onDismiss,
        ),
      ],
    );
  }
}

class _InstalledExternalPlayers extends StatefulWidget {
  const _InstalledExternalPlayers({
    required this.usingBuiltIn,
    required this.externalPlayerName,
    required this.onSelect,
    this.onDismiss,
  });

  final bool usingBuiltIn;
  final String? externalPlayerName;
  final PlayerMenuSelectHandler onSelect;
  final VoidCallback? onDismiss;

  @override
  State<_InstalledExternalPlayers> createState() =>
      _InstalledExternalPlayersState();
}

class _InstalledExternalPlayersState extends State<_InstalledExternalPlayers> {
  late final Future<List<ExternalPlayer>> _playersFuture =
      ExternalPlayerService.getInstalledPlayers();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ExternalPlayer>>(
      future: _playersFuture,
      builder: (context, snapshot) {
        final players = snapshot.data;
        if (players == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (players.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text(
              'No external players installed',
              style: GoogleFonts.inter(
                color: ForjaShellColors.textSecondary,
                fontSize: 12,
              ),
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < players.length; i++) ...[
              if (i != 0) const SizedBox(height: 6),
              PlayerPopupOptionChip(
                label: players[i].displayName,
                selected:
                    !widget.usingBuiltIn &&
                    widget.externalPlayerName == players[i].displayName,
                expanded: true,
                onTap: () async {
                  widget.onDismiss?.call();
                  if (!widget.usingBuiltIn &&
                      widget.externalPlayerName == players[i].displayName) {
                    return;
                  }
                  await widget.onSelect(externalPlayer: players[i].displayName);
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          color: ForjaShellColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.55,
        ),
      ),
    );
  }
}
