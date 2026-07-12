import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/settings/widgets/provider_priority_table.dart';
import 'package:rust/rust.dart';

import 'helpers/rust_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initRustForAppTests();
  });

  group('ProviderPriorityTable', () {
    testWidgets('renders films domain scores and baseline rank', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderPriorityTable(
              domain: SourceDomain.movies,
              title: 'Films',
              subtitle: 'Test',
              catalog: const {
                'videasy': 'Videasy',
                'vidlink': 'VidLink',
              },
              order: const ['videasy', 'vidlink'],
              onOrderChanged: (_) {},
              onReset: () {},
            ),
          ),
        ),
      );

      expect(find.text('Films'), findsOneWidget);
      expect(find.text('Videasy'), findsOneWidget);
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('Eff.'), findsOneWidget);
    });

    testWidgets('asian drama shows single kisskh row', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderPriorityTable(
              domain: SourceDomain.asianDrama,
              title: 'Asian Drama',
              subtitle: 'Test',
              catalog: const {'kisskh': 'KissKH'},
              order: const ['kisskh'],
              onOrderChanged: (_) {},
              onReset: () {},
            ),
          ),
        ),
      );

      expect(find.text('KissKH'), findsOneWidget);
      expect(find.text('kisskh'), findsOneWidget);
    });
  });
}
