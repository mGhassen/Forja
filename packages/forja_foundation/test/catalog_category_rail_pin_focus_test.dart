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
  bool mouseDownActivates = true,
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
  testWidgets('pinned category shows pin icon on leanback without hold', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        child: CatalogCategoryRail(
          selectedId: 'a',
          items: const [
            CatalogCategoryItem(
              id: 'a',
              label: 'EU | FR | REUNION',
              pinnable: true,
              pinned: true,
            ),
            CatalogCategoryItem(id: 'b', label: 'Sports', pinnable: true),
          ],
          onTogglePin: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
  });

  testWidgets('hold OK then → focuses category pin (nested focus allowed)', (
    tester,
  ) async {
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
  });

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

  testWidgets('OK on pin scrolls to new index and focuses the category', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(child: const SizedBox(height: 280, child: _PinRailHost())),
    );
    await tester.pumpAndSettle();

    final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));
    final offsetBefore = scrollState.position.maxScrollExtent;
    expect(
      offsetBefore,
      greaterThan(0),
      reason: 'list must be taller than rail',
    );
    scrollState.position.jumpTo(offsetBefore);
    await tester.pumpAndSettle();

    final zFinder = find.text('Z');
    expect(zFinder, findsOneWidget);

    Focus.of(tester.element(zFinder)).requestFocus();
    await tester.pump();

    // Hold OK reveals pin (pin-only rail — no floating reorder).
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(seconds: 2, milliseconds: 50));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(find.byIcon(Icons.push_pin_outlined), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    // OK on pin.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    // Z is first under Favorites.
    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => s == 'Favorites' || s == 'A' || s == 'Z')
        .toList();
    expect(labels.take(3).toList(), ['Favorites', 'Z', 'A']);

    final zFocus = Focus.of(tester.element(find.text('Z')));
    expect(zFocus.hasFocus, isTrue, reason: 'pin must focus the category');

    final offsetAfter = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .pixels;
    expect(
      offsetAfter,
      lessThan(offsetBefore),
      reason: 'rail must scroll up to the pinned row',
    );
  });

  testWidgets('selecting a category scrolls it into view', (tester) async {
    await tester.pumpWidget(
      _wrap(
        tv: false,
        child: const SizedBox(height: 280, child: _SelectScrollRailHost()),
      ),
    );
    await tester.pumpAndSettle();

    final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));
    final maxExtent = scrollState.position.maxScrollExtent;
    expect(maxExtent, greaterThan(0));
    scrollState.position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(scrollState.position.pixels, 0);

    // Select a row that is off-screen below.
    final host = tester.state<_SelectScrollRailHostState>(
      find.byType(_SelectScrollRailHost),
    );
    host.select('z');
    await tester.pumpAndSettle();

    final offsetAfter = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .pixels;
    expect(
      offsetAfter,
      greaterThan(0),
      reason: 'rail must scroll down to the selected category',
    );
  });

  testWidgets('search list expand pins selected category near 4th row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        tv: false,
        child: const SizedBox(
          height: 280,
          child: _SearchExpandScrollRailHost(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final host = tester.state<_SearchExpandScrollRailHostState>(
      find.byType(_SearchExpandScrollRailHost),
    );
    // Filtered search hits, then expand back to full list (clear search).
    host.expandToFull();
    await tester.pumpAndSettle();

    final offsetAfter = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .pixels;
    expect(
      offsetAfter,
      greaterThan(0),
      reason: 'clearing search must scroll the restored category into view',
    );
  });
}

class _SelectScrollRailHost extends StatefulWidget {
  const _SelectScrollRailHost();

  @override
  State<_SelectScrollRailHost> createState() => _SelectScrollRailHostState();
}

class _SelectScrollRailHostState extends State<_SelectScrollRailHost> {
  String _selected = 'a';

  late final List<CatalogCategoryItem> _items = [
    for (var i = 0; i < 24; i++)
      CatalogCategoryItem(
        id: String.fromCharCode(97 + (i % 26)) + '$i',
        label: 'Cat $i',
      ),
    const CatalogCategoryItem(id: 'z', label: 'Z'),
  ];

  void select(String id) => setState(() => _selected = id);

  @override
  Widget build(BuildContext context) {
    return CatalogCategoryRail(
      selectedId: _selected,
      items: _items,
      onSelect: select,
    );
  }
}

class _SearchExpandScrollRailHost extends StatefulWidget {
  const _SearchExpandScrollRailHost();

  @override
  State<_SearchExpandScrollRailHost> createState() =>
      _SearchExpandScrollRailHostState();
}

class _SearchExpandScrollRailHostState
    extends State<_SearchExpandScrollRailHost> {
  var _filtered = true;
  static const _selected = 'z';

  late final List<CatalogCategoryItem> _all = [
    for (var i = 0; i < 24; i++)
      CatalogCategoryItem(id: 'c$i', label: 'Cat $i'),
    const CatalogCategoryItem(id: 'z', label: 'Z'),
  ];

  void expandToFull() => setState(() => _filtered = false);

  @override
  Widget build(BuildContext context) {
    final items = _filtered
        ? const [
            CatalogCategoryItem(id: 'z', label: 'Z'),
            CatalogCategoryItem(id: 'c0', label: 'Cat 0'),
          ]
        : _all;
    return CatalogCategoryRail(selectedId: _selected, items: items);
  }
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

class _PinRailHost extends StatefulWidget {
  const _PinRailHost();

  @override
  State<_PinRailHost> createState() => _PinRailHostState();
}

class _PinRailHostState extends State<_PinRailHost> {
  late List<CatalogCategoryItem> _items;

  @override
  void initState() {
    super.initState();
    _items = [
      const CatalogCategoryItem(
        id: 'fav',
        label: 'Favorites',
        fixed: true,
        icon: Icons.star_rounded,
      ),
      for (var i = 0; i < 26; i++)
        CatalogCategoryItem(
          id: String.fromCharCode(97 + i),
          label: String.fromCharCode(65 + i),
          pinnable: true,
        ),
    ];
  }

  void _togglePin(String id) {
    setState(() {
      final idx = _items.indexWhere((e) => e.id == id);
      if (idx < 0) return;
      final item = _items[idx];
      final pinning = !item.pinned;
      final next = [..._items]..removeAt(idx);
      final updated = CatalogCategoryItem(
        id: item.id,
        label: item.label,
        pinnable: true,
        pinned: pinning,
      );
      if (pinning) {
        final insertAt = next.indexWhere((e) => !e.fixed);
        next.insert(insertAt < 0 ? next.length : insertAt, updated);
      } else {
        next.insert(idx.clamp(0, next.length), updated);
      }
      _items = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CatalogCategoryRail(
      selectedId: 'z',
      items: _items,
      onTogglePin: _togglePin,
    );
  }
}
