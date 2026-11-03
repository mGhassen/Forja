import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/chrome/horizontal_scroller.dart';

void main() {
  Future<void> pumpScroller(
    WidgetTester tester, {
    required ScrollController horizontal,
    required ScrollController vertical,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: vertical,
            children: [
              const SizedBox(height: 40),
              HorizontalScroller(
                height: 80,
                controller: horizontal,
                itemCount: 12,
                itemBuilder: (_, i) =>
                    SizedBox(width: 120, height: 80, child: Text('c$i')),
              ),
              const SizedBox(height: 800),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> scrollAtRail(
    WidgetTester tester, {
    required PointerDeviceKind kind,
    required double dy,
  }) async {
    final box =
        tester.renderObject(find.byType(HorizontalScroller)) as RenderBox;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: center,
        scrollDelta: Offset(0, dy),
        kind: kind,
      ),
    );
    await tester.pump();
  }

  testWidgets('mouse wheel keeps vertical page scroll', (tester) async {
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);

    await pumpScroller(tester, horizontal: horizontal, vertical: vertical);
    await tester.pumpAndSettle();

    await scrollAtRail(tester, kind: PointerDeviceKind.mouse, dy: 80);

    expect(horizontal.offset, 0);
    expect(vertical.offset, greaterThan(0));
  });

  testWidgets('trackpad vertical scroll moves the strip', (tester) async {
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);

    await pumpScroller(tester, horizontal: horizontal, vertical: vertical);
    await tester.pumpAndSettle();

    final pageBefore = vertical.offset;
    await scrollAtRail(tester, kind: PointerDeviceKind.trackpad, dy: 80);

    expect(horizontal.offset, greaterThan(0));
    expect(vertical.offset, pageBefore);
  });
}
