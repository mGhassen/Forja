import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/widgets/catalog/poster_rail.dart';

/// Horizontal "More Like This" row — host builds [cards].
class DetailsRecommendationsSection extends StatelessWidget {
  const DetailsRecommendationsSection({
    super.key,
    required this.cards,
    this.title = 'More Like This',
    this.rowHeight = 180,
    this.gap = 12,
  });

  final List<Widget> cards;
  final String title;
  final double rowHeight;
  final double gap;

  static const TextStyle titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  );

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            bottom: DetailsTokens.sectionTitleGap,
          ),
          child: Text(title, style: titleStyle),
        ),
        FocusTraversalGroup(
          child: SizedBox(
            height: rowHeight,
            child: ListView.separated(
              // Match Home HorizontalScroller — hover/focus scale paints past
              // the row box instead of clipping into section margins.
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: cards.length,
              separatorBuilder: (_, _) => SizedBox(width: gap),
              itemBuilder: (context, index) => cards[index],
            ),
          ),
        ),
      ],
    );
  }
}

/// Poster rail from absolute image URLs (no host Movie).
Widget catalogPosterRail({
  required List<PosterItem> items,
  double itemWidth = 120,
  double itemHeight = 180,
}) {
  return PosterRail(
    items: items,
    itemWidth: itemWidth,
    itemHeight: itemHeight,
  );
}
