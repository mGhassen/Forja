import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/chrome/catalog_menu.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';

void main() {
  testWidgets('CatalogMenu toggle clear paints no tab active', (tester) async {
    final selections = <String, String>{'kind': 'asian_drama'};
    final revision = ValueNotifier(0);

    Color? labelColor(String label) {
      final text = tester.widget<Text>(find.text(label));
      return text.style?.color;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: revision,
            builder: (context, _) {
              return LayoutScope(
                selections: Map<String, String>.from(selections),
                widgetSpecs: const {},
                onSelect: (id, value, {required bool toggle}) {
                  if (toggle) {
                    final current = selections[id];
                    if (current == value) {
                      selections.remove(id);
                    } else {
                      selections[id] = value;
                    }
                  } else {
                    selections[id] = value;
                  }
                  revision.value++;
                },
                child: CatalogMenu(
                  spec: {
                    'id': 'kind',
                    'toggle': true,
                    'items': [
                      {'id': 'movie', 'label': 'Film'},
                      {'id': 'tv', 'label': 'Series'},
                      {'id': 'asian_drama', 'label': 'Asian Drama'},
                    ],
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Asian Drama'));
    await tester.pumpAndSettle();

    expect(selections.containsKey('kind'), isFalse);
    // Cleared selection must not paint Film (index 0) as active.
    expect(labelColor('Film'), labelColor('Asian Drama'));
  });
}
