import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/design/design.dart';

void main() {
  testWidgets('ForjaLoadingDots paints cycling dots', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ForjaLoadingDots(color: Colors.white),
        ),
      ),
    );
    expect(find.byType(ForjaLoadingDots), findsOneWidget);
  });
}
