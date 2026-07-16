import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/widgets/shell_card_play_overlay.dart';

Widget _overlayHarness({
  required bool active,
  required bool visible,
  double diameter = 48,
  double iconSize = 28,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          children: [
            ShellCardPlayOverlay(
              active: active,
              visible: visible,
              diameter: diameter,
              iconSize: iconSize,
            ),
          ],
        ),
      ),
    ),
  );
}

Finder get _playPulse => find.byKey(const ValueKey('shell-card-play-pulse'));

void main() {
  testWidgets('active visible play control floats and pulses slowly', (
    tester,
  ) async {
    await tester.pumpWidget(_overlayHarness(active: false, visible: true));

    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
      Offset.zero,
    );

    await tester.pumpWidget(_overlayHarness(active: true, visible: true));

    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.1);
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
      const Offset(0, -0.1),
    );

    await tester.pump(const Duration(milliseconds: 100));
    final pulse = tester.widget<ScaleTransition>(_playPulse);
    expect(pulse.scale.value, greaterThan(1));
    expect(pulse.scale.value, lessThanOrEqualTo(1.12));
  });

  testWidgets('hidden play control stays at rest and supports compact sizing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _overlayHarness(active: true, visible: false, diameter: 30, iconSize: 18),
    );

    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
      Offset.zero,
    );
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );
    expect(tester.widget<ScaleTransition>(_playPulse).scale.value, 1);
    expect(tester.getSize(find.byType(AnimatedContainer)), const Size(30, 30));
    expect(tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded)).size, 18);
  });
}
