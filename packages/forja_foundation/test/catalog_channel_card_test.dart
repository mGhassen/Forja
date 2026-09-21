import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/channel_card_tokens.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';
import 'package:forja_foundation/widgets/catalog/catalog_channel_card.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: forjaThemeData(),
    home: Scaffold(
      body: ShellPaintScope(
        useTvFocus: false,
        scaleOnHover: true,
        focusStyled: (_, {required focused}) => focused,
        usesTvDensity: false,
        child: Center(child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('logo slot height stays fixed when the title is long', (
    tester,
  ) async {
    const cardW = 160.0;
    const cardH = 180.0;
    final expectedLogoH = cardH -
        ChannelCardTokens.titleBarHeight -
        ChannelCardTokens.epgSlotHeight;

    Future<Size> logoSizeFor(String title) async {
      await tester.pumpWidget(
        _wrap(
          CatalogChannelCard(
            title: title,
            imageUrl: '',
            width: cardW,
            height: cardH,
          ),
        ),
      );
      await tester.pump();
      // Logo placeholder is the only Icon in the logo Expanded stack.
      final icon = find.byIcon(Icons.tv_rounded);
      expect(icon, findsOneWidget);
      // Walk up to the Expanded logo region via the card's outer size math:
      // logo area = card height − fixed title − fixed EPG.
      final cardBox = tester.getSize(find.byType(CatalogChannelCard));
      expect(cardBox.height, cardH);
      expect(cardBox.width, cardW);
      // Placeholder centers in the logo slot — its parent expand box height
      // equals the remaining column space.
      final placeholderCenter = tester.getCenter(icon);
      final cardTopLeft = tester.getTopLeft(find.byType(CatalogChannelCard));
      final logoBottom = cardTopLeft.dy + expectedLogoH;
      expect(placeholderCenter.dy, lessThan(logoBottom));
      expect(
        placeholderCenter.dy,
        closeTo(cardTopLeft.dy + expectedLogoH / 2, 1.0),
      );
      return Size(cardW, expectedLogoH);
    }

    final short = await logoSizeFor('VIP - NO EVENT');
    final long = await logoSizeFor(
      '##### GOLDEN EVENTS ##### EXTRA LONG TITLE THAT WOULD WRAP',
    );
    expect(short.height, expectedLogoH);
    expect(long.height, expectedLogoH);
    expect(long.height, short.height);
  });
}
