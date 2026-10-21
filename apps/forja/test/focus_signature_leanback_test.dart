import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/nav/chrome_menu_item.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/chrome/kit_chrome_top_bar.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/core/shell_paint_host_install.dart';
import 'package:forja/shell/nav/shell_nav_rail.dart';
import 'package:forja_foundation/tokens/focus_chrome_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/focus_chrome.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';

/// One leanback focus signature (RFC-122 T06): accent ring + glow + lift from
/// [FocusChromeTokens] on cards, top-menu tabs, chips, nav rail items and
/// settings rows. Desktop hover keeps its own look.
Widget _wrap(ShellProfile profile, Widget child) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1280, 720)),
      child: ShellScope(
        profile: profile,
        config: shellPlatformConfigFor(profile),
        child: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    ),
  );
}

bool _isLeanbackRing(Decoration? d) {
  if (d is! BoxDecoration) return false;
  final b = d.border;
  if (b is! Border) return false;
  return b.top.color == FocusChromeTokens.ringColor &&
      b.top.width == FocusChromeTokens.ringWidth;
}

bool _hasGlow(Decoration? d) {
  if (d is! BoxDecoration) return false;
  final shadows = d.boxShadow;
  if (shadows == null) return false;
  return shadows.any(
    (s) =>
        s.blurRadius == FocusChromeTokens.glowBlur &&
        s.color == FocusChromeTokens.glowColor(),
  );
}

Iterable<Decoration?> _decorationsUnder(WidgetTester tester, Finder root) {
  final boxes = tester
      .widgetList<DecoratedBox>(
        find.descendant(of: root, matching: find.byType(DecoratedBox)),
      )
      .map((w) => w.decoration);
  final animated = tester
      .widgetList<AnimatedContainer>(
        find.descendant(of: root, matching: find.byType(AnimatedContainer)),
      )
      .map((w) => w.decoration);
  return [...boxes, ...animated];
}

bool _paintsLeanbackRing(
  WidgetTester tester,
  Finder root, {
  required bool withGlow,
}) {
  return _decorationsUnder(
    tester,
    root,
  ).any((d) => _isLeanbackRing(d) && (!withGlow || _hasGlow(d)));
}

double _controlScale(WidgetTester tester, Finder root) {
  final transforms = tester.widgetList<Transform>(
    find.descendant(of: root, matching: find.byType(Transform)),
  );
  expect(transforms, isNotEmpty, reason: 'FocusableControl scale transform');
  return transforms.first.transform.getMaxScaleOnAxis();
}

Future<void> _focusControl(WidgetTester tester, Finder control) async {
  final focus = tester.widget<Focus>(
    find.descendant(of: control, matching: find.byType(Focus)).first,
  );
  focus.focusNode!.requestFocus();
  // Focus applies in a microtask; dependent setState lands a frame later.
  await tester.pump();
  await tester.pump();
}

Future<void> _hover(WidgetTester tester, Finder target) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(target));
  await tester.pumpAndSettle();
}

Widget _topBar() {
  return SizedBox(
    width: 1280,
    height: 200,
    child: KitChromeTopBar(
      tabId: 'test-tab',
      selectedMenuId: ValueNotifier<String?>(null),
      selectedCategoryId: ValueNotifier<String?>(null),
      menus: const [
        ChromeMenuItem(id: 'm1', label: 'Alpha'),
        ChromeMenuItem(id: 'm2', label: 'Beta'),
      ],
      categories: const [],
      scrollOffset: ValueNotifier<double>(0),
      heroHeight: ValueNotifier<double>(400),
      onSearch: null,
    ),
  );
}

Finder _tab(String label) => find
    .ancestor(of: find.text(label), matching: find.byType(FocusableControl))
    .first;

Finder _navFocus(String id) =>
    find.byWidgetPredicate((w) => w is Focus && w.debugLabel == 'nav-$id');

