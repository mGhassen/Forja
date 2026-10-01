import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/portal_list_tokens.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_row.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

Widget _wrap({required Widget child}) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1920, 1080)),
      child: ShellPaintScope(
        useTvFocus: true,
        scaleOnHover: false,
        usesTvDensity: true,
        focusStyled: (context, {required focused}) => focused,
        child: Scaffold(
          body: SizedBox(
            width: 280,
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'PortalListRow TV densifies meta icons/badges inside rowHeightTv',
    (tester) async {
      FlutterErrorDetails? overflow;
      final prior = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) {
          overflow = details;
        }
        prior?.call(details);
      };
      addTearDown(() => FlutterError.onError = prior);

      await tester.pumpWidget(
        _wrap(
          child: PortalListRow(
            leanback: true,
            height: PortalListTokens.rowHeightTv,
            item: const PortalListItem(
              id: '1',
              label: 'MAGNMAC9E9',
              subtitle: 'http://example.portal/get.php',
              selected: true,
              isNew: true,
              platformLabel: 'Xtream',
              expiry: '2026-12-31',
              activeConnections: '2',
              maxConnections: '5',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(overflow, isNull, reason: 'TV portal row must not RenderFlex-overflow');

      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(
        icons.any((i) => i.size == PortalListTokens.metaIconSizeTv),
        isTrue,
      );

      final newBadge = tester.widget<Text>(find.text('NEW'));
      expect(newBadge.style?.fontSize, PortalListTokens.badgeFontSizeTv);
    },
  );
}
