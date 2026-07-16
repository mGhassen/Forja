import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/controls/player_chrome_overlay.dart';

void main() {
  testWidgets('PlayerTopBar title stays centered with unequal side controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 576);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerTopBar(
            title: 'Centered title',
            onBack: () {},
            trailing: const SizedBox(width: 132, height: 44),
          ),
        ),
      ),
    );

    expect(tester.getCenter(find.text('Centered title')).dx, closeTo(512, 0.1));
  });
}
