import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/details/list_status_pin.dart';

/// Minimal host-like tap: Focus owns Select → onTap (same contract as
/// app [FocusableControl]).
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
  testWidgets('TV status menu Select activates Plan to Watch', (tester) async {
    String? selected;
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
              child: ListStatusPopupPanel(
                currentStatus: null,
                tvFocus: true,
                autoFocusSelected: true,
                onSelect: (id) => selected = id,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plan to Watch'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(selected, 'plantowatch');
  });

  testWidgets('TV status menu Select toggles off current status', (tester) async {
    String? selected = 'watching';
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
              child: ListStatusPopupPanel(
                currentStatus: 'watching',
                tvFocus: true,
                autoFocusSelected: true,
                onSelect: (id) => selected = id,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(selected, '');
  });
}
