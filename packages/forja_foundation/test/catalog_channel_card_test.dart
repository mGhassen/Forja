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
  testWidgets('logo fills the full logo band — no inset AspectRatio square', (
    tester,
  ) async {
    const cardW = 160.0;
    const cardH = 180.0;
    final expectedBandH = cardH -
        ChannelCardTokens.titleBarHeight -
        ChannelCardTokens.epgSlotHeight;

    await tester.pumpWidget(
      _wrap(
        const CatalogChannelCard(
          title: 'VIP - NO EVENT',
          imageUrl: '',
          width: cardW,
          height: cardH,
        ),
      ),
    );
    await tester.pump();

    // No nested 1:1 frame — logo band is the full Expanded face.
    expect(find.byType(AspectRatio), findsNothing);

    // Empty URL still shows the TV placeholder in that band.
    expect(find.byIcon(Icons.tv_rounded), findsOneWidget);
    final placeholderCenter = tester.getCenter(find.byIcon(Icons.tv_rounded));
    final cardTop = tester.getTopLeft(find.byType(CatalogChannelCard)).dy;
    expect(
      placeholderCenter.dy,
      closeTo(cardTop + expectedBandH / 2, 2.0),
    );
  });

  testWidgets('long titles do not change the logo band height', (tester) async {
    const cardW = 160.0;
    const cardH = 180.0;

    Future<double> placeholderY(String title) async {
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
      return tester.getCenter(find.byIcon(Icons.tv_rounded)).dy;
    }

    final shortY = await placeholderY('VIP - NO EVENT');
    final longY = await placeholderY(
      '##### GOLDEN EVENTS ##### EXTRA LONG TITLE THAT WOULD WRAP',
    );
    expect(longY, closeTo(shortY, 0.5));
  });
}
