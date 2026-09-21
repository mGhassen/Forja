import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/chrome/event_list_search.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

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
    onFocusChange: onFocusChange,
    onKeyEvent: (node, event) {
      final custom = onKeyEvent?.call(node, event);
      if (custom != null && custom != KeyEventResult.ignored) return custom;
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

void main() {
  testWidgets(
    'TV: closing expanded search returns focus to the search icon',
    (tester) async {
      var query = '';
      final searchKey = GlobalKey<EventListSearchState>();

      await tester.pumpWidget(
        MaterialApp(
          home: ShellPaintScope(
            useTvFocus: true,
            scaleOnHover: false,
            usesTvDensity: true,
            focusStyled: (_, {required focused}) => focused,
            focusableTapBuilder: _tvTap,
            child: Scaffold(
              body: Center(
                child: EventListSearch(
                  key: searchKey,
                  query: query,
                  onQueryChanged: (q) => query = q,
                  debugLabel: 'test-event-search',
                ),
              ),
            ),
          ),
        ),
      );

      final state = searchKey.currentState!;
      state.openSearch();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(FocusManager.instance.primaryFocus?.debugLabel, 'test-event-search');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'test-event-search-tool',
      );
      expect(query, '');
    },
  );

  testWidgets(
    'TV: closing via × returns focus to the search icon',
    (tester) async {
      var query = 'espn';
      final searchKey = GlobalKey<EventListSearchState>();

      await tester.pumpWidget(
        MaterialApp(
          home: ShellPaintScope(
            useTvFocus: true,
            scaleOnHover: false,
            usesTvDensity: true,
            focusStyled: (_, {required focused}) => focused,
            focusableTapBuilder: _tvTap,
            child: Scaffold(
              body: Center(
                child: EventListSearch(
                  key: searchKey,
                  query: query,
                  onQueryChanged: (q) => query = q,
                  debugLabel: 'test-event-search-x',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Open is already true from non-empty query; land on the field then ×.
      searchKey.currentState!.openSearch();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'test-event-search-x-close',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'test-event-search-x-tool',
      );
      expect(query, '');
    },
  );
}
