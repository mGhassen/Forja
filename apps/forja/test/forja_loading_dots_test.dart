import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/feedback/loading_dots.dart';

void main() {
  testWidgets('ForjaLoadingDots paints cycling dots', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ForjaLoadingDots(color: Colors.white),
        ),
      ),
    );
    expect(find.byType(ForjaLoadingDots), findsOneWidget);
  });

  testWidgets('ForjaBusyCancelGlyph height matches size', (tester) async {
    const size = 9.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForjaBusyCancelGlyph(
            color: Colors.white,
            size: size,
            hovered: false,
            onHover: (_) {},
          ),
        ),
      ),
    );
    final box = tester.getSize(find.byType(ForjaBusyCancelGlyph));
    expect(box.height, size);
    expect(box.width, size + 2);
  });

  testWidgets('ForjaShellChip loading does not grow height', (tester) async {
    Widget wrap(Widget child) => MaterialApp(
          home: ShellPaintScope(
            useTvFocus: true,
            scaleOnHover: false,
            usesTvDensity: true,
            focusStyled: (_, {required focused}) => focused,
            child: Scaffold(body: Center(child: child)),
          ),
        );

    await tester.pumpWidget(
      wrap(
        const ForjaShellChip(
          label: 'Videasy',
          accentHover: true,
        ),
      ),
    );
    final idle = tester.getSize(find.byType(ForjaShellChip));

    await tester.pumpWidget(
      wrap(
        const ForjaShellChip(
          label: 'Videasy',
          accentHover: true,
          loading: true,
        ),
      ),
    );
    final loading = tester.getSize(find.byType(ForjaShellChip));

    expect(loading.height, idle.height);
  });
}
