import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/services/external_player_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rust/rust.dart';

typedef PlayerSwitchHandler = Future<void> Function(
  Duration resumePosition, {
  BuiltInPlayerEngine? builtInEngine,
  String? externalPlayer,
  String? streamUrl,
  Map<String, String>? headers,
  String? activeProvider,
  List<StreamSource>? sources,
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
      padding: const EdgeInsets.all(8),
      shrinkWrap: true,
      physics: physics ?? const ClampingScrollPhysics(),
      children: [
        if (Platform.isAndroid) ...[
          const _SectionLabel('Built-in engine'),
          ...builtInPlayerEngineOptions.map(
            (engine) => PlayerPopupListTile(
              label: engine.displayName,
              selected: usingBuiltIn && engine == builtInEngine,
              onTap: () async {
                onDismiss?.call();
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
            onTap: () async {
              onDismiss?.call();
              if (usingBuiltIn) return;
              await onSelect(builtInEngine: builtInEngine);
            },
          ),
          const SizedBox(height: 8),
          const _SectionLabel('External app'),
        ],
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
          children: players
              .map(
                (player) => PlayerPopupListTile(
                  label: player.displayName,
                  selected: !widget.usingBuiltIn &&
                      widget.externalPlayerName == player.displayName,
                  onTap: () async {
                    widget.onDismiss?.call();
                    if (!widget.usingBuiltIn &&
                        widget.externalPlayerName == player.displayName) {
                      return;
                    }
                    await widget.onSelect(externalPlayer: player.displayName);
                  },
                ),
              )
              .toList(growable: false),
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
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: ForjaShellColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
