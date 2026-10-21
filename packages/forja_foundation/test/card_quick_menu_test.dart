import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/card_quick_menu_tokens.dart';
import 'package:forja_foundation/widgets/catalog/card_quick_menu.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Minimal TV focusable so the foundation widget can be exercised without
/// the host [FocusableControl]: D-pad focus + Select → onTap.
Widget _stubFocusableTap({
  required BuildContext context,
  required Widget child,
  VoidCallback? onTap,
  double borderRadius = 12,
  double scaleOnFocus = 1.04,
  VoidCallback? onLeftEdge,
  VoidCallback? onUpEdge,
  VoidCallback? onDownEdge,
  VoidCallback? onRightEdge,
  ValueChanged<bool>? onFocusChange,
  ValueChanged<bool>? onHoverChange,
  FocusNode? focusNode,
  bool autoFocus = false,
  int? listIndex,
  bool navLeftAlways = false,
  int? gridIndex,
  int? gridColumns,
  String? tvTabId,
  String? tvRowId,
  int? tvItemIndex,
  ShellPaintTvZone? tvZone,
  ShellPaintEnsureVisible ensureVisibleMode = ShellPaintEnsureVisible.row,
  bool showFocusBorder = false,
  bool showFocusFill = false,
  bool showFocusRail = false,
  bool suppressInkHover = false,
  bool allowNestedFocus = false,
  FocusOnKeyEventCallback? onKeyEvent,
  bool mouseDownActivates = true,
}) {
  return Focus(
    focusNode: focusNode,
    autofocus: autoFocus,
    onFocusChange: onFocusChange,
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.select) {
        onTap?.call();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: child,
  );
}

Widget _host(Widget child, {required bool tv}) {
  return MaterialApp(
    home: Scaffold(
      body: ShellPaintScope(
        useTvFocus: tv,
        scaleOnHover: !tv,
        focusStyled: (_, {required focused}) => focused,
        usesTvDensity: tv,
        focusableTapBuilder: tv ? _stubFocusableTap : null,
        child: Center(child: child),
      ),
    ),
  );
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
  CardQuickMenuAction(
    id: 'c',
    label: 'Gamma',
    icon: Icons.bookmark_add_outlined,
    onTap: () => fired.add('c'),
  ),
];

void main() {
  group('cardQuickMenuOrigin', () {
    const screen = Size(1920, 1080);
    const menu = Size(200, 150);

    test('sits to the right of the card, top-aligned', () {
      const anchor = Rect.fromLTWH(300, 400, 160, 240);
      final o = cardQuickMenuOrigin(
        anchor: anchor,
        menu: menu,
        screen: screen,
        tv: true,
      );
      expect(o.dx, anchor.right + CardQuickMenuTokens.anchorGapTv);
      expect(o.dy, anchor.top);
    });

    test('flips to the left when the right side overflows', () {
      const anchor = Rect.fromLTWH(1700, 400, 160, 240);
      final o = cardQuickMenuOrigin(
        anchor: anchor,
        menu: menu,
        screen: screen,
        tv: true,
      );
      expect(o.dx, anchor.left - CardQuickMenuTokens.anchorGapTv - menu.width);
    });

    test('clamps inside the screen margin vertically', () {
      const anchor = Rect.fromLTWH(300, 1000, 160, 240);
      final o = cardQuickMenuOrigin(
        anchor: anchor,
        menu: menu,
        screen: screen,
        tv: false,
      );
      expect(
        o.dy,
        screen.height - CardQuickMenuTokens.screenMargin - menu.height,
      );
      const top = Rect.fromLTWH(300, -50, 160, 240);
      final o2 = cardQuickMenuOrigin(
        anchor: top,
        menu: menu,
        screen: screen,
        tv: false,
      );
      expect(o2.dy, CardQuickMenuTokens.screenMargin);
    });
  });

  testWidgets('paints title and every action label', (tester) async {
    final fired = <String>[];
    await tester.pumpWidget(
      _host(
        CardQuickMenu(title: 'Synthetic Title', actions: _actions(fired)),
        tv: false,
      ),
    );
    await tester.pump();

    expect(find.text('Synthetic Title'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);
    expect(find.byType(CardQuickMenuRow), findsNWidgets(3));
  });

  testWidgets('blank title paints no heading', (tester) async {
    await tester.pumpWidget(
      _host(CardQuickMenu(title: '  ', actions: _actions([])), tv: false),
    );
    await tester.pump();
    expect(find.text('  '), findsNothing);
    expect(find.byType(CardQuickMenuRow), findsNWidgets(3));
  });

  testWidgets('pointer tap on a row fires that action only', (tester) async {
    final fired = <String>[];
    await tester.pumpWidget(
      _host(CardQuickMenu(actions: _actions(fired)), tv: false),
    );
    await tester.pump();

    await tester.tap(find.text('Beta'));
    await tester.pump();
    expect(fired, ['b']);
  });

  testWidgets('TV: first row autofocuses and Select fires it', (tester) async {
    final fired = <String>[];
    await tester.pumpWidget(
      _host(
        CardQuickMenu(
          actions: _actions(fired),
          tvFocus: true,
          autoFocusFirst: true,
        ),
        tv: true,
      ),
    );
    await tester.pump();
    await tester.pump();

    final rows = tester
        .widgetList<CardQuickMenuRow>(find.byType(CardQuickMenuRow))
        .toList();
    expect(rows[0].autoFocus, isTrue);
    expect(rows[1].autoFocus, isFalse);
    expect(rows[2].autoFocus, isFalse);

    final firstNode = Focus.of(tester.element(find.text('Alpha')));
    expect(firstNode.hasFocus, isTrue);
    expect(FocusManager.instance.primaryFocus, same(firstNode));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(fired, ['a']);
  });

  testWidgets('TV density uses the leanback row tokens', (tester) async {
    await tester.pumpWidget(
      _host(CardQuickMenu(actions: _actions([]), tvFocus: true), tv: true),
    );
    await tester.pump();

    final icon = tester.widget<Icon>(find.byType(Icon).first);
    expect(icon.size, CardQuickMenuTokens.iconSizeTv);
    final box = tester.widget<ConstrainedBox>(
      find
          .descendant(
            of: find.byType(CardQuickMenu),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(box.constraints.minWidth, CardQuickMenuTokens.minWidthTv);
    expect(box.constraints.maxWidth, CardQuickMenuTokens.maxWidthTv);
  });
}
