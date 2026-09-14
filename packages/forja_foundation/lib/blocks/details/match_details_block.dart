import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/props_map.dart';

/// Full-bleed match / list-entry details paint — hero + overlays (RFC-112).
///
/// Pack JSON: `{ "type": "matchDetails", "props": { "backgroundColor": "#…" } }`
/// with hero/overlay as painted slots.
class MatchDetailsPage extends StatelessWidget {
  const MatchDetailsPage({
    super.key,
    required this.backgroundColor,
    required this.hero,
    this.overlay,
  });

  factory MatchDetailsPage.fromProps(
    Map<String, dynamic> props, {
    required Widget hero,
    Widget? overlay,
    Color? fallbackBackground,
  }) {
    return MatchDetailsPage(
      backgroundColor:
          propsColor(props, 'backgroundColor') ??
          fallbackBackground ??
          Colors.black,
      hero: hero,
      overlay: overlay,
    );
  }

  final Color backgroundColor;
  final Widget hero;
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
