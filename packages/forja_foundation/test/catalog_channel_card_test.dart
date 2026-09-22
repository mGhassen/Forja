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

  testWidgets('TV density uses the leanback card title size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: forjaThemeData(),
        home: Scaffold(
          body: ShellPaintScope(
            useTvFocus: true,
            scaleOnHover: false,
            focusStyled: (_, {required focused}) => focused,
            usesTvDensity: true,
            child: const Center(
              child: CatalogChannelCard(
                title: 'VIP - NO EVENT',
                imageUrl: '',
                width: 110,
                height: 122,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final text = tester.widget<Text>(find.text('VIP - NO EVENT'));
    expect(
      text.style?.fontSize,
      ChannelCardTokens.cardTitleFontSizeTv,
    );
  });

  testWidgets('emphasize flip does not call onInteractiveActive', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        CatalogChannelCard(
          title: 'A',
          imageUrl: '',
          width: 160,
          height: 180,
          emphasize: false,
          onInteractiveActive: (_) => calls++,
        ),
      ),
    );
    await tester.pump();
    expect(calls, 0);

    await tester.pumpWidget(
      _wrap(
        CatalogChannelCard(
          title: 'A',
          imageUrl: '',
          width: 160,
          height: 180,
          emphasize: true,
          onInteractiveActive: (_) => calls++,
        ),
      ),
    );
    await tester.pump();
    expect(calls, 0);
  });

  testWidgets(
    'parent setState from onInteractiveActive during emphasize rebuild is safe',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: forjaThemeData(),
          home: Scaffold(
            body: ShellPaintScope(
              useTvFocus: false,
              scaleOnHover: true,
              focusStyled: (_, {required focused}) => focused,
              usesTvDensity: false,
              child: const Center(child: _EmphasizeSelectHarness()),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Play'));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('VIP EVENTS'), findsOneWidget);
    },
  );
}

class _EmphasizeSelectHarness extends StatefulWidget {
  const _EmphasizeSelectHarness();

  @override
  State<_EmphasizeSelectHarness> createState() =>
      _EmphasizeSelectHarnessState();
}

class _EmphasizeSelectHarnessState extends State<_EmphasizeSelectHarness> {
  int _selected = -1;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => setState(() => _selected = 0),
          child: const Text('Play'),
        ),
        CatalogChannelCard(
          title: 'VIP EVENTS',
          imageUrl: '',
          width: 160,
          height: 180,
          emphasize: _selected == 0,
          onInteractiveActive: (active) {
            // Old bug: card notified parent from didUpdateWidget(emphasize),
            // and parent setState mid-build → red error tile.
            if (!mounted) return;
            if (active && _selected != 0) {
              setState(() => _selected = 0);
            } else if (!active && _selected == 0) {
              setState(() => _selected = -1);
            }
          },
        ),
      ],
    );
  }
}
