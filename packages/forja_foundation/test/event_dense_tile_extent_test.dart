import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/event_dense_tile.dart';
import 'package:forja_foundation/widgets/chrome/catalog_dense_list.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

Widget _wrap({required bool tv, required Widget child}) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1280, 800)),
      child: ShellPaintScope(
        useTvFocus: tv,
        scaleOnHover: false,
        usesTvDensity: tv,
        focusStyled: (context, {required focused}) => focused,
        child: Scaffold(
          body: SizedBox(width: 480, height: 400, child: child),
        ),
      ),
    ),
  );
}

void main() {
  test('denseListRowExtent covers EventDenseTile pad + text stack', () {
    const desktop = ShellTokens.eventDensePadV * 2 +
        ShellTokens.eventDenseFontSize * ShellTokens.eventDenseLineHeight +
        ShellTokens.eventDenseMetaGap +
        ShellTokens.eventDenseMetaFontSize * ShellTokens.eventDenseLineHeight +
        2;
    const tv = ShellTokens.eventDensePadVTv * 2 +
        ShellTokens.eventDenseFontSizeTv * ShellTokens.eventDenseLineHeight +
        ShellTokens.eventDenseMetaGapTv +
        ShellTokens.eventDenseMetaFontSizeTv * ShellTokens.eventDenseLineHeight +
        2;

    expect(ShellTokens.denseListRowExtent, desktop);
    expect(ShellTokens.denseListRowExtentTv, tv);
    // Leanback type ladder is not chrome-scaled — extent must not be desktop×scale.
    expect(
      ShellTokens.denseListRowExtentTv,
      isNot(ShellTokens.denseListRowExtent * ShellTokens.tvChromeScale),
    );
  });

  testWidgets('EventDenseTile fits denseListRowExtent without overflow',
      (tester) async {
    for (final tv in [false, true]) {
      FlutterErrorDetails? overflow;
      final prior = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) {
          overflow = details;
        }
        prior?.call(details);
      };
      addTearDown(() => FlutterError.onError = prior);

      final extent = ShellTokens.denseListRowExtentOf(tv);
      await tester.pumpWidget(
        _wrap(
          tv: tv,
          child: CatalogDenseList(
            itemCount: 3,
            itemBuilder: (context, i) => EventDenseTile(
              title: 'New York Giants at Los Angeles Rams $i',
              meta: 'american-football · Live',
              airing: true,
              viewers: 9493,
              selected: i == 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        overflow,
        isNull,
        reason: 'tv=$tv extent=$extent must fit EventDenseTile',
      );
    }
  });
}
