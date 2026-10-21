import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/catalog/mood_section.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

void main() {
  testWidgets('revealIncludesTitle wraps title + chips, not results', (
    tester,
  ) async {
    const chipKey = Key('chip');
    await tester.pumpWidget(
      _app(
        const MoodSection(
          title: 'Mood',
          revealIncludesTitle: true,
          chipStrip: SizedBox(key: chipKey, height: 40, width: 200),
          results: SizedBox(height: 300, width: 200),
        ),
      ),
    );

    final extentFinder = find.byType(ShellPaintEnsureVisibleExtent);
    expect(extentFinder, findsOneWidget);

    // The focused chip resolves the extent — the reveal scrolls this box.
    final chipContext = tester.element(find.byKey(chipKey));
    final extentContext = ShellPaintEnsureVisibleExtent.maybeContext(
      chipContext,
    );
    expect(extentContext, isNotNull);

    final extentBox = extentContext!.findRenderObject() as RenderBox;
    final chipBox = tester.renderObject<RenderBox>(find.byKey(chipKey));
    final sectionBox = tester.renderObject<RenderBox>(find.byType(MoodSection));
    final extentTop = extentBox.localToGlobal(Offset.zero).dy;
    final chipTop = chipBox.localToGlobal(Offset.zero).dy;

    expect(extentTop, sectionBox.localToGlobal(Offset.zero).dy);
    expect(chipTop, greaterThan(extentTop), reason: 'title sits above chips');
    expect(
      extentBox.size.height,
      lessThan(sectionBox.size.height),
      reason: 'results stay outside the reveal extent',
    );
    expect(
      extentBox.size.height,
      closeTo(chipTop - extentTop + chipBox.size.height, 0.01),
    );
  });

  testWidgets('default keeps the chip strip as its own reveal target', (
    tester,
  ) async {
    const chipKey = Key('chip');
    await tester.pumpWidget(
      _app(
        const MoodSection(
          title: 'Mood',
          chipStrip: SizedBox(key: chipKey, height: 40, width: 200),
        ),
      ),
    );
    expect(find.byType(ShellPaintEnsureVisibleExtent), findsNothing);
    final chipContext = tester.element(find.byKey(chipKey));
    expect(ShellPaintEnsureVisibleExtent.maybeContext(chipContext), isNull);
  });
}
