import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/portal_list_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_view.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

Widget _wrap({required bool tv, required Widget child}) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1920, 1080)),
      child: ShellPaintScope(
        useTvFocus: tv,
        scaleOnHover: !tv,
        usesTvDensity: tv,
        focusStyled: (context, {required focused}) => focused,
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  testWidgets('PortalListView header icons use TV size under usesTvDensity', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        tv: true,
        child: PortalListView(
          width: PortalListTokens.resolvePanelWidth(
            true,
            ShellTokens.sidePanelWidth,
          ),
          title: 'Portals',
          items: const [
            PortalListItem(id: '1', label: 'MAGNMAC9E9', selected: true),
          ],
          headerActions: const [
            PortalListHeaderAction(id: 'add', label: 'Add', icon: 'add'),
          ],
        ),
      ),
    );

    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(icons, isNotEmpty);
    expect(
      icons.any((i) => i.size == PortalListTokens.headerIconSizeTv),
      isTrue,
    );

    final title = tester.widget<Text>(find.textContaining('Portals').first);
    expect(title.style?.fontSize, ShellTokens.tvTitleFontSize);
  });
}
