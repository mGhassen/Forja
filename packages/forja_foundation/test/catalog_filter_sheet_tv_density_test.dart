import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/catalog_filter_sheet.dart';
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
  testWidgets('CatalogFilterSheet uses TV type ladder under usesTvDensity', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        tv: true,
        child: CatalogFilterSheet(
          current: 'all',
          options: const [
            (id: 'all', label: 'All', subtitle: null),
            (id: 'espn', label: 'ESPN', subtitle: null),
          ],
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Catalog'));
    expect(title.style?.fontSize, ShellTokens.filterSheetTitleFontSizeTv);
    expect(title.style?.fontSize, ShellTokens.tvTitleFontSize);

    final option = tester.widget<Text>(find.text('All'));
    expect(option.style?.fontSize, ShellTokens.filterSheetOptionFontSizeTv);
    expect(option.style?.fontSize, ShellTokens.tvBodyFontSize);
  });

  testWidgets('CatalogFilterSheet keeps desktop title size off TV', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        tv: false,
        child: CatalogFilterSheet(
          current: 'all',
          options: const [
            (id: 'all', label: 'All', subtitle: null),
          ],
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Catalog'));
    expect(title.style?.fontSize, ShellTokens.filterSheetTitleFontSize);
  });

  testWidgets(
    'CatalogFilterSheet shrink-wraps under TV max height (no empty panel)',
    (tester) async {
      const screen = Size(1920, 1080);
      final maxHeight =
          screen.height * ShellTokens.filterSheetMaxHeightFractionTv;

      await tester.pumpWidget(
        _wrap(
          tv: true,
          child: CatalogFilterSheet(
            current: 'all',
            options: const [
              (id: 'all', label: 'All', subtitle: null),
              (id: 'espn', label: 'ESPN', subtitle: null),
            ],
          ),
        ),
      );

      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.shrinkWrap, isTrue);

      final box = tester.renderObject<RenderBox>(find.byType(ListView));
      expect(box.size.height, lessThan(maxHeight));
      expect(box.size.height, greaterThan(0));
    },
  );
}
