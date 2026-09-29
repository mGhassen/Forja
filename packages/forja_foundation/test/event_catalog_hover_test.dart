import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/blocks/catalog/catalog_cards_grid.dart';
import 'package:forja_foundation/widgets/catalog/event_catalog_hover.dart';

void main() {
  testWidgets('catalog list stays hidden until 2s hover', (tester) async {
    var armed = false;
    Future<void> pump() {
      return tester.pumpWidget(
        MaterialApp(
          home: EventCatalogHover(
            catalogs: const ['PPV', 'ESPN'],
            armed: armed,
            child: const SizedBox(width: 120, height: 48, child: Text('Match')),
          ),
        ),
      );
    }

    await pump();
    expect(find.text('PPV'), findsNothing);

    armed = true;
    await pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('PPV'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Catalogs'), findsOneWidget);
    expect(find.text('PPV'), findsOneWidget);
    expect(find.text('ESPN'), findsOneWidget);

    armed = false;
    await pump();
    await tester.pump();
    expect(find.text('PPV'), findsNothing);
  });

  testWidgets('schedule list shows merged catalogs after a 2s hover', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 320,
            child: CatalogCardsGrid(
              cardKind: 'list',
              items: const [
                {
                  'id': 'm1',
                  'paint': {
                    'props': {
                      'title': 'Arsenal vs Chelsea',
                      'catalogs': ['PPV', 'StreamFree'],
                    },
                  },
                },
              ],
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.text('Arsenal vs Chelsea')));
    await tester.pump();
    await tester.pump();
    expect(find.text('StreamFree'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('PPV'), findsOneWidget);
    expect(find.text('StreamFree'), findsOneWidget);
  });
}
