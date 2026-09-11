import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';
import 'package:forja_foundation/widgets/details/details_hero.dart';
import 'package:forja_foundation/widgets/details/play_row.dart';

/// Details page template — hero + play row + body (RFC-106 G6).
class DetailsBlock extends StatelessWidget {
  const DetailsBlock({
    super.key,
    required this.hero,
    this.playRow,
    required this.body,
    this.scrollable = true,
  });

  final DetailsHero hero;
  final PlayRow? playRow;
  final Widget body;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        hero,
        if (playRow != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              theme.spaceLg,
              theme.spaceMd,
              theme.spaceLg,
              0,
            ),
            child: playRow,
          ),
        body,
      ],
    );

    if (!scrollable) return column;
    return SingleChildScrollView(child: column);
  }
}
