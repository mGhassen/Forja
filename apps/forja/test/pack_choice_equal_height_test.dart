import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/settings/packs/forja_pack_choice_cards.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

void main() {
  testWidgets(
    'Official and Community pack cards share height with unequal subtitles',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: ShellPaintScope(
                useTvFocus: true,
                scaleOnHover: false,
                usesTvDensity: true,
                focusStyled: (_, {required focused}) => focused,
                child: ForjaPackChoiceCards(
                  onInstallOfficial: () {},
                  onBrowseCommunity: () {},
                  communitySubtitle:
                      'Choose packs on your phone\nhttps://www.forjahq.xyz/plugins',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final officialCard = tester.getSize(
        find
            .ancestor(
              of: find.text('Official packs'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final communityCard = tester.getSize(
        find
            .ancestor(
              of: find.text('Community Packs'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(officialCard.height, communityCard.height);
    },
  );
}
