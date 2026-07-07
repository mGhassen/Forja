import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/widgets/animated_logo.dart';
import 'package:forja/shared/widgets/forja_logo.dart';

void main() {
  testWidgets('splash logo paints a halo shadow layer', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF141414),
          body: Center(
            child: SplashLogoWithHalo(
              logoHeight: 160,
              isLight: false,
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
