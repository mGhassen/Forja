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
                  'type': 'rail',
                  'title': 'Tonight',
                  'items': [
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
              ],
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Tonight'), findsOneWidget);
    expect(find.text('Poster A'), findsWidgets);
  });
}