Future<void> _focusNavItem(WidgetTester tester, String id) async {
  final childFinder = find.descendant(
    of: _navFocus(id),
    matching: find.byType(GestureDetector),
  );
  final el = tester.element(childFinder.first);
  FocusScope.of(el).requestFocus(Focus.of(el));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(installShellPaintHostAdapters);

  group('catalog card', () {
    Widget card(FocusNode node) => FocusableControl(
      focusNode: node,
      showFocusBorder: true,
      onTap: () {},
      child: const SizedBox(width: 140, height: 200),
    );

    testWidgets('leanback focus: accent ring + glow + card lift, instant', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(_wrap(ShellProfile.tv, card(node)));
      final root = find.byType(FocusableControl);
      expect(_paintsLeanbackRing(tester, root, withGlow: true), isFalse);

      node.requestFocus();
      await tester.pump();

      expect(_paintsLeanbackRing(tester, root, withGlow: true), isTrue);
      expect(
        _controlScale(tester, root),
        closeTo(FocusChromeTokens.cardScale, 1e-6),
      );
    });

    testWidgets('desktop hover: no ring under the pointer, same lift', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(_wrap(ShellProfile.desktop, card(node)));
      final root = find.byType(FocusableControl);

      await _hover(tester, root);

      expect(_paintsLeanbackRing(tester, root, withGlow: false), isFalse);
      expect(
        _decorationsUnder(tester, root).any(_hasGlow),
        isFalse,
        reason: 'no glow on desktop',
      );
      expect(
        _controlScale(tester, root),
        closeTo(FocusChromeTokens.cardScale, 1e-6),
      );
    });
  });

  group('top-menu text tab', () {
    testWidgets('leanback focus: accent pill around the tab text + chip lift', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(ShellProfile.tv, _topBar()));
      final alpha = _tab('Alpha');
      final beta = _tab('Beta');

      await _focusControl(tester, alpha);

      final ring = tester.widget<FocusChromeRing>(
        find.descendant(of: alpha, matching: find.byType(FocusChromeRing)),
      );
      expect(ring.active, isTrue);
      expect(_paintsLeanbackRing(tester, alpha, withGlow: true), isTrue);
      expect(
        _controlScale(tester, alpha),
        closeTo(FocusChromeTokens.chipScale, 1e-6),
      );
      final betaRing = tester.widget<FocusChromeRing>(
        find.descendant(of: beta, matching: find.byType(FocusChromeRing)),
      );
      expect(betaRing.active, isFalse);
      expect(_paintsLeanbackRing(tester, beta, withGlow: false), isFalse);
    });

    testWidgets('desktop hover: underline look only, no pill, no lift', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(ShellProfile.desktop, _topBar()));
      final alpha = _tab('Alpha');

      await _hover(tester, find.text('Alpha'));

      final ring = tester.widget<FocusChromeRing>(
        find.descendant(of: alpha, matching: find.byType(FocusChromeRing)),
      );
      expect(ring.active, isFalse);
      expect(_paintsLeanbackRing(tester, alpha, withGlow: false), isFalse);
      expect(_controlScale(tester, alpha), closeTo(1.0, 1e-6));
    });
  });

  group('chip', () {
    testWidgets('leanback focus: ring + glow + backplate + chip lift', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(ShellProfile.tv, ForjaShellChip(label: 'Action', onTap: () {})),
      );
      final root = find.byType(FocusableControl);

      await _focusControl(tester, root);

      expect(_paintsLeanbackRing(tester, root, withGlow: true), isTrue);
      expect(
        _controlScale(tester, root),
        closeTo(FocusChromeTokens.chipScale, 1e-6),
      );
    });

    testWidgets('desktop hover: flat pill, no ring, no lift', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ShellProfile.desktop,
          ForjaShellChip(label: 'Action', onTap: () {}),
        ),
      );
      final root = find.byType(FocusableControl);

      await _hover(tester, root);

      expect(_paintsLeanbackRing(tester, root, withGlow: false), isFalse);
      expect(_controlScale(tester, root), closeTo(1.0, 1e-6));
    });
  });

  group('nav rail item', () {
    Widget rail() => ShellNavRail(
      visibleIds: const ['home', 'search', 'settings'],
      selectedIndex: 0,
      onDestinationSelected: (_) {},
    );

    testWidgets('leanback focus: accent backplate + ring behind the icon', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(ShellProfile.tv, rail()));

      await _focusNavItem(tester, 'search');

      final ring = tester.widget<FocusChromeRing>(
        find.descendant(
          of: _navFocus('search'),
          matching: find.byType(FocusChromeRing),
        ),
      );
      expect(ring.active, isTrue);
      expect(ring.behind, isTrue);
      expect(ring.fill, FocusChromeTokens.backplateFill());
      expect(
        _paintsLeanbackRing(tester, _navFocus('search'), withGlow: true),
        isTrue,
      );
      // Idle neighbor stays bare.
      final home = tester.widget<FocusChromeRing>(
        find.descendant(
          of: _navFocus('home'),
          matching: find.byType(FocusChromeRing),
        ),
      );
      expect(home.active, isFalse);
    });

    testWidgets('desktop hover: label reveal only, no backplate', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(ShellProfile.desktop, rail()));

      await _hover(tester, _navFocus('search'));

      final ring = tester.widget<FocusChromeRing>(
        find.descendant(
          of: _navFocus('search'),
          matching: find.byType(FocusChromeRing),
        ),
      );
      expect(ring.active, isFalse);
      expect(
        _paintsLeanbackRing(tester, _navFocus('search'), withGlow: false),
        isFalse,
      );
    });
  });

  group('settings row', () {
    Widget row(FocusNode node) => FocusableControl(
      focusNode: node,
      scaleOnFocus: FocusChromeTokens.rowScale,
      showFocusRail: true,
      borderRadius: 8,
      onTap: () {},
      child: const SizedBox(width: 320, height: 44),
    );

    /// The rounded fill + ring layer (the control-sized AnimatedContainer).
    BoxDecoration ringLayer(WidgetTester tester) {
      final boxes = tester.widgetList<AnimatedContainer>(
        find.descendant(
          of: find.byType(FocusableControl),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final layer = boxes.firstWhere(
        (w) => (w.decoration as BoxDecoration).borderRadius != null,
      );
      return layer.decoration as BoxDecoration;
    }

    /// The leading accent bar layer painted on top of the ring.
    Finder accentBar(WidgetTester tester) {
      final bars = find.descendant(
        of: find.byType(FocusableControl),
        matching: find.byType(AnimatedContainer),
      );
      return find.byWidgetPredicate(
        (w) =>
            w is AnimatedContainer &&
            (w.decoration as BoxDecoration).borderRadius == null &&
            tester.widgetList(bars).contains(w),
      );
    }

    testWidgets('leanback focus: leading accent bar + rounded accent ring, '
        'no lift', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(_wrap(ShellProfile.tv, row(node)));

      node.requestFocus();
      await tester.pump();
      await tester.pump();

      final ring = ringLayer(tester);
      expect(
        ring.borderRadius,
        BorderRadius.circular(8),
        reason: 'ring follows the control radius',
      );
      expect(_isLeanbackRing(ring), isTrue);
      expect(_hasGlow(ring), isFalse, reason: 'rows: ring without glow');
      expect(ring.color, ForjaShellColors.inkHover);

      final bar = accentBar(tester);
      expect(bar, findsOneWidget);
      expect(
        (tester.widget<AnimatedContainer>(bar).decoration as BoxDecoration)
            .color,
        FocusChromeTokens.ringColor,
      );
      expect(tester.getSize(bar).width, FocusChromeTokens.railAccentWidth);
      expect(
        tester.getRect(bar).left,
        tester.getRect(find.byType(FocusableControl)).left,
        reason: 'bar hugs the leading edge',
      );
      expect(
        find.descendant(
          of: find.byType(FocusableControl),
          matching: find.byType(Transform),
        ),
        findsNothing,
        reason: 'rows do not lift',
      );
    });

    testWidgets('desktop hover: leading accent bar only', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(_wrap(ShellProfile.desktop, row(node)));

      await _hover(tester, find.byType(FocusableControl));

      final ring = ringLayer(tester);
      expect(ring.border, isNull);
      expect(ring.color, ForjaShellColors.inkHover);
      final bar = accentBar(tester);
      expect(
        (tester.widget<AnimatedContainer>(bar).decoration as BoxDecoration)
            .color,
        ForjaShellColors.brandGreen,
      );
      expect(tester.getSize(bar).width, FocusChromeTokens.railAccentWidth);
    });
  });
}
