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

  testWidgets('PortalListView search field uses top-bar pill chrome on TV', (
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
          searchPlaceholder: 'Search portals…',
          items: const [
            PortalListItem(id: '1', label: 'MAGNMAC9E9', selected: true),
          ],
        ),
      ),
    );

    await tester.tap(find.byTooltip('Search portals'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    final decoration = field.decoration!;
    expect(decoration.border, InputBorder.none);
    expect(decoration.focusedBorder, InputBorder.none);
    expect(decoration.prefixIcon, isNull);
    final pad = decoration.contentPadding!.resolve(TextDirection.ltr);
    expect(pad.vertical, PortalListTokens.searchFieldPadVTv * 2);

    final pill = tester.widget<Container>(
      find
          .ancestor(
            of: find.byType(TextField),
            matching: find.byType(Container),
          )
          .first,
    );
    final box = pill.decoration! as BoxDecoration;
    expect(pill.constraints?.maxHeight, PortalListTokens.searchFieldHeightTv);
    expect(
      (box.border as Border).top.color,
      Colors.white.withValues(alpha: 0.18),
    );
    expect(
      box.borderRadius,
      BorderRadius.circular(PortalListTokens.searchFieldHeightTv / 2),
    );

    final prefixIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(Row),
        matching: find.byIcon(Icons.search_rounded),
      ),
    );
    expect(prefixIcon.size, PortalListTokens.searchPrefixIconSizeTv);
  });
}
