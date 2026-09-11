import 'package:flutter/material.dart';
import 'package:forja_foundation/widgets/details/details_hero.dart';

/// Full-bleed match / list-entry details paint — hero + overlays (Zone A).
///
/// Host wires stream panels, TV focus, and resolve into [belowActionRow] /
/// [overlay].
class MatchDetailsPage extends StatelessWidget {
  const MatchDetailsPage({
    super.key,
    required this.backgroundColor,
    required this.hero,
    this.overlay,
  });

  final Color backgroundColor;
  final DetailsHero hero;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          hero,
          ?overlay,
        ],
      ),
    );
  }
}
