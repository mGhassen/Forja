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
  testWidgets('logo paints inside a fixed 1:1 AspectRatio frame', (tester) async {
    const cardW = 160.0;
    const cardH = 180.0;

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

    final frame = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(frame.aspectRatio, ChannelCardTokens.logoAspectRatio);

    final frameSize = tester.getSize(find.byType(AspectRatio));
    expect(frameSize.width, closeTo(frameSize.height, 0.5));
    // Square is bounded by the padded logo band, not the full card face.
    expect(frameSize.width, lessThan(cardW));
    expect(
      frameSize.width,
      greaterThan(cardW * 0.5),
    );

    // Empty URL still shows the TV placeholder inside that fixed frame.
    expect(find.byIcon(Icons.tv_rounded), findsOneWidget);
  });

  testWidgets('long titles do not change the 1:1 logo frame size', (
    tester,
  ) async {
    const cardW = 160.0;
    const cardH = 180.0;

    Future<Size> frameSizeFor(String title) async {
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
      return tester.getSize(find.byType(AspectRatio));
    }

    final short = await frameSizeFor('VIP - NO EVENT');
    final long = await frameSizeFor(
      '##### GOLDEN EVENTS ##### EXTRA LONG TITLE THAT WOULD WRAP',
    );
    expect(short, long);
    expect(short.width, closeTo(short.height, 0.5));
  });
}
