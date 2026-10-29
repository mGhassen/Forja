import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/kit_card_quick_actions.dart';
import 'package:forja/shared/engine/runtime/kit/paint_artifact.dart';
import 'package:forja/shared/engine/runtime/kit/paint_tree.dart';
import 'package:forja/shared/engine/runtime/open/meta_surface_open.dart';
import 'package:forja/shell/core/forja_shell_layout.dart';
import 'package:forja/shell/core/forja_shell_metrics.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/hero_pill_buttons.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/core/shell_paint_host_install.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/card_quick_menu.dart';
import 'package:forja_foundation/widgets/catalog/cinematic_hero.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Synthetic ids only — proves the generic touch contract, not a shipped pack.
const _plugin = 'test-hub-a';
const _tab = 'catalog';
const _phone = Size(411, 914);

Widget _wrap(ShellProfile profile, Widget child, {Size size = _phone}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: ShellScope(
        profile: profile,
        config: shellPlatformConfigFor(profile),
        child: Scaffold(body: child),
      ),
    ),
  );
}

MetaItem _item() => const MetaItem(
  id: 'x1',
  type: 'movie',
  name: 'Synthetic',
  open: MetaOpen(surface: 'test-surface', id: '42'),
);

Map<String, dynamic> _heroSpec(List<Map<String, dynamic>> actions) => {
  'type': 'hero',
  'id': 'spotlight',
  'actions': actions,
  'items': [
    {
      'meta': {
        'id': 'x1',
        'type': 'movie',
        'name': 'Synthetic',
        'open': {'surface': 'test-surface', 'id': '42'},
      },
      'paint': {
        'type': 'posterCard',
        'props': {
          'title': 'Synthetic',
          'backdropUrl': 'https://example.com/b.jpg',
          'focalX': 0.25,
        },
      },
    },
  ],
};

const _packActions = [
  {
    'id': 'play',
    'label': 'Play',
    'icon': 'play',
    'tone': 'primary',
    'profiles': ['mobile'],
  },
  {'id': 'details', 'label': 'Details', 'tone': 'secondary'},
];

