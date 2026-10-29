import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/chrome/top_bar_actions.dart';

Widget _chip(String label, double width) =>
    SizedBox(key: ValueKey(label), width: width, height: 32);

Widget _bar(double width, {bool phone = true}) => MaterialApp(
  home: ShellPaintScope(
    useTvFocus: false,
    scaleOnHover: false,
    focusStyled: (context, {required focused}) => focused,
    usesTvDensity: false,
    usesMobileDensity: phone,
    child: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: TopBarActions(
            padding: EdgeInsets.zero,
            gap: 8,
            leading: [_chip('a', 120), _chip('b', 120)],
            trailing: [_chip('search', 48), _chip('portals', 260)],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('wide bar keeps trailing actions at the end', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_bar(1200));

    expect(tester.takeException(), isNull);
    expect(tester.getTopLeft(find.byKey(const ValueKey('a'))).dx, 0);
    expect(tester.getTopRight(find.byKey(const ValueKey('portals'))).dx, 1200);
  });

  testWidgets('desktop keeps the fixed row (no scroll view)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_bar(1200, phone: false));

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.getTopRight(find.byKey(const ValueKey('portals'))).dx, 1200);
  });

  testWidgets('narrow bar scrolls instead of overflowing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_bar(400));

    expect(tester.takeException(), isNull);
    final portals = find.byKey(const ValueKey('portals'));
    expect(tester.getTopRight(portals).dx, greaterThan(400));

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopRight(portals).dx, lessThanOrEqualTo(400));
  });
}
