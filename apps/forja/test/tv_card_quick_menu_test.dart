import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/kit_card_quick_actions.dart';
import 'package:forja/shared/engine/runtime/open/meta_surface_open.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/core/shell_paint_host_install.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_card_quick_menu.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/tokens/card_quick_menu_tokens.dart';
import 'package:forja_foundation/widgets/catalog/card_quick_menu.dart';
import 'package:forja_foundation/widgets/catalog/interactive_poster_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Synthetic catalog tab — proves the generic hold/menu contract, not a
/// shipped hub id.
const _tab = 'catalog';

Widget _wrapTv(Widget child) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1920, 1080)),
      child: ShellScope(
        profile: ShellProfile.tv,
        config: shellPlatformConfigFor(ShellProfile.tv),
        child: FocusScope(
          child: TvFocusGraph(
            tabId: _tab,
            child: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      ),
    ),
  );
}

class _Counts {
  int tap = 0;
  int hold = 0;
}

Widget _card(_Counts c, {FocusNode? focusNode}) {
  return Focus(
    // Outer node so the test can request focus onto the card's own control.
    focusNode: focusNode,
    skipTraversal: true,
    canRequestFocus: false,
    child: InteractivePosterCard(
      imageUrl: '',
      title: 'Synthetic',
      listIndex: 0,
      onTap: () => c.tap++,
      onLongPress: () => c.hold++,
      longPressDuration: CardQuickMenuTokens.holdDelay,
    ),
  );
}

Future<void> _focusCard(WidgetTester tester) async {
  final node = Focus.of(tester.element(find.text('Synthetic').first));
  node.requestFocus();
  await tester.pump();
  expect(node.hasFocus, isTrue);
}

List<CardQuickMenuAction> _actions(List<String> fired) => [
  CardQuickMenuAction(
    id: 'a',
    label: 'Alpha',
    icon: Icons.play_arrow_rounded,
    onTap: () => fired.add('a'),
  ),
  CardQuickMenuAction(
    id: 'b',
    label: 'Beta',
    icon: Icons.info_outline_rounded,
    onTap: () => fired.add('b'),
  ),
];

MetaItem _item({
  String id = 'x1',
  String type = 'movie',
  MetaOpen? open = const MetaOpen(surface: 'test-surface', id: '42'),
}) => MetaItem(id: id, type: type, name: 'Synthetic', open: open);

