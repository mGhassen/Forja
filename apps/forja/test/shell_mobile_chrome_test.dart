import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shell/chrome/kit_top_bar_fade.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shell/frame/shell_scaffold.dart';
import 'package:forja/shell/frame/shell_status_bar_scrim.dart';
import 'package:forja/shell/nav/nav_config.dart';
import 'package:forja/shell/nav/shell_bottom_nav.dart';
import 'package:forja/shell/platform/shell_system_ui.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:rust/src/settings_service.dart';

// Synthetic hub ids — never shipped pack ids.
const _hubs = [
  't_hub_1',
  't_hub_2',
  't_hub_3',
  't_hub_4',
  't_hub_5',
  't_hub_6',
];
const _icons = [
  Icons.home,
  Icons.star,
  Icons.tv,
  Icons.sports,
  Icons.list,
  Icons.bookmark,
];
const _accents = {
  't_hub_1': Color(0xFFE50914),
  't_hub_2': Color(0xFF8B5CF6),
  't_hub_3': Color(0xFFEC4899),
  't_hub_4': Color(0xFF22C55E),
  't_hub_5': Color(0xFFF59E0B),
  't_hub_6': Color(0xFF06B6D4),
};

const _phonePortrait = Size(411, 914);
const _phoneLandscape = Size(914, 411);

Widget _wrap(
  Widget child, {
  ShellProfile profile = ShellProfile.mobile,
  Size size = _phonePortrait,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size, padding: padding),
      child: ShellScope(
        profile: profile,
        config: shellPlatformConfigFor(profile),
        child: child,
      ),
    ),
  );
}

