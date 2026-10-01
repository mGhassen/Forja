import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/kit/paint_artifact.dart';
import 'package:forja_foundation/blocks/props_map.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

Widget _scope({required bool tv, required Widget child}) {
  return ShellPaintScope(
    useTvFocus: tv,
    scaleOnHover: !tv,
    focusStyled: (_, {required focused}) => focused,
    usesTvDensity: tv,
    child: child,
  );
}

void main() {
  testWidgets('packLength scales desktop px on TV density', (tester) async {
    late double? tvLen;
    late double? deskLen;
    await tester.pumpWidget(
      MaterialApp(
        home: _scope(
          tv: true,
          child: Builder(
            builder: (context) {
              tvLen = PackPaintArtifact.packLength(context, 140);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: _scope(
          tv: false,
          child: Builder(
            builder: (context) {
              deskLen = PackPaintArtifact.packLength(context, 140);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(deskLen, 140);
    expect(tvLen, closeTo(140 * ShellTokens.tvChromeScale, 0.001));
  });

  testWidgets('propsLength matches packLength contract', (tester) async {
    late double? scaled;
    await tester.pumpWidget(
      MaterialApp(
        home: _scope(
          tv: true,
          child: Builder(
            builder: (context) {
              scaled = propsLength(context, {'cardWidth': 140}, 'cardWidth');
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(scaled, closeTo(140 * ShellTokens.tvChromeScale, 0.001));
  });
}