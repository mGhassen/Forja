import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// One catalog details rail — title + horizontal cards (props only).
class DetailsRailSectionData {
  const DetailsRailSectionData({
    required this.id,
    required this.title,
    required this.cards,
  });

  final String id;
  final String title;
  final List<Widget> cards;
}

/// Horizontal rail row used under details heroes.
class DetailsRailSection extends StatelessWidget {
  const DetailsRailSection({
    super.key,
    required this.title,
    required this.cards,
    required this.rowHeight,
    this.compactTop = true,
  });

  final String title;
  final List<Widget> cards;
  /// Host passes portrait poster card height; a short fixed row clips to near-square.
  final double rowHeight;
  final bool compactTop;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(
        top: compactTop ? 0 : ShellTokens.homeSectionTitleTop,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ShellTokens.homeSectionHorizontalPadding,
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: ForjaShellColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: rowHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: ShellTokens.homeSectionHorizontalPadding,
              ),
              itemCount: cards.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => cards[i],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stack of [DetailsRailSection] widgets.
class DetailsRails extends StatelessWidget {
  const DetailsRails({
    super.key,
    required this.sections,
    required this.rowHeight,
  });

  final List<DetailsRailSectionData> sections;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 24),
          DetailsRailSection(
            title: sections[i].title,
            cards: sections[i].cards,
            rowHeight: rowHeight,
          ),
        ],
      ],
    );
  }
}
