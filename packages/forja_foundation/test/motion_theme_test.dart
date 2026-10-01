import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

void main() {
  Widget harness({
    required bool scaleOnHover,
    required Widget child,
    ForjaMotionTheme? theme,
  }) {
    Widget tree = ShellPaintScope(
      useTvFocus: !scaleOnHover,
      scaleOnHover: scaleOnHover,
      focusStyled: (_, {required focused}) => focused,
      usesTvDensity: !scaleOnHover,
      child: child,
    );
    if (theme != null) {
      tree = ForjaMotionScope(theme: theme, child: tree);
    }
    return MaterialApp(home: Scaffold(body: tree));
  }

  testWidgets('defaults cardLift scale', (tester) async {
    late double scale;
    await tester.pumpWidget(
      harness(
        scaleOnHover: true,
        child: Builder(
          builder: (context) {
            scale = ForjaMotionTheme.of(context).scaleForActive(
              context,
              ForjaMotionPreset.cardLift,
              true,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(scale, ForjaMotionTheme.defaults.cardLift.hoverScale);
  });

  testWidgets('leanback uses focusScale when active', (tester) async {
    late double scale;
    await tester.pumpWidget(
      harness(
        scaleOnHover: false,
        child: Builder(
          builder: (context) {
            scale = ForjaMotionTheme.of(context).scaleForActive(
              context,
              ForjaMotionPreset.cardLift,
              true,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(scale, ForjaMotionTheme.defaults.cardLift.focusScale);
  });

  testWidgets('inactive is 1.0', (tester) async {
    late double scale;
    await tester.pumpWidget(
      harness(
        scaleOnHover: true,
        child: Builder(
          builder: (context) {
            scale = ForjaMotionTheme.of(context).scaleForActive(
              context,
              ForjaMotionPreset.cardLift,
              false,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(scale, 1.0);
  });

  test('merge overlay changes cardLift', () {
    final merged = ForjaMotionTheme.defaults.merge({
      'cardLift': {'hoverScale': 1.2, 'durationMs': 300},
      'unknownPreset': {'hoverScale': 9.0},
    });
    expect(merged.cardLift.hoverScale, 1.2);
    expect(merged.cardLift.durationMs, 300);
    expect(merged.chipLift.hoverScale, ForjaMotionTheme.defaults.chipLift.hoverScale);
  });

  test('presetFromName parses aliases', () {
    expect(ForjaMotionTheme.presetFromName('card_lift'), ForjaMotionPreset.cardLift);
    expect(ForjaMotionTheme.presetFromName('fillOnly'), ForjaMotionPreset.fillOnly);
    expect(ForjaMotionTheme.presetFromName('nope'), isNull);
  });

  testWidgets('node props override wins', (tester) async {
    late double scale;
    await tester.pumpWidget(
      harness(
        scaleOnHover: true,
        theme: ForjaMotionTheme.defaults.merge({
          'cardLift': {'hoverScale': 1.2},
        }),
        child: Builder(
          builder: (context) {
            final themed = ForjaMotionTheme.of(context).mergeNodeProps({
              'motion': 'cardLift',
              'hoverScale': 1.5,
            });
            scale = themed.cardLift.hoverScale;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(scale, 1.5);
  });

  test('railIcon duration matches shell rail animation', () {
    expect(
      ForjaMotionTheme.defaults.railIcon.durationMs,
      ShellTokens.navRailIconScaleAnimation.inMilliseconds,
    );
  });
}
