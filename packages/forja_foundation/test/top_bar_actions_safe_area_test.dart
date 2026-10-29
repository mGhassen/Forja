import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/chrome/top_bar_actions.dart';

Widget _bar({required EdgeInsets padding}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: const Size(914, 411), padding: padding),
        child: Align(
          alignment: Alignment.topLeft,
          child: TopBarActions(
            padding: EdgeInsets.zero,
            leading: const [SizedBox(key: ValueKey('chip'), width: 80, height: 32)],
          ),
        ),
      ),
    );

void main() {
  testWidgets('strip clears the top system inset (edge-to-edge phone)', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(padding: const EdgeInsets.only(top: 24)));
    expect(tester.getTopLeft(find.byKey(const ValueKey('chip'))).dy,
        greaterThanOrEqualTo(24));
  });

  testWidgets('no inset (TV, desktop, consumed) leaves the strip in place', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(padding: EdgeInsets.zero));
    expect(tester.getTopLeft(find.byKey(const ValueKey('chip'))).dy,
        lessThan(24));
  });
}
