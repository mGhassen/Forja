import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/kit/paint_tree.dart';

/// RFC-112 — PackPaintTree mounts catalogBody (+ child paint). Synthetic only.
void main() {
  testWidgets('catalogBody mounts child label paint', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PackPaintTree(
            pluginId: 'test-hub-a',
            spec: {
              'type': 'catalogBody',
              'props': {'bottomGap': 0},
              'children': [
                {
                  'paint': {
                    'type': 'label',
                    'props': {'title': 'Shared catalog body'},
                  },
                },
              ],
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Shared catalog body'), findsOneWidget);
  });

  testWidgets('empty block from paint type', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PackPaintTree(
            pluginId: 'test-hub-a',
            spec: {
              'type': 'empty',
              'props': {'title': 'No items'},
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('No items'), findsOneWidget);
  });

  testWidgets('catalogBody mounts posterCard child', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PackPaintTree(
            pluginId: 'test-hub-a',
            spec: {
              'type': 'catalogBody',
              'props': {'bottomGap': 0},
              'children': [
                {
                  'paint': {
                    'type': 'posterCard',
                    'props': {
                      'title': 'Poster A',
                      'imageUrl': '',
                    },
                  },
                },
              ],
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Poster A'), findsWidgets);
  });

  testWidgets('details block mounts DetailsHero from props', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PackPaintTree(
            pluginId: 'test-hub-a',
            spec: {
              'type': 'details',
              'props': {
                'title': 'Painted Details',
                'overview': 'From pack props',
                'backdropUrl': '',
              },
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Painted Details'), findsWidgets);
    expect(find.text('From pack props'), findsWidgets);
  });

  testWidgets('columnsHeader mounts header/side/body', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PackPaintTree(
            pluginId: 'test-hub-a',
            spec: {
              'type': 'columnsHeader',
              'props': {'sideWidth': 100},
              'children': [
                {
                  'paint': {
                    'type': 'label',
                    'props': {'title': 'Top chrome'},
                  },
                },
                {
                  'type': 'kit.categoryBar',
                  'id': 'cats',
                  'orientation': 'vertical',
                  'default': 'all',
                  'items': [
                    {'id': 'all', 'label': 'All'},
                    {'id': 'sports', 'label': 'Sports'},
                  ],
                },
                {
                  'paint': {
                    'type': 'label',
                    'props': {'title': 'Channels grid'},
                  },
                },
              ],
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Top chrome'), findsOneWidget);
    expect(find.text('All'), findsWidgets);
    expect(find.text('Sports'), findsWidgets);
    expect(find.text('Channels grid'), findsOneWidget);
  });

  testWidgets('topBody mounts top/bodyTop/grid', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PackPaintTree(
            pluginId: 'test-hub-a',
            spec: {
              'type': 'topBody',
              'children': [
                {
                  'paint': {
                    'type': 'label',
                    'props': {'title': 'Live chrome'},
                  },
                },
                {
                  'type': 'kit.categoryBar',
                  'id': 'kind',
                  'default': 'all',
                  'items': [
                    {'id': 'all', 'label': 'All'},
                    {'id': 'football', 'label': 'Football'},
                  ],
                },
                {
                  'paint': {
                    'type': 'label',
                    'props': {'title': 'Match grid'},
                  },
                },
              ],
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Live chrome'), findsOneWidget);
    expect(find.text('Football'), findsWidgets);
    expect(find.text('Match grid'), findsOneWidget);
  });

  testWidgets('tabsCards mounts menu/tabs/cards', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PackPaintTree(
            pluginId: 'test-hub-a',
            spec: {
              'type': 'tabsCards',
              'children': [
                {
                  'type': 'kit.menu',
                  'id': 'kind',
                  'toggle': true,
                  'items': [
                    {'id': 'movie', 'label': 'Film'},
                    {'id': 'tv', 'label': 'Series'},
                  ],
                },
                {
                  'type': 'kit.tabs',
                  'id': 'status',
                  'default': 'watching',
                  'tabs': [
                    {'id': 'watching', 'label': 'Watching'},
                    {'id': 'completed', 'label': 'Completed'},
                  ],
                },
                {
                  'paint': {
                    'type': 'label',
                    'props': {'title': 'List posters'},
                  },
                },
              ],
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Film'), findsWidgets);
    expect(find.text('Watching'), findsWidgets);
    expect(find.text('List posters'), findsOneWidget);
  });
}
