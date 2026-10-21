import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/hero_pill_buttons.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/widgets/details/hero_pill_surfaces.dart';

Widget _host(ShellProfile profile, {required FocusNode focus}) {
  return MaterialApp(
    home: ShellScope(
      profile: profile,
      config: shellPlatformConfigFor(profile),
      child: Scaffold(
        body: Center(
          child: HeroPillIconGroup(
            focusNode: focus,
            slots: const [
              HeroPillIconSlot(
                icon: Icons.add_rounded,
                label: 'Keep for later',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('leanback keeps the grouped pill label painted without focus', (
    tester,
  ) async {
    final focus = FocusNode(debugLabel: 'pill');
    addTearDown(focus.dispose);
    await tester.pumpWidget(_host(ShellProfile.tv, focus: focus));
    await tester.pump();

    final surface = tester.widget<HeroPillGroupedSlotSurface>(
      find.byType(HeroPillGroupedSlotSurface),
    );
    expect(surface.compact, isFalse);
    expect(surface.active, isFalse);
    final idleWidth = tester.getSize(find.byType(HeroPillIconGroup)).width;
    expect(tester.getSize(find.text('Keep for later')).width, greaterThan(0));

    // Focus must not change the row width (View details used to shift).
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(HeroPillIconGroup)).width, idleWidth);
  });

  testWidgets('pointer shells keep icon-only slots until hover / focus', (
    tester,
  ) async {
    final focus = FocusNode(debugLabel: 'pill');
    addTearDown(focus.dispose);
    await tester.pumpWidget(_host(ShellProfile.desktop, focus: focus));
    await tester.pump();

    final surface = tester.widget<HeroPillGroupedSlotSurface>(
      find.byType(HeroPillGroupedSlotSurface),
    );
    expect(surface.compact, isTrue);
  });
}
