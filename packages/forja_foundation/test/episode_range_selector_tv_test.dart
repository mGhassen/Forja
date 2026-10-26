import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/details/episode_range_bar.dart';

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
  testWidgets('TV OK opens episode range dialog and Select picks a chunk', (
    tester,
  ) async {
    var selected = 0;
    final ranges = [
      const EpisodeRange(index: 0, labelStart: 1, labelEnd: 50),
      const EpisodeRange(index: 1, labelStart: 51, labelEnd: 100),
      const EpisodeRange(index: 2, labelStart: 101, labelEnd: 120),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ShellPaintScope(
          useTvFocus: true,
          scaleOnHover: false,
          usesTvDensity: true,
          focusStyled: (_, {required focused}) => focused,
          focusableTapBuilder: _tvTap,
          isActivateKey: (event) =>
              event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter),
          child: Scaffold(
            body: Center(
              child: EpisodeRangeSelector(
                ranges: ranges,
                selectedIndex: selected,
                useFocusableChips: true,
                onSelected: (i) => selected = i,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 - 50'), findsOneWidget);
    expect(find.text('Episode range'), findsNothing);

    await tester.tap(find.text('1 - 50'));
    await tester.pumpAndSettle();

    expect(find.text('Episode range'), findsOneWidget);
    expect(find.text('51 - 100'), findsWidgets);

    // Selected chunk autofocuses; ↓ then Select picks the next range.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(selected, 1);
    expect(find.text('Episode range'), findsNothing);
  });
}
