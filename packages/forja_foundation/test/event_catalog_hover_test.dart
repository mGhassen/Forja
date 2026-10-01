import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/catalog/event_card.dart';

void main() {
  testWidgets('merged catalogs replace the inside of the event card', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EventCard(
          title: 'Finland vs Belarus',
          width: 280,
          height: 160,
          homeTeam: 'Finland',
          awayTeam: 'Belarus',
          live: true,
          categoryLabel: 'Football',
          viewers: 468,
          showCatalogs: true,
          catalogs: [
            'Streamed',
            'PPV',
            'Live Soccer TV',
            'LiveOnSat',
            'StreamFree',
            'Streamic',
            'WatchFooty',
          ],
        ),
      ),
    );

    expect(find.text('Finland vs Belarus'), findsNothing);
    expect(find.text('FOOTBALL'), findsNothing);
    expect(find.text('● LIVE'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(EventCard),
        matching: find.byType(ListView),
      ),
      findsOneWidget,
    );
    expect(find.text('PPV'), findsOneWidget);
    expect(find.text('WatchFooty'), findsOneWidget);
  });

  testWidgets('event card keeps the match face until catalogs are shown', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EventCard(
          title: 'Finland vs Belarus',
          width: 280,
          height: 160,
          catalogs: ['PPV', 'StreamFree'],
        ),
      ),
    );

    expect(find.text('Finland vs Belarus'), findsOneWidget);
    expect(find.text('PPV'), findsNothing);
  });
}
