import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/details/facts_panel.dart';

Widget _scope({required bool tv, required Widget child}) {
  return MaterialApp(
    home: Scaffold(
      body: ShellPaintScope(
        useTvFocus: tv,
        scaleOnHover: !tv,
        focusStyled: (_, {required focused}) => focused,
        usesTvDensity: tv,
        child: Align(
          alignment: Alignment.topRight,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  test('facts tokens follow tvChromeScale', () {
    expect(
      DetailsTokens.factsMaxWidthTv,
      closeTo(DetailsTokens.factsMaxWidth * ShellTokens.tvChromeScale, 0.001),
    );
    expect(
      DetailsTokens.factsPadHTv,
      closeTo(DetailsTokens.factsPadH * ShellTokens.tvChromeScale, 0.001),
    );
    expect(
      DetailsTokens.factsPadVEdgeTv,
      closeTo(DetailsTokens.factsPadVEdge * ShellTokens.tvChromeScale, 0.001),
    );
    expect(
      DetailsTokens.factsRadiusTv,
      closeTo(DetailsTokens.factsRadius * ShellTokens.tvChromeScale, 0.001),
    );
  });

  testWidgets('FactsPanel paints smaller under TV density', (tester) async {
    const rows = [
      (label: 'Name', value: 'Lanterns'),
      (label: 'Status', value: 'Returning Series'),
      (label: 'Network', value: 'HBO'),
    ];

    await tester.pumpWidget(
      _scope(
        tv: false,
        child: const SizedBox(
          width: DetailsTokens.factsMaxWidth,
          child: FactsPanel(rows: rows),
        ),
      ),
    );
    final desk = tester.getSize(find.byType(FactsPanel));

    await tester.pumpWidget(
      _scope(
        tv: true,
        child: const SizedBox(
          width: DetailsTokens.factsMaxWidthTv,
          child: FactsPanel(rows: rows),
        ),
      ),
    );
    final tv = tester.getSize(find.byType(FactsPanel));

    expect(tv.width, lessThan(desk.width));
    expect(tv.height, lessThan(desk.height));
    expect(tv.width, closeTo(DetailsTokens.factsMaxWidthTv, 0.5));
  });
}
