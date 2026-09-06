import 'package:flutter/material.dart';
import 'package:forja/shell/shell_bus.dart';

/// While a fullscreen player owns the SoC, skip building [builder] so poster /
/// backdrop [Image] widgets unmount. Ancestor [State] stays alive for Back /
/// TV focus (same pattern as IPTV catalog freeze).
///
/// Use a builder — not a pre-built [child] — so heavy chrome is not constructed
/// while the player is active.
class PlayerSurfaceChromeStub extends StatelessWidget {
  const PlayerSurfaceChromeStub({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ShellBus.playerSurfaceActive,
      builder: (context, playerActive, _) {
        if (playerActive) {
          return const ColoredBox(color: Colors.black);
        }
        return builder(context);
      },
    );
  }
}