ShellScaffold _scaffold(
  List<String> ids, {
  int selectedIndex = 0,
  ValueChanged<int>? onSelected,
}) {
  return ShellScaffold(
    useNavRail: false,
    visibleIds: ids,
    selectedIndex: selectedIndex,
    mountedTabIds: {ids[selectedIndex]},
    onDestinationSelected: onSelected ?? (_) {},
    tabFor: (id) => Center(child: Text('body-$id')),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = _phonePortrait,
  EdgeInsets padding = EdgeInsets.zero,
  ShellProfile profile = ShellProfile.mobile,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _wrap(child, profile: profile, size: size, padding: padding),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    PluginNavRegistry.seedTestHubNav(
      destinations: {
        for (var i = 0; i < _hubs.length; i++)
          _hubs[i]: NavDestination(
            id: _hubs[i],
            icon: _icons[i],
            activeIcon: _icons[i],
            label: 'Hub ${i + 1}',
          ),
      },
      accents: _accents,
    );
    SettingsService.shellWritingDirection.value =
        SettingsService.shellWritingLtr;
    ShellBus.shellOverlayHasPage.value = false;
    for (final id in _hubs) {
      ShellBus.hubScrollOffsetFor(id).value = 0;
    }
  });

  group('bottom bar painted indexes', () {
    test('every destination id is painted in order', () {
      expect(ShellBottomNav.paintedIndexes([..._hubs.take(4), 'settings']), [
        0,
        1,
        2,
        3,
        4,
      ]);
      expect(ShellBottomNav.paintedIndexes([..._hubs, 'settings']), [
        0,
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
    });

    test('ids without a destination never take a slot', () {
      expect(
        ShellBottomNav.paintedIndexes([
          _hubs[0],
          'no_such_tab',
          ..._hubs.skip(1),
          'settings',
        ]),
        [0, 2, 3, 4, 5, 6, 7],
      );
    });
  });

  testWidgets('many tabs: bar scrolls; Settings selectable in the row', (
    tester,
  ) async {
    final ids = [..._hubs, 'settings'];
    int? picked;
    await _pump(tester, _scaffold(ids, onSelected: (i) => picked = i));

    expect(find.text('Hub 1'), findsOneWidget);
    expect(find.text('More'), findsNothing);
    expect(find.byType(ListView), findsWidgets);

    final scrollable = find.descendant(
      of: find.byType(ShellBottomNav),
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);
    await tester.drag(scrollable, const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(picked, ids.indexOf('settings'));
  });

  testWidgets('selected overflow tab keeps its own accent underline', (
    tester,
  ) async {
    final ids = [..._hubs, 'settings'];
    await _pump(tester, _scaffold(ids, selectedIndex: 5));
    await tester.pumpAndSettle();

    // Selected slot is scrolled into view; its accent stays on that tab.
    expect(find.text('Hub 6'), findsOneWidget);
    final selected = tester.widget<Text>(find.text('Hub 6'));
    expect(selected.style?.color, _accents[_hubs[5]]);
  });

  testWidgets('selected tab uses destination accent + underline', (
    tester,
  ) async {
    await _pump(tester, _scaffold([_hubs[0], _hubs[1], 'settings']));

    final selectedIcon = tester.widget<NavDestinationIcon>(
      find.byWidgetPredicate(
        (w) => w is NavDestinationIcon && w.destination.id == _hubs[0],
      ),
    );
    expect(selectedIcon.color, _accents[_hubs[0]]);

    final underline = find.byKey(ValueKey('nav-${_hubs[0]}-underline'));
    expect(underline, findsOneWidget);
    final deco =
        tester.widget<AnimatedContainer>(underline).decoration as BoxDecoration;
    expect(deco.color, _accents[_hubs[0]]);
    expect(tester.getSize(underline).width, greaterThan(0));

    final idleUnderline = find.byKey(ValueKey('nav-${_hubs[1]}-underline'));
    expect(tester.getSize(idleUnderline).width, 0);
  });

  testWidgets('hover paints destination accent like the rail', (tester) async {
    await _pump(tester, _scaffold([_hubs[0], _hubs[1], 'settings']));

    Finder idleIcon() => find.byWidgetPredicate(
      (w) => w is NavDestinationIcon && w.destination.id == _hubs[1],
    );
    expect(
      tester.widget<NavDestinationIcon>(idleIcon()).color,
      ForjaShellColors.iconMuted,
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byIcon(Icons.star)));
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavDestinationIcon>(idleIcon()).color,
      _accents[_hubs[1]],
    );
  });

  testWidgets('portrait bar keeps its height and clears the gesture inset', (
    tester,
  ) async {
    const bottomInset = 24.0;
    await _pump(
      tester,
      _scaffold([..._hubs.take(3), 'settings']),
      padding: const EdgeInsets.only(bottom: bottomInset),
    );

    final bar = tester.getSize(find.byType(ShellBottomNav));
    expect(bar.height, ShellTokens.bottomNavHeight + bottomInset);
    final label = tester.getRect(find.text('Hub 1'));
    expect(
      label.bottom,
      lessThanOrEqualTo(_phonePortrait.height - bottomInset),
    );
  });

  testWidgets('landscape phone gets the compact bar, icon beside label', (
    tester,
  ) async {
    const bottomInset = 16.0;
    await _pump(
      tester,
      _scaffold([..._hubs, 'settings']),
      size: _phoneLandscape,
      padding: const EdgeInsets.only(bottom: bottomInset),
    );

    final bar = tester.getSize(find.byType(ShellBottomNav));
    expect(bar.height, ShellTokens.bottomNavHeightCompact + bottomInset);
    final icon = tester.getRect(find.byIcon(Icons.home).first);
    final label = tester.getRect(find.text('Hub 1'));
    expect(label.left, greaterThan(icon.right));
    expect((label.center.dy - icon.center.dy).abs(), lessThan(4));
    expect(tester.takeException(), isNull);
  });

  group('status bar scrim', () {
    const top = 28.0;

    testWidgets('mobile: nothing at rest, theme strip once content scrolls', (
      tester,
    ) async {
      await _pump(
        tester,
        _scaffold([_hubs[0], 'settings']),
        padding: const EdgeInsets.only(top: top),
      );
      expect(find.byType(ShellStatusBarScrim), findsOneWidget);
      expect(
        find.byType(ColoredBox).evaluate().where((e) {
          final box = e.renderObject as RenderBox?;
          return box != null && box.size.height == top;
        }),
        isEmpty,
      );

      ShellBus.hubScrollOffsetFor(_hubs[0]).value = 200;
      await tester.pump();
      final strip = find.descendant(
        of: find.byType(ShellStatusBarScrim),
        matching: find.byType(ColoredBox),
      );
      expect(strip, findsOneWidget);
      expect(tester.getSize(strip).height, top);
    });

    testWidgets('mobile: hidden while a shell overlay page is up', (
      tester,
    ) async {
      ShellBus.hubScrollOffsetFor(_hubs[0]).value = 200;
      await _pump(
        tester,
        _scaffold([_hubs[0], 'settings']),
        padding: const EdgeInsets.only(top: top),
      );
      expect(
        find.descendant(
          of: find.byType(ShellStatusBarScrim),
          matching: find.byType(ColoredBox),
        ),
        findsOneWidget,
      );
      // Details / search page pushed on the shell overlay navigator.
      ShellBus.shellOverlayHasPage.value = true;
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(ShellStatusBarScrim),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
    });

    testWidgets('desktop and TV never mount it', (tester) async {
      ShellBus.hubScrollOffsetFor(_hubs[0]).value = 200;
      for (final profile in [ShellProfile.desktop, ShellProfile.tv]) {
        await _pump(
          tester,
          ShellScaffold(
            useNavRail: true,
            visibleIds: [_hubs[0], 'settings'],
            selectedIndex: 0,
            mountedTabIds: {_hubs[0]},
            onDestinationSelected: (_) {},
            tabFor: (id) => Text(id),
          ),
          size: const Size(1280, 800),
          padding: const EdgeInsets.only(top: top),
          profile: profile,
        );
        expect(find.byType(ShellStatusBarScrim), findsNothing);
      }
    });

    test('opacity ramps over the scrim fade distance', () {
      expect(ShellStatusBarScrim.opacityFor(0), 0);
      expect(
        ShellStatusBarScrim.opacityFor(28, fadeInDistance: 56),
        closeTo(0.5, 1e-9),
      );
      expect(ShellStatusBarScrim.opacityFor(500), 1);
    });
  });

  group('kitTopBarSolidOpacity (touch hub bar)', () {
    test('clear at rest under a hero', () {
      expect(
        kitTopBarSolidOpacity(
          scrollOffset: 0,
          heroHeight: 600,
          barHeight: 80,
          fadeDistance: 200,
        ),
        0,
      );
    });

    test('solid when the hero text bottom reaches the bar', () {
      // start = 600 − 80 − 200 = 320; full at 520.
      expect(
        kitTopBarSolidOpacity(
          scrollOffset: 420,
          heroHeight: 600,
          barHeight: 80,
          fadeDistance: 200,
        ),
        closeTo(0.5, 1e-9),
      );
      expect(
        kitTopBarSolidOpacity(
          scrollOffset: 520,
          heroHeight: 600,
          barHeight: 80,
          fadeDistance: 200,
        ),
        1,
      );
    });

    test('no hero: fades in from the first scroll', () {
      expect(
        kitTopBarSolidOpacity(
          scrollOffset: 100,
          heroHeight: 0,
          barHeight: 80,
          fadeDistance: 200,
        ),
        closeTo(0.5, 1e-9),
      );
    });
  });

  group('shell system bars', () {
    test('touch is edge-to-edge; TV and desktop keep sticky immersive', () {
      expect(
        ShellSystemUi.shellModeFor(ShellProfile.mobile, android: true),
        SystemUiMode.edgeToEdge,
      );
      expect(
        ShellSystemUi.shellModeFor(ShellProfile.tv, android: true),
        SystemUiMode.immersiveSticky,
      );
      expect(
        ShellSystemUi.shellModeFor(ShellProfile.desktop, android: true),
        SystemUiMode.immersiveSticky,
      );
    });

    test('off Android the shell leaves system bars alone', () {
      for (final p in ShellProfile.values) {
        expect(ShellSystemUi.shellModeFor(p, android: false), isNull);
      }
    });
  });

  group('toasts', () {
    tearDown(() {
      for (final e in List.of(ForjaToast.controller.entries)) {
        ForjaToast.controller.dismiss(e.id);
      }
      ShellBus.hideGlobalNav.value = false;
    });

    Future<Rect> toastRect(
      WidgetTester tester, {
      required ShellProfile profile,
      required Size size,
      EdgeInsets padding = EdgeInsets.zero,
    }) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _wrap(
          const ForjaToastHost(child: SizedBox.expand()),
          profile: profile,
          size: size,
          padding: padding,
        ),
      );
      ForjaToast.info('3 updates available', duration: Duration.zero);
      await tester.pump();
      await tester.pump();
      return tester.getRect(find.text('3 updates available'));
    }

    testWidgets('mobile: toast docks above the bottom bar, below the title', (
      tester,
    ) async {
      const padding = EdgeInsets.only(top: 28, bottom: 24);
      final rect = await toastRect(
        tester,
        profile: ShellProfile.mobile,
        size: _phonePortrait,
        padding: padding,
      );
      expect(rect.top, greaterThan(_phonePortrait.height / 2));
      expect(
        rect.bottom,
        lessThanOrEqualTo(
          _phonePortrait.height - padding.bottom - ShellTokens.bottomNavHeight,
        ),
      );
      expect(rect.right, lessThanOrEqualTo(_phonePortrait.width));
    });

    testWidgets('desktop: toast stays top-right', (tester) async {
      final rect = await toastRect(
        tester,
        profile: ShellProfile.desktop,
        size: const Size(1280, 800),
      );
      expect(rect.top, lessThan(200));
    });
  });
}
