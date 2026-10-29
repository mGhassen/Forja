import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/hero_pill_buttons.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/kit_details_play_row.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/widgets/details/details_top_bar.dart';
import 'package:forja_foundation/widgets/details/hero_pill_surfaces.dart';

Widget _host(Widget child, {ShellProfile profile = ShellProfile.mobile}) {
  return MaterialApp(
    home: ShellScope(
      profile: profile,
      config: shellPlatformConfigFor(profile),
      child: Scaffold(body: child),
    ),
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(411, 914);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('phone actions: full-width Play, labels shown at rest', (
    tester,
  ) async {
    _phone(tester);
    var played = 0;
    var sources = 0;
    await tester.pumpWidget(
      _host(
        HeroPillLabelScope(
          child: DetailsStackedActions(
            primary: KitDetailsPlayRow(
              label: 'Play S1E1',
              onPlay: () => played++,
              expand: true,
            ),
            secondary: [
              HeroPillPlayButton(
                label: 'Sources',
                icon: Icons.link_rounded,
                tone: HeroPillPlayTone.secondary,
                onTap: () => sources++,
              ),
              HeroPillIconGroup(
                slots: const [
                  HeroPillIconSlot(icon: Icons.add_rounded, label: 'My List'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final plays = tester
        .widgetList<HeroPillPlaySurface>(find.byType(HeroPillPlaySurface))
        .toList();
    expect(plays, hasLength(2));
    expect(plays.every((p) => p.expanded), isTrue);
    expect(plays.first.fill, isTrue);
    expect(tester.getSize(find.byType(HeroPillPlaySurface).first).width, 411);
    // Secondary pill hugs its label instead of taking the whole line.
    expect(
      tester.getSize(find.byType(HeroPillPlaySurface).last).width,
      lessThan(411),
    );
    final slot = tester.widget<HeroPillGroupedSlotSurface>(
      find.byType(HeroPillGroupedSlotSurface),
    );
    expect(slot.compact, isFalse);

    await tester.tap(find.text('Play S1E1'));
    await tester.tap(find.text('Sources'));
    expect(played, 1);
    expect(sources, 1);
  });

  testWidgets('desktop pills stay icon-only without the label scope', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        profile: ShellProfile.desktop,
        const Center(child: HeroPillPlayButton(label: 'Trailer')),
      ),
    );
    await tester.pump();
    final surface = tester.widget<HeroPillPlaySurface>(
      find.byType(HeroPillPlaySurface),
    );
    expect(surface.expanded, isFalse);
    expect(surface.fill, isFalse);
  });

  testWidgets('phone top bar: 48 dp back, turns solid past the hero', (
    tester,
  ) async {
    _phone(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final heroKey = GlobalKey();
    var popped = 0;
    await tester.pumpWidget(
      _host(
        Stack(
          children: [
            ListView(
              controller: controller,
              children: [
                SizedBox(key: heroKey, height: 600),
                const SizedBox(height: 2000),
              ],
            ),
            MediaDetailsMobileTopBar(
              scrollController: controller,
              heroKey: heroKey,
              title: 'Synthetic Title',
              backgroundColor: Colors.black,
              onPressed: () => popped++,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    double progress() => tester
        .widget<DetailsCollapsingTopBar>(find.byType(DetailsCollapsingTopBar))
        .progress;

    expect(progress(), 0);
    final back = find.byIcon(Icons.chevron_left_rounded);
    expect(back, findsOneWidget);
    final hit = tester.getSize(
      find.ancestor(of: back, matching: find.byType(SizedBox)).first,
    );
    expect(hit.width, DetailsTokens.backHitSizeMobile);
    await tester.tap(back);
    expect(popped, 1);

    controller.jumpTo(600);
    await tester.pump();
    expect(progress(), 1);
  });
}
