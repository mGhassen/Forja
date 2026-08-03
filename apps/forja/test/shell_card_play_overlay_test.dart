import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/shell_card_play_overlay.dart';

Widget _overlayHarness({
  required bool active,
  required bool visible,
  VoidCallback? onTap,
  VoidCallback? onCardTap,
  double diameter = 48,
  double iconSize = 28,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 160,
        height: 160,
        child: GestureDetector(
          onTap: onCardTap,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              ShellCardPlayOverlay(
                active: active,
                visible: visible,
                onTap: onTap,
                diameter: diameter,
                iconSize: iconSize,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Finder get _playPulse => find.byKey(const ValueKey('shell-card-play-pulse'));
Finder get _hoverTarget =>
    find.byKey(const ValueKey('shell-card-play-hover-target'));

void main() {
  testWidgets('active visible play control pulses only on button hover', (
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
    expect(tester.widget<ScaleTransition>(_playPulse).scale.value, 1);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(_hoverTarget));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final pulse = tester.widget<ScaleTransition>(_playPulse);
    expect(pulse.scale.value, greaterThan(1));
    expect(pulse.scale.value, lessThanOrEqualTo(1.12));

    await mouse.moveTo(const Offset(0, 0));
    await tester.pump();
    expect(tester.widget<ScaleTransition>(_playPulse).scale.value, 1);
  });

  testWidgets(
    'inactive visible play accents green and pulses only on button hover',
    (tester) async {
      await tester.pumpWidget(_overlayHarness(active: false, visible: true));

      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      expect(
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer))
            .decoration,
        isA<BoxDecoration>().having(
          (d) => d.color,
          'color',
          Colors.black.withValues(alpha: 0.42),
        ),
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer();
      await mouse.moveTo(tester.getCenter(_hoverTarget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        1.1,
      );
      expect(
        tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
        const Offset(0, -0.1),
      );
      expect(
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer))
            .decoration,
        isA<BoxDecoration>().having(
          (d) => d.color,
          'color',
          ForjaShellColors.brandGreen,
        ),
      );
      final pulse = tester.widget<ScaleTransition>(_playPulse);
      expect(pulse.scale.value, greaterThan(1));
      expect(pulse.scale.value, lessThanOrEqualTo(1.12));
    },
  );

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

  testWidgets('visible play button receives tap; card does not', (tester) async {
    var playTaps = 0;
    var cardTaps = 0;
    await tester.pumpWidget(
      _overlayHarness(
        active: true,
        visible: true,
        onTap: () => playTaps++,
        onCardTap: () => cardTaps++,
      ),
    );

    await tester.tap(_hoverTarget);
    await tester.pump();

    expect(playTaps, 1);
    expect(cardTaps, 0);
  });

  testWidgets('hidden play onTap does not steal card taps', (tester) async {
    var playTaps = 0;
    var cardTaps = 0;
    await tester.pumpWidget(
      _overlayHarness(
        active: true,
        visible: false,
        onTap: () => playTaps++,
        onCardTap: () => cardTaps++,
      ),
    );

    await tester.tapAt(const Offset(80, 80));
    await tester.pump();

    expect(playTaps, 0);
    expect(cardTaps, 1);
  });
}
