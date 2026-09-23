import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/controls/chrome/player_status_roulette.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

Widget _wrap({required bool tv, required Widget child}) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.black,
      body: ShellPaintScope(
        useTvFocus: tv,
        scaleOnHover: !tv,
        focusStyled: (_, {required focused}) => focused,
        usesTvDensity: tv,
        child: Center(child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('status roulette shows header, active source, and progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        tv: false,
        child: const StatusRouletteView(
          header: 'Checking sources',
          entries: [
            StatusRouletteEntry(
              id: 'source-0',
              label: 'Megaplay',
              kind: StatusRouletteKind.loading,
            ),
            StatusRouletteEntry(
              id: 'source-1',
              label: 'VidLink',
              kind: StatusRouletteKind.loading,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Checking sources'), findsOneWidget);
    expect(find.text('Megaplay'), findsOneWidget);
    expect(find.text('0 / 2'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('status roulette TV density keeps leanback type', (tester) async {
    await tester.pumpWidget(
      _wrap(
        tv: true,
        child: const StatusRouletteView(
          header: 'Checking sources',
          entries: [
            StatusRouletteEntry(
              id: 'source-0',
              label: 'Megaplay',
              kind: StatusRouletteKind.loading,
            ),
          ],
        ),
      ),
    );

    final label = tester.widget<Text>(find.text('Megaplay'));
    expect(label.style?.fontSize, ShellTokens.playerStatusLabelFontSizeTv);
    expect(find.text('0 / 1'), findsOneWidget);
  });
}
