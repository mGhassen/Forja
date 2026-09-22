import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/chrome/catalog_category_rail.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Host-like tap: mirrors app [FocusableControl] descendants + key order.
Widget _tvTap({
  required BuildContext context,
  required Widget child,
  VoidCallback? onTap,
  double borderRadius = 12,
  double scaleOnFocus = 1,
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
  bool showFocusFill = true,
  bool showFocusRail = false,
  bool suppressInkHover = false,
  bool allowNestedFocus = false,
  FocusOnKeyEventCallback? onKeyEvent,
}) {
  return Focus(
    focusNode: focusNode,
    autofocus: autoFocus,
    descendantsAreFocusable: allowNestedFocus,
    descendantsAreTraversable: allowNestedFocus,
    onFocusChange: onFocusChange,
    onKeyEvent: (node, event) {
      final custom = onKeyEvent?.call(node, event);
      if (custom != null && custom != KeyEventResult.ignored) return custom;
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowRight &&
          onRightEdge != null) {
        onRightEdge();
        return KeyEventResult.handled;
      }
      if (onTap == null) return KeyEventResult.ignored;
      if (!ShellPaintScope.isActivateKeyOf(context, event)) {
        return KeyEventResult.ignored;
      }
      onTap();
      return KeyEventResult.handled;
    },
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    ),
  );
}

Widget _wrap({required Widget child, bool tv = true}) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1280, 720)),
      child: ShellPaintScope(
        useTvFocus: tv,
        scaleOnHover: !tv,
        usesTvDensity: tv,
        focusStyled: (_, {required focused}) => focused,
        focusableTapBuilder: tv ? _tvTap : null,
        child: Scaffold(body: SizedBox(width: 280, child: child)),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'hold OK then → focuses category pin (nested focus allowed)',
    (tester) async {
      var pinned = false;
      await tester.pumpWidget(
        _wrap(
          child: CatalogCategoryRail(
            selectedId: 'a',
            items: const [
              CatalogCategoryItem(
                id: 'a',
                label: 'EU | FR | REUNION',
                pinnable: true,
              ),
            ],
            onTogglePin: (_) => pinned = !pinned,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rowFinder = find.text('EU | FR | REUNION');
      expect(rowFinder, findsOneWidget);
      final rowFocus = Focus.of(tester.element(rowFinder));
      rowFocus.requestFocus();
      await tester.pump();
      expect(rowFocus.hasFocus, isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(seconds: 2, milliseconds: 50));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pump();

      // Pin icon mounted after reveal.
      expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      final pinFocus = Focus.of(
        tester.element(find.byIcon(Icons.push_pin_outlined)),
      );
      expect(pinFocus.hasFocus, isTrue, reason: '→ after hold must land on pin');
      expect(pinned, isFalse);
    },
  );

  testWidgets(
    'floating reorder ↑ keeps focus on moved category (not neighbor)',
    (tester) async {
      await tester.pumpWidget(_wrap(child: const _ReorderRailHost()));
      await tester.pumpAndSettle();

      final bFinder = find.text('B');
      expect(bFinder, findsOneWidget);
      Focus.of(tester.element(bFinder)).requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(seconds: 2, milliseconds: 50));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pump();

      // Float shows pin on B.
      expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      // B moved above A.
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .where((s) => s == 'A' || s == 'B' || s == 'C')
          .toList();
      expect(texts, ['B', 'A', 'C']);

      // Focus stayed on B (not A).
      final bFocus = Focus.of(tester.element(find.text('B')));
      expect(bFocus.hasFocus, isTrue, reason: 'float ↑ must keep focus on B');
    },
  );

  testWidgets(
    'desktop drag proxy teardown does not trip InheritedElement dependents',
    (tester) async {
      // Regression: proxyDecorator used InheritedWidget + dependOn →
      // '_dependents.isEmpty' when the overlay dropped.
      await tester.pumpWidget(
        _wrap(tv: false, child: const _ReorderRailHost()),
      );
      await tester.pumpAndSettle();

      final drag = await tester.startGesture(tester.getCenter(find.text('B')));
      // Match _DelayedReorderDragStartListener delay (1500ms).
      await tester.pump(const Duration(milliseconds: 1500));
      await drag.moveBy(const Offset(0, 40));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}

class _ReorderRailHost extends StatefulWidget {
  const _ReorderRailHost();

  @override
  State<_ReorderRailHost> createState() => _ReorderRailHostState();
}

class _ReorderRailHostState extends State<_ReorderRailHost> {
  var _items = const [
    CatalogCategoryItem(id: 'a', label: 'A', pinnable: true),
    CatalogCategoryItem(id: 'b', label: 'B', pinnable: true),
    CatalogCategoryItem(id: 'c', label: 'C', pinnable: true),
  ];

  @override
  Widget build(BuildContext context) {
    return CatalogCategoryRail(
      selectedId: 'b',
      canReorder: true,
      items: _items,
      onTogglePin: (_) {},
      onReorder: (oldIndex, newIndex) {
        setState(() {
          final next = [..._items];
          final item = next.removeAt(oldIndex);
          next.insert(newIndex, item);
          _items = next;
        });
      },
    );
  }
}