void main() {
  setUpAll(installShellPaintHostAdapters);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ShellTvFocusCoordinator.setNavOrder([_tab]);
    ShellTvFocus.currentNavTabId = _tab;
    ShellTvFocusCoordinator.clearTab(_tab);
    ShellTvCardQuickMenu.resetForTest();
    MetaSurfaceOpen.debugReset();
  });

  tearDownAll(MetaSurfaceOpen.debugReset);

  group('OK hold on a focused card', () {
    testWidgets('short press activates the card once, no hold', (tester) async {
      final c = _Counts();
      await tester.pumpWidget(_wrapTv(_card(c)));
      await _focusCard(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 120));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(c.tap, 1);
      expect(c.hold, 0);
    });

    testWidgets('hold past the threshold opens the menu, not the card', (
      tester,
    ) async {
      final c = _Counts();
      await tester.pumpWidget(_wrapTv(_card(c)));
      await _focusCard(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(
        CardQuickMenuTokens.holdDelay + const Duration(milliseconds: 50),
      );
      expect(c.hold, 1);
      expect(c.tap, 0);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(c.tap, 0, reason: 'key-up after a hold must not also activate');
      expect(c.hold, 1);
    });

    testWidgets('key-up without a matching key-down does nothing', (
      tester,
    ) async {
      final c = _Counts();
      await tester.pumpWidget(_wrapTv(_card(c)));
      await _focusCard(tester);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(seconds: 1));

      expect(c.tap, 0);
      expect(c.hold, 0);
    });

    testWidgets('card without an explicit hold length keeps the 2 s default', (
      tester,
    ) async {
      // Other long-press consumers (grid "open with") pass no duration; the
      // quick-menu wire passes CardQuickMenuTokens.holdDelay explicitly.
      final c = _Counts();
      await tester.pumpWidget(
        _wrapTv(
          InteractivePosterCard(
            imageUrl: '',
            title: 'Synthetic',
            listIndex: 0,
            onTap: () => c.tap++,
            onLongPress: () => c.hold++,
          ),
        ),
      );
      await _focusCard(tester);
      final card = tester.widget<InteractivePosterCard>(
        find.byType(InteractivePosterCard),
      );
      expect(card.longPressDuration, const Duration(milliseconds: 2000));
      expect(
        card.longPressDuration,
        greaterThan(CardQuickMenuTokens.holdDelay),
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(
        CardQuickMenuTokens.holdDelay + const Duration(milliseconds: 100),
      );
      expect(c.hold, 0, reason: 'quick-menu threshold must not retime it');
      await tester.pump(const Duration(milliseconds: 1500));
      expect(c.hold, 1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(c.tap, 0);
    });

    testWidgets('remote MENU key opens the menu for the focused card', (
      tester,
    ) async {
      final c = _Counts();
      await tester.pumpWidget(_wrapTv(_card(c)));
      await _focusCard(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.contextMenu);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.contextMenu);
      await tester.pump();

      expect(c.hold, 1);
      expect(c.tap, 0);
    });
  });

  group('ShellTvCardQuickMenu overlay', () {
    testWidgets('opens with the first action focused; Back restores the card', (
      tester,
    ) async {
      final c = _Counts();
      final fired = <String>[];
      await tester.pumpWidget(_wrapTv(_card(c)));
      await _focusCard(tester);
      final cardNode = FocusManager.instance.primaryFocus!;

      ShellTvCardQuickMenu.show(
        tester.element(find.text('Synthetic').first),
        actions: _actions(fired),
        title: 'Synthetic',
      );
      await tester.pump();
      await tester.pump();

      expect(ShellTvCardQuickMenu.isOpen, isTrue);
      expect(find.byType(CardQuickMenu), findsOneWidget);
      final alphaNode = Focus.of(tester.element(find.text('Alpha')));
      expect(alphaNode.hasFocus, isTrue);
      expect(cardNode.hasFocus, isFalse);

      // Hardware Back lands on the coordinator before Focus onKey.
      expect(ShellTvFocusCoordinator.tryDismissTransientOverlay(), isTrue);
      await tester.pump();
      await tester.pump();

      expect(ShellTvCardQuickMenu.isOpen, isFalse);
      expect(find.byType(CardQuickMenu), findsNothing);
      expect(cardNode.hasFocus, isTrue);
      expect(fired, isEmpty);
      // Slot released — a second Back is not swallowed by a closed menu.
      expect(ShellTvFocusCoordinator.tryDismissTransientOverlay(), isFalse);
    });

    testWidgets('Escape inside the menu closes it and restores the card', (
      tester,
    ) async {
      final c = _Counts();
      await tester.pumpWidget(_wrapTv(_card(c)));
      await _focusCard(tester);
      final cardNode = FocusManager.instance.primaryFocus!;

      ShellTvCardQuickMenu.show(
        tester.element(find.text('Synthetic').first),
        actions: _actions([]),
      );
      await tester.pump();
      await tester.pump();
      expect(ShellTvCardQuickMenu.isOpen, isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump();

      expect(ShellTvCardQuickMenu.isOpen, isFalse);
      expect(cardNode.hasFocus, isTrue);
    });

    testWidgets('OK on an action runs it, closes, and refocuses the card', (
      tester,
    ) async {
      final c = _Counts();
      final fired = <String>[];
      await tester.pumpWidget(_wrapTv(_card(c)));
      await _focusCard(tester);
      final cardNode = FocusManager.instance.primaryFocus!;

      ShellTvCardQuickMenu.show(
        tester.element(find.text('Synthetic').first),
        actions: _actions(fired),
      );
      await tester.pump();
      await tester.pump();

      // ↓ to the second row, then OK.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(Focus.of(tester.element(find.text('Beta'))).hasFocus, isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pump();
      await tester.pump();

      expect(fired, ['b']);
      expect(ShellTvCardQuickMenu.isOpen, isFalse);
      expect(cardNode.hasFocus, isTrue);
      expect(c.tap, 0, reason: 'menu OK never leaks to the card');
    });

    testWidgets('arrows stay inside the menu while open', (tester) async {
      final c = _Counts();
      await tester.pumpWidget(_wrapTv(_card(c)));
      await _focusCard(tester);

      ShellTvCardQuickMenu.show(
        tester.element(find.text('Synthetic').first),
        actions: _actions([]),
      );
      await tester.pump();
      await tester.pump();

      for (final key in [
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowDown,
      ]) {
        await tester.sendKeyDownEvent(key);
        await tester.sendKeyUpEvent(key);
        await tester.pump();
      }
      final focused = FocusManager.instance.primaryFocus;
      final inMenu = find.ancestor(
        of: find.byWidgetPredicate((w) => w is Focus && w.focusNode == focused),
        matching: find.byType(CardQuickMenu),
      );
      expect(inMenu, findsOneWidget);
      expect(ShellTvCardQuickMenu.isOpen, isTrue);
    });

    testWidgets('empty actions never open', (tester) async {
      final c = _Counts();
      await tester.pumpWidget(_wrapTv(_card(c)));
      await _focusCard(tester);

      ShellTvCardQuickMenu.show(
        tester.element(find.text('Synthetic').first),
        actions: const [],
      );
      await tester.pump();
      expect(ShellTvCardQuickMenu.isOpen, isFalse);
    });
  });

  group('KitCardQuickActions', () {
    testWidgets('playable card → Play · Details · Add to My List', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapTv(const SizedBox()));
      final ctx = tester.element(find.byType(SizedBox));

      final actions = KitCardQuickActions.build(
        ctx,
        pluginId: 'test-hub-a',
        item: _item(),
      );
      expect(actions.map((a) => a.id), [
        KitCardQuickActions.playId,
        KitCardQuickActions.detailsId,
        KitCardQuickActions.listId,
      ]);
      expect(actions.map((a) => a.label), [
        'Play',
        'Details',
        'Add to My List',
      ]);
    });

    testWidgets('surface-handled card → one Open row, never Play + Details', (
      tester,
    ) async {
      MetaSurfaceOpen.register('test-surface', (_, _) {});
      await tester.pumpWidget(_wrapTv(const SizedBox()));
      final ctx = tester.element(find.byType(SizedBox));

      final actions = KitCardQuickActions.build(
        ctx,
        pluginId: 'test-hub-a',
        item: _item(),
      );
      expect(actions.map((a) => a.id), [
        KitCardQuickActions.openId,
        KitCardQuickActions.listId,
      ]);
      expect(actions.first.label, 'Open');
      expect(
        actions.map((a) => a.id),
        isNot(contains(KitCardQuickActions.playId)),
      );
      expect(
        actions.map((a) => a.id),
        isNot(contains(KitCardQuickActions.detailsId)),
      );
    });

    testWidgets('pack-emitted list status → Remove from My List', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapTv(const SizedBox()));
      final ctx = tester.element(find.byType(SizedBox));

      final actions = KitCardQuickActions.build(
        ctx,
        pluginId: 'test-hub-a',
        item: _item(),
        knownStatus: 'watching',
      );
      expect(actions.last.label, 'Remove from My List');
    });

    testWidgets('collection card has no Play; card without a route has no menu', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapTv(const SizedBox()));
      final ctx = tester.element(find.byType(SizedBox));

      final collection = KitCardQuickActions.build(
        ctx,
        pluginId: 'test-hub-a',
        item: _item(type: 'collection'),
      );
      expect(
        collection.map((a) => a.id),
        isNot(contains(KitCardQuickActions.playId)),
      );
      expect(collection.map((a) => a.id), contains(KitCardQuickActions.detailsId));

      final noRoute = KitCardQuickActions.build(
        ctx,
        pluginId: 'test-hub-a',
        item: _item(id: '', open: null),
      );
      expect(noRoute, isEmpty);
      expect(
        KitCardQuickActions.openerFor(
          ctx,
          pluginId: 'test-hub-a',
          item: _item(id: '', open: null),
        ),
        isNull,
      );
    });

    testWidgets('card without open keeps Details but no My List', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapTv(const SizedBox()));
      final ctx = tester.element(find.byType(SizedBox));

      final actions = KitCardQuickActions.build(
        ctx,
        pluginId: 'test-hub-a',
        item: _item(open: null),
      );
      expect(actions.map((a) => a.id), [
        KitCardQuickActions.playId,
        KitCardQuickActions.detailsId,
      ]);
    });

    testWidgets('leanback profile gets an opener', (tester) async {
      await tester.pumpWidget(_wrapTv(const SizedBox()));
      final ctx = tester.element(find.byType(SizedBox));
      expect(
        KitCardQuickActions.openerFor(
          ctx,
          pluginId: 'test-hub-a',
          item: _item(),
        ),
        isNotNull,
      );
    });
  });
}
