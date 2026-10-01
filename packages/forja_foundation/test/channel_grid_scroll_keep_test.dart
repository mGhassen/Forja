import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/chrome/catalog_poster_grid.dart';

void main() {
  testWidgets(
    'channel grid keep-visible scroll does not pin the focused row to the top',
    (tester) async {
      final scroll = ScrollController();
      const viewportH = 400.0;
      const layout = CatalogPosterGridLayout(
        columns: 4,
        cardW: 120,
        cardH: 120,
        gap: 10,
        leading: 8,
        rightPad: 8,
        topPad: 8,
      );
      const rows = 20;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: viewportH,
              child: ListView.builder(
                controller: scroll,
                itemCount: rows,
                itemExtent: layout.cardH + layout.gap,
                itemBuilder: (context, i) => Text('row-$i'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mid-list so the next row is already on screen.
      final midRow = 6;
      scroll.jumpTo(
        layout.itemTop(midRow * layout.columns).clamp(
          0.0,
          scroll.position.maxScrollExtent,
        ),
      );
      await tester.pump();
      final offsetBefore = scroll.offset;

      layout.scrollItemKeepVisible(
        scroll,
        (midRow + 1) * layout.columns,
      );
      await tester.pump();
      expect(
        scroll.offset,
        offsetBefore,
        reason: 'next row already on screen must not scroll',
      );

      // Row well below the fold.
      final clipped = midRow + 8;
      layout.scrollItemKeepVisible(scroll, clipped * layout.columns);
      await tester.pump();
      expect(scroll.offset > offsetBefore, isTrue);
      final pinnedTop = layout.itemTop(clipped * layout.columns);
      expect(
        (scroll.offset - pinnedTop).abs() > 1.0,
        isTrue,
        reason: 'clipped row must not snap to the first line',
      );
    },
  );
}
