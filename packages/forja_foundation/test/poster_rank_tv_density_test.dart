import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/poster_card.dart';
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
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

void main() {
  test('poster rank TV tokens follow film layout scale', () {
    expect(
      ShellTokens.posterRankFontSizeTv,
      closeTo(
        ShellTokens.posterRankFontSize * ShellTokens.tvLayoutScale,
        0.001,
      ),
    );
    expect(
      ShellTokens.posterRankStrokeWidthTv,
      closeTo(
        ShellTokens.posterRankStrokeWidth * ShellTokens.tvLayoutScale,
        0.001,
      ),
    );
    expect(
      ShellTokens.posterRankLetterSpacingTv,
      closeTo(
        ShellTokens.posterRankLetterSpacing * ShellTokens.tvLayoutScale,
        0.001,
      ),
    );
  });

  testWidgets('PosterRankMark uses leanback size under usesTvDensity',
      (tester) async {
    await tester.pumpWidget(
      _wrap(tv: true, child: const PosterRankMark(rank: 1)),
    );

    final text = tester.widget<Text>(find.text('1'));
    expect(text.style?.fontSize, ShellTokens.posterRankFontSizeTv);
  });

  testWidgets('PosterRankMark keeps desktop size without TV density',
      (tester) async {
    await tester.pumpWidget(
      _wrap(tv: false, child: const PosterRankMark(rank: 2)),
    );

    final text = tester.widget<Text>(find.text('2'));
    expect(text.style?.fontSize, ShellTokens.posterRankFontSize);
  });
}
