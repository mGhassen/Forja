import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/kit/paint_tree.dart';
import 'package:forja_foundation/forja_foundation.dart';

/// RFC-112 — PackPaintTree mounts catalog page blocks. Synthetic only.
void main() {
  testWidgets('columnsHeader paints top chrome + side rail + empty',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: forjaThemeData(),
        home: Scaffold(
          body: PackPaintTree(
            pluginId: 'test-hub-a',
            spec: {
              'type': 'columnsHeader',
              'props': {
                'actions': [
                  {'id': 'refresh', 'label': 'Refresh'},
                ],
                'sideItems': [
                  {'id': 'all', 'label': 'All'},
                  {'id': 'news', 'label': 'News'},
                ],
                'emptyTitle': 'No channels',
              },
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Refresh'), findsWidgets);
    expect(find.text('News'), findsWidgets);
    expect(find.text('No channels'), findsOneWidget);
  });

  testWidgets('topBody paints chrome + kinds + empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: forjaThemeData(),
        home: Scaffold(
          body: PackPaintTree(
            pluginId: 'test-hub-a',
            spec: {
              'type': 'topBody',
              'props': {
                'actions': [
                  {'id': 'horizon', 'label': 'Today'},
                ],
                'kindItems': [
                  {'id': 'all', 'label': 'All'},
                  {'id': 'football', 'label': 'Football'},
                ],
                'emptyTitle': 'No matches',
              },
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Football'), findsWidgets);
    expect(find.text('No matches'), findsOneWidget);
  });

  testWidgets('tabsCards paints menu + tabs + empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: forjaThemeData(),
        home: Scaffold(
          body: PackPaintTree(
            pluginId: 'test-hub-a',
            spec: {
              'type': 'tabsCards',
              'props': {
                'menuItems': [
                  {'id': 'movie', 'label': 'Film'},
                ],
                'tabItems': [
                  {'id': 'watching', 'label': 'Watching'},
                ],
                'emptyTitle': 'Your list is empty',
              },
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Film'), findsWidgets);
    expect(find.text('Watching'), findsWidgets);
    expect(find.text('Your list is empty'), findsOneWidget);
  });
}
