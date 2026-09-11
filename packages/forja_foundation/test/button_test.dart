import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/forja_foundation.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: forjaThemeData(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('Button variants', () {
    testWidgets('primary renders label and fires onPressed', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _wrap(
          Button(
            variant: ButtonVariant.primary,
            label: 'Play',
            onPressed: () => pressed++,
          ),
        ),
      );
      expect(find.text('Play'), findsOneWidget);
      await tester.tap(find.text('Play'));
      expect(pressed, 1);
    });

    testWidgets('ghost / outline / destructive / link / plainIcon build',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Button(
                variant: ButtonVariant.ghost,
                label: 'Ghost',
                onPressed: () {},
              ),
              Button(
                variant: ButtonVariant.outline,
                label: 'Outline',
                onPressed: () {},
              ),
              Button(
                variant: ButtonVariant.destructive,
                label: 'Delete',
                onPressed: () {},
              ),
              Button(
                variant: ButtonVariant.link,
                label: 'Link',
                onPressed: () {},
              ),
              Button(
                variant: ButtonVariant.plainIcon,
                size: ButtonSize.icon,
                icon: Icons.close,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.text('Ghost'), findsOneWidget);
      expect(find.text('Outline'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Link'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('loading disables press', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _wrap(
          Button(
            label: 'Save',
            loading: true,
            onPressed: () => pressed++,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(Button));
      expect(pressed, 0);
    });

    testWidgets('sizes sm md lg icon build', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final size in ButtonSize.values)
                Button(
                  size: size,
                  label: size == ButtonSize.icon ? null : size.name,
                  icon: size == ButtonSize.icon ? Icons.add : null,
                  onPressed: () {},
                ),
            ],
          ),
        ),
      );
      expect(find.byType(Button), findsNWidgets(ButtonSize.values.length));
    });
  });

  group('ButtonGroup', () {
    testWidgets('separator and text slots', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ButtonGroup(
            children: [
              Button(label: 'A', onPressed: () {}),
              ButtonGroup.separator(),
              ButtonGroup.text('or'),
              Button(label: 'B', onPressed: () {}),
            ],
          ),
        ),
      );
      expect(find.text('A'), findsOneWidget);
      expect(find.text('or'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
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
}
