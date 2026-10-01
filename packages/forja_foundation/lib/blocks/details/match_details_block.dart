import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/props_map.dart';
import 'package:forja_foundation/widgets/details/details_hero.dart';

/// Prebuilt match / live-entry details: full-bleed [DetailsHero] from props.
///
/// ```json
/// {
///   "type": "matchDetails",
///   "props": {
///     "title": "Home vs Away",
///     "backdropUrl": "…",
///     "subtitle": "Premier League",
///     "metaParts": ["20:00", "Live"],
///     "contentScrim": true
///   }
/// }
/// ```
/// Host injects [actionRow] / [belowActionRow] / [overlay] only.
class MatchDetailsPage extends StatelessWidget {
  const MatchDetailsPage({
    super.key,
    required this.backgroundColor,
    required this.hero,
    this.overlay,
  });

  /// Composes [DetailsHero] from props (not an empty hero slot).
  static Widget fromProps(
    Map<String, dynamic> props, {
    Widget? actionRow,
    Widget? belowActionRow,
    Widget? overlay,
    Color? fallbackBackground,
  }) {
    final bg = propsColor(props, 'backgroundColor') ??
        fallbackBackground ??
        const Color(0xFF141414);
    final hero = DetailsHero(
      backdropUrl: propsStringOr(props, 'backdropUrl', ''),
      backdropUrls: propsStringList(props, 'backdropUrls'),
      title: propsStringOr(props, 'title', ''),
      subtitle: propsString(props, 'subtitle'),
      genres: propsStringList(props, 'genres'),
      metaParts: propsStringList(props, 'metaParts'),
      rating: propsNum(props, 'rating'),
      overview: propsStringOr(props, 'overview', ''),
      logoUrl: propsString(props, 'logoUrl'),
      actionRow: actionRow,
      belowActionRow: belowActionRow,
      belowActionRowFullWidth: propsBool(props, 'belowActionRowFullWidth'),
      belowActionRowGap: propsNumOr(props, 'belowActionRowGap', 20),
      scaleActionRow: propsBool(props, 'scaleActionRow', true),
      contentScrim: propsBool(props, 'contentScrim', true),
      enableKenBurns: propsBool(props, 'enableKenBurns', true),
      tvDensity: propsBool(props, 'tvDensity'),
      plainTitle: propsBool(props, 'plainTitle'),
      selectableTitle: propsBool(props, 'selectableTitle'),
      chromeOnly: propsBool(props, 'chromeOnly'),
      height: propsNum(props, 'height'),
      factsValueMaxLines: propsInt(props, 'factsValueMaxLines') ?? 1,
    );
    return MatchDetailsPage(
      backgroundColor: bg,
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
