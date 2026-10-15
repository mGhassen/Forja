import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/blocks/catalog/catalog_cards_grid.dart';
import 'package:forja_foundation/tokens/event_card_tokens.dart';
import 'package:forja_foundation/widgets/catalog/event_card.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

ShellPaintFocusableTap _desktopTap(FocusNode node) {
  return ({
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
    bool showFocusFill = false,
    bool showFocusRail = false,
    bool suppressInkHover = false,
    bool allowNestedFocus = false,
    FocusOnKeyEventCallback? onKeyEvent,
    bool mouseDownActivates = true,
  }) {
    return Focus(
      focusNode: focusNode ?? node,
      autofocus: autoFocus,
      onFocusChange: onFocusChange,
      child: MouseRegion(
        onEnter: (_) {
          onHoverChange?.call(true);
          // Desktop hover claims focus; leaving hover does not unfocus.
          (focusNode ?? node).requestFocus();
        },
        onExit: (_) => onHoverChange?.call(false),
        child: child,
      ),
    );
  };
}

/// Desktop hybrid: hover arms catalogs; mouse focus retention does not.
Widget _wrapDesktop(Widget child, {required FocusNode focusNode}) {
  return MaterialApp(
    home: Scaffold(
      body: ShellPaintScope(
        useTvFocus: true,
        scaleOnHover: true,
        // Mouse-claimed focus does not paint focus chrome (keyboard does).
        focusStyled: (_, {required focused}) => false,
        usesTvDensity: false,
        focusableTapBuilder: _desktopTap(focusNode),
        child: Center(child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('merged catalogs replace the inside of the event card', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EventCard(
          title: 'Finland vs Belarus',
          width: 280,
          height: 160,
          homeTeam: 'Finland',
          awayTeam: 'Belarus',
          live: true,
          categoryLabel: 'Football',
          viewers: 468,
          showCatalogs: true,
          catalogs: [
            'Streamed',
            'PPV',
            'Live Soccer TV',
            'LiveOnSat',
            'StreamFree',
            'Streamic',
            'WatchFooty',
          ],
        ),
      ),
    );

    expect(find.text('Finland vs Belarus'), findsNothing);
    expect(find.text('FOOTBALL'), findsNothing);
    expect(find.text('● LIVE'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(EventCard),
        matching: find.byType(ListView),
      ),
      findsOneWidget,
    );
    expect(find.text('PPV'), findsOneWidget);
    expect(find.text('WatchFooty'), findsOneWidget);
  });

  testWidgets('event card keeps the match face until catalogs are shown', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EventCard(
          title: 'Finland vs Belarus',
          width: 280,
          height: 160,
          catalogs: ['PPV', 'StreamFree'],
        ),
      ),
    );

    expect(find.text('Finland vs Belarus'), findsOneWidget);
    expect(find.text('PPV'), findsNothing);
  });

  testWidgets(
    'desktop: leaving hover restores match face even if focus sticks',
    (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _wrapDesktop(
          const InteractiveEventCard(
            props: {
              'title': 'Finland vs Belarus',
              'homeTeam': 'Finland',
              'awayTeam': 'Belarus',
              'live': true,
              'categoryLabel': 'Football',
              'catalogs': ['PPV', 'LiveOnSat'],
            },
            width: 280,
            height: 160,
          ),
          focusNode: focusNode,
        ),
      );

      final card = find.byType(InteractiveEventCard);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(card));
      await tester.pump();

      await tester.pump(EventCardTokens.catalogHoverDelay);
      await tester.pump();
      expect(find.text('PPV'), findsOneWidget);
      expect(find.text('Finland vs Belarus'), findsNothing);
      expect(focusNode.hasFocus, isTrue);

      await gesture.moveTo(const Offset(0, 0));
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);
      expect(find.text('Finland vs Belarus'), findsOneWidget);
      expect(find.text('PPV'), findsNothing);
    },
  );
}
