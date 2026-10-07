import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/chrome/pointer_down_claim.dart';

void main() {
  testWidgets('ancestor mouse-down skips a claimed press', (tester) async {
    var ancestorOpened = 0;
    var pinTapped = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Listener(
          onPointerDown: (e) {
            if (PointerDownClaim.isClaimed(e.pointer)) return;
            ancestorOpened++;
          },
          child: Stack(
            children: [
              const ColoredBox(
                color: Color(0xFF000000),
                child: SizedBox(width: 200, height: 300),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: PointerDownClaim(
                  child: GestureDetector(
                    key: const Key('pin'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => pinTapped++,
                    child: const SizedBox(width: 24, height: 24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const Key('pin')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(pinTapped, 1);
    expect(ancestorOpened, 0);

    await tester.tapAt(const Offset(100, 200), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(ancestorOpened, 1);
  });
}
