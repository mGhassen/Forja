import 'package:flutter/material.dart'
    hide Switch, Chip, Checkbox, Radio, RadioGroup, ListTile, Tooltip;
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/forja_foundation.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: forjaThemeData(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('G3 smoke builds', () {
    testWidgets('Checkbox Radio Label Textarea build', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(value: true, onChanged: (_) {}, label: 'Agree'),
              RadioGroup<String>(
                value: 'a',
                onChanged: (_) {},
                children: const [
                  Radio(
                    value: 'a',
                    groupValue: 'a',
                    onChanged: null,
                    label: 'A',
                  ),
                  Radio(
                    value: 'b',
                    groupValue: 'a',
                    onChanged: null,
                    label: 'B',
                  ),
                ],
              ),
              const Label(text: 'Email', isRequired: true),
              const Textarea(hintText: 'Notes'),
            ],
          ),
        ),
      );
      expect(find.text('Agree'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('Tabs Skeleton Alert Progress Avatar build', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tabs(
                  labels: const ['Films', 'TV'],
                  selectedIndex: 0,
                  onChanged: (_) {},
                ),
                const Skeleton(width: 120, height: 12),
                const SkeletonText(lines: 2),
                const SkeletonPoster(width: 80),
                const Alert(
                  title: 'Heads up',
                  description: 'Something happened',
                ),
                const Progress(value: 0.4),
                const Progress(
                  variant: ProgressVariant.circular,
                  value: 0.5,
                ),
                const Avatar(initials: 'FG'),
                const Spinner(),
                const Heading('Title'),
                const Body('Body copy', tone: BodyTone.secondary),
                PageDots(count: 3, index: 1, onChanged: (_) {}),
                MoodCircle(label: 'Action', selected: true, onTap: () {}),
                PosterFrame(
                  width: 60,
                  child: ColoredBox(color: Colors.grey.shade800),
                ),
                SegmentedControl<int>(
                  value: 0,
                  options: const [
                    SegmentedOption(value: 0, label: 'Day'),
                    SegmentedOption(value: 1, label: 'Week'),
                  ],
                  onChanged: (_) {},
                ),
                const Kbd(keys: ['⌘', 'K']),
                Select<String>(
                  value: 'a',
                  options: const [
                    SelectOption(value: 'a', label: 'Alpha'),
                    SelectOption(value: 'b', label: 'Beta'),
                  ],
                  onChanged: (_) {},
                ),
                const Accordion(
                  title: 'More',
                  initiallyExpanded: true,
                  child: Body('Expanded'),
                ),
                ListTile(
                  title: const Text('Row'),
                  subtitle: const Text('Sub'),
                  onTap: () {},
                ),
                SearchField(onChanged: (_) {}),
                const ForjaNetworkImage(
                  url: 'not-absolute',
                  width: 40,
                  height: 40,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Films'), findsOneWidget);
      expect(find.text('Heads up'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      expect(find.text('Expanded'), findsOneWidget);
    });
  });

  group('Switch', () {
    testWidgets('toggles value via onChanged', (tester) async {
      var value = false;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              return Switch(
                value: value,
                onChanged: (v) => setState(() => value = v),
              );
            },
          ),
        ),
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(value, isTrue);
    });
  });

  group('Chip', () {
    testWidgets('idle and selected variants build', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Chip(
                label: 'Idle',
                variant: ChipVariant.idle,
                size: ChipSize.sm,
                onPressed: () {},
              ),
              Chip(
                label: 'Selected',
                variant: ChipVariant.selected,
                size: ChipSize.md,
                onPressed: () => tapped = true,
              ),
            ],
          ),
        ),
      );
      expect(find.text('Idle'), findsOneWidget);
      expect(find.text('Selected'), findsOneWidget);
      await tester.tap(find.text('Selected'));
      expect(tapped, isTrue);
    });
  });

  group('VerticalMenu', () {
    testWidgets('item slot selects', (tester) async {
      String? picked;
      await tester.pumpWidget(
        _wrap(
          VerticalMenu(
            children: [
              VerticalMenu.item(
                label: 'Netflix',
                selected: true,
                onTap: () => picked = 'netflix',
              ),
              VerticalMenu.item(
                label: 'Prime',
                onTap: () => picked = 'prime',
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Prime'));
      expect(picked, 'prime');
    });
  });

  group('LogoMenuRail', () {
    testWidgets('builds items and fires onSelect', (tester) async {
      String? selected;
      await tester.pumpWidget(
        _wrap(
          LogoMenuRail(
            selectedId: 'a',
            onSelect: (id) => selected = id,
            items: const [
              LogoMenuItem(id: 'a', label: 'Alpha'),
              LogoMenuItem(id: 'b', label: 'Beta'),
            ],
          ),
        ),
      );
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      await tester.tap(find.text('Beta'));
      expect(selected, 'b');
    });

    testWidgets('visible false hides rail', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LogoMenuRail(
            visible: false,
            selectedId: null,
            onSelect: (_) {},
            items: const [LogoMenuItem(id: 'a', label: 'Hidden')],
          ),
        ),
      );
      expect(find.text('Hidden'), findsNothing);
    });
  });

  group('KitTypes.normalize', () {
    test('maps legacy aliases', () {
      expect(KitTypes.normalize('stack'), KitTypes.stack);
      expect(KitTypes.normalize('menu'), KitTypes.menu);
      expect(KitTypes.normalize('tabs'), KitTypes.tabs);
      expect(
        KitTypes.normalize('tabs', {'style': 'kind'}),
        KitTypes.menu,
      );
      expect(KitTypes.normalize('host.my_list'), KitTypes.list);
      expect(KitTypes.normalize('rail'), KitTypes.row);
      expect(KitTypes.normalize('topBar'), KitTypes.topBar);
      expect(KitTypes.normalize('kinds'), KitTypes.categoryBar);
      expect(KitTypes.normalize('kit.stack'), KitTypes.stack);
      expect(KitTypes.normalize('custom.slot'), 'custom.slot');
    });
  });
}
