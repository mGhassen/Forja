import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/shell/brand/animated_logo.dart';
import 'package:forja/shared/shell/brand/forja_logo.dart';

void main() {
  testWidgets('splash logo paints a halo shadow layer', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF141414),
          body: Center(
            child: SplashLogoWithHalo(
              logoHeight: 160,
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 900));

    final logo = tester.widget<ForjaLogo>(find.byType(ForjaLogo));
    expect(logo.halo, isNotNull);
    expect(logo.halo!.centerAlpha, greaterThan(0));
  });
}
