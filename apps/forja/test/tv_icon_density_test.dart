import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_metrics.dart';
import 'package:forja/shell/core/shell_paint_host.dart';
import 'package:forja_foundation/blocks/props_map.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

void main() {
  testWidgets('TV shell IconTheme densifies default Material icon size', (
    tester,
  ) async {
    late double? themeSize;
    await tester.pumpWidget(
      MaterialApp(
        home: shellPaintHostScope(
          inputPolicy: ShellInputPolicy.tv,
          metrics: ShellMetrics.tv,
          child: Builder(
            builder: (context) {
              themeSize = IconTheme.of(context).size;
              return const Icon(Icons.search_rounded);
            },
          ),
        ),
      ),
    );
    expect(themeSize, ShellTokens.iconSizeTv);
  });

  testWidgets('propsIconSizeOr scales desktop fallback on TV', (tester) async {
    late double sized;
    await tester.pumpWidget(
      MaterialApp(
        home: ShellPaintScope(
          useTvFocus: true,
          scaleOnHover: false,
          usesTvDensity: true,
          focusStyled: (_, {required focused}) => focused,
          child: Builder(
            builder: (context) {
              sized = propsIconSizeOr(context, const {}, 'iconSize', 20);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(sized, closeTo(20 * ShellTokens.tvChromeScale, 0.001));
  });
}
