import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/components/badge.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

Widget _wrap({required bool tv, required Widget child}) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(
      extensions: [ForjaThemeExtension.dark()],
    ),
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1920, 1080)),
      child: ShellPaintScope(
        useTvFocus: tv,
        scaleOnHover: !tv,
        usesTvDensity: tv,
        focusStyled: (context, {required focused}) => focused,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

void main() {
  testWidgets('Badge uses leanback type under usesTvDensity', (tester) async {
    await tester.pumpWidget(
      _wrap(tv: true, child: const Badge(label: 'NOW')),
    );

    final style = tester.widget<DefaultTextStyle>(
      find.descendant(
        of: find.byType(Badge),
        matching: find.byType(DefaultTextStyle),
      ).first,
    );
    expect(style.style.fontSize, ShellTokens.tvMetaFontSize);
  });
}
