import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/blocks/catalog/catalog_cards_grid.dart';
import 'package:forja_foundation/widgets/catalog/event_card.dart';
import 'package:forja_foundation/widgets/chrome/catalog_poster_grid.dart';

void main() {
  test('scroll offset keeps the item at the same screen Y after reflow', () {
    expect(
      CatalogPosterGridLayout.scrollOffsetKeepingScreenY(
        oldItemTop: 400,
        oldOffset: 250,
        newItemTop: 900,
        maxScrollExtent: 5000,
      ),
      750,
    );
    expect(
      CatalogPosterGridLayout.scrollOffsetKeepingScreenY(
        oldItemTop: 100,
        oldOffset: 0,
        newItemTop: 40,
        maxScrollExtent: 800,
      ),
      0,
    );
    expect(
      CatalogPosterGridLayout.scrollOffsetKeepingScreenY(
        oldItemTop: 200,
        oldOffset: 50,
        newItemTop: 4000,
        maxScrollExtent: 500,
      ),
      500,
    );
  });

  test('item top follows column row stride', () {
    const layout = CatalogPosterGridLayout(
      columns: 4,
      cardW: 200,
      cardH: 100,
      gap: 10,
      leading: 16,
      rightPad: 16,
      topPad: 4,
    );
    expect(layout.itemTop(0), 4);
    expect(layout.itemTop(5), 4 + 110);
  });

  testWidgets(
    'narrowing the event grid keeps the selected card on screen',
    (tester) async {
      const wide = 1200.0;
      const narrow = 480.0;
      const height = 420.0;
      const selected = 'm18';

      Future<void> pump({required double width, String? selectedId}) {
        return tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                height: height,
                child: CatalogCardsGrid(
                  cardKind: 'event',
                  selectedItemId: selectedId,
                  items: [
                    for (var i = 0; i < 30; i++)
                      {'id': 'm$i', 'title': 'Match $i'},
                  ],
                ),
              ),
            ),
          ),
        );
      }

      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pump(width: wide);
      await tester.pump();

      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(640);
      await tester.pump();

      final card = find.ancestor(
        of: find.text('Match 18'),
        matching: find.byType(EventCard),
      );
      expect(card, findsOneWidget);
      final before = tester.getRect(card).top;
      final viewportTop = tester.getTopLeft(find.byType(CatalogCardsGrid)).dy;
      expect(scrollable.position.pixels, greaterThan(100));
      expect(before, greaterThan(viewportTop));

      await pump(width: narrow, selectedId: selected);
      await tester.pump();

      expect(card, findsOneWidget);
      final after = tester.getRect(card).top;
      expect(
        (after - before).abs(),
        lessThan(12),
        reason: 'selected card should stay put when the grid reflows',
      );
      expect(after, greaterThan(viewportTop));
      expect(after, lessThan(viewportTop + height));

      await pump(width: wide);
      await tester.pump();

      expect(card, findsOneWidget);
      final closed = tester.getRect(card).top;
      expect(
        (closed - after).abs(),
        lessThan(12),
        reason: 'closing the panel should keep the same card on screen',
      );
    },
  );
}