void main() {
  setUpAll(installShellPaintHostAdapters);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MetaSurfaceOpen.debugReset();
  });

  tearDownAll(MetaSurfaceOpen.debugReset);

  group('profile density', () {
    test('only the mobile metrics row is touch density', () {
      expect(ShellMetrics.mobile.usesMobileDensity, isTrue);
      expect(ShellMetrics.desktop.usesMobileDensity, isFalse);
      expect(ShellMetrics.tv.usesMobileDensity, isFalse);
    });

    testWidgets('paint scope + host poster helpers follow the profile', (
      tester,
    ) async {
      final seen = <ShellProfile, (bool, double, double)>{};
      for (final p in ShellProfile.values) {
        await tester.pumpWidget(
          _wrap(
            p,
            Builder(
              builder: (context) {
                seen[p] = (
                  ShellPaintScope.usesMobileDensityOf(context),
                  shellPosterCardWidth(context),
                  shellPosterCardRowGap(context),
                );
                return const SizedBox();
              },
            ),
          ),
        );
      }
      expect(seen[ShellProfile.mobile]!.$1, isTrue);
      expect(
        seen[ShellProfile.mobile]!.$2,
        ShellTokens.posterCardWidthMobileFor(_phone),
      );
      expect(seen[ShellProfile.mobile]!.$3, ShellTokens.posterCardRowGapMobile);
      expect(seen[ShellProfile.desktop]!.$1, isFalse);
      expect(
        seen[ShellProfile.desktop]!.$2,
        ShellTokens.posterCardWidthDesktop,
      );
      expect(seen[ShellProfile.desktop]!.$3, ShellTokens.posterCardRowGap);
      expect(seen[ShellProfile.tv]!.$1, isFalse);
      expect(seen[ShellProfile.tv]!.$2, ShellTokens.posterCardWidthTv);
      expect(seen[ShellProfile.tv]!.$3, ShellTokens.tvPosterCardRowGap);
    });
  });

  testWidgets('pack poster sizes follow touch density; TV keeps chrome scale', (
    tester,
  ) async {
    final seen = <ShellProfile, double?>{};
    for (final p in ShellProfile.values) {
      await tester.pumpWidget(
        _wrap(
          p,
          Builder(
            builder: (context) {
              seen[p] = PackPaintArtifact.packPosterLength(context, 190);
              return const SizedBox();
            },
          ),
          size: p == ShellProfile.tv ? const Size(1920, 1080) : _phone,
        ),
      );
    }
    expect(
      seen[ShellProfile.mobile],
      ShellTokens.posterCardWidthMobileFor(_phone),
    );
    expect(seen[ShellProfile.desktop], 190);
    expect(seen[ShellProfile.tv], ShellTokens.chromeScale(190, tv: true));
  });

  group('card long-press on touch', () {
    testWidgets('mobile gets an opener that shows the action sheet', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(ShellProfile.mobile, const SizedBox()));
      final ctx = tester.element(find.byType(SizedBox));
      final open = KitCardQuickActions.openerFor(
        ctx,
        pluginId: _plugin,
        item: _item(),
      );
      expect(open, isNotNull);
      open!();
      await tester.pumpAndSettle();
      expect(find.byType(CardQuickActionSheet), findsOneWidget);
      expect(find.text(KitCardQuickActions.playLabel), findsOneWidget);
      expect(find.text(KitCardQuickActions.detailsLabel), findsOneWidget);
      expect(find.text(KitCardQuickActions.addToListLabel), findsOneWidget);
    });

    testWidgets('desktop keeps no hold opener', (tester) async {
      await tester.pumpWidget(_wrap(ShellProfile.desktop, const SizedBox()));
      final ctx = tester.element(find.byType(SizedBox));
      expect(
        KitCardQuickActions.openerFor(ctx, pluginId: _plugin, item: _item()),
        isNull,
      );
    });
  });

  group('hero actions', () {
    Future<void> pumpHero(
      WidgetTester tester,
      ShellProfile profile, {
      List<Map<String, dynamic>> actions = _packActions,
    }) async {
      await tester.pumpWidget(
        _wrap(
          profile,
          SingleChildScrollView(
            child: PackPaintTree(
              spec: _heroSpec(actions),
              pluginId: _plugin,
              tabId: _tab,
            ),
          ),
          size: profile == ShellProfile.tv ? const Size(1920, 1080) : _phone,
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('pack-declared mobile Play leads the row on touch', (
      tester,
    ) async {
      await pumpHero(tester, ShellProfile.mobile);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Play')).dx,
        lessThan(tester.getTopLeft(find.text('Details')).dx),
      );
      final hero = tester.widget<CinematicHero>(find.byType(CinematicHero));
      expect(hero.layout.mobile, isTrue);
      expect(hero.layout.maxImageHeight, isNotNull);
      // Pack focalX 0.25 → crop focus left of center.
      expect(
        hero.slides.single.portraitImageAlignment,
        const Alignment(-0.5, 0),
      );
    });

    testWidgets('mobile-only Play stays off desktop', (tester) async {
      await pumpHero(tester, ShellProfile.desktop);
      expect(find.text('Play'), findsNothing);
      expect(find.text('Details'), findsOneWidget);
      final hero = tester.widget<CinematicHero>(find.byType(CinematicHero));
      expect(hero.layout.mobile, isFalse);
      expect(hero.layout.maxImageHeight, isNull);
    });

    testWidgets('Play on every profile joins the TV focus row', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpHero(
        tester,
        ShellProfile.tv,
        actions: [
          {'id': 'play', 'label': 'Play', 'tone': 'primary'},
          {'id': 'details', 'label': 'Details', 'tone': 'secondary'},
        ],
      );
      HeroPillPlayButton pill(String label) =>
          tester.widget<HeroPillPlayButton>(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(HeroPillPlayButton),
            ),
          );
      final play = pill('Play');
      final details = pill('Details');
      expect(play.focusNode, isNotNull);
      expect(play.tvItemIndex, 0);
      expect(details.tvItemIndex, 1);
      expect(play.tvRowId, details.tvRowId);

      play.onRightEdge!();
      await tester.pump();
      expect(details.focusNode!.hasFocus, isTrue);
      details.onLeftEdge!();
      await tester.pump();
      expect(play.focusNode!.hasFocus, isTrue);
    });
  });
}
