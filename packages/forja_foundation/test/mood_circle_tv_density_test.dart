import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/components/mood_circle.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/shell_mood_circle.dart';
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
  test('TV mood circle tokens are denser than desktop', () {
    expect(ShellTokens.moodCircleSizeTv, lessThan(MoodCircleLayout.desktop.circleSize));
    expect(ShellTokens.moodCircleSizeTv, 34);
    expect(ShellTokens.moodCircleIconSizeTv, lessThan(MoodCircleLayout.desktop.iconSize));
    expect(
      MoodCircleLayout.tvScrollable.circleSize,
      ShellTokens.moodCircleSizeTv,
    );
  });

  testWidgets('ShellMoodCircleItem forces TV layout under usesTvDensity', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        tv: true,
        child: ShellMoodCircleItem(
          // Stale desktop prop — density must win.
          layout: MoodCircleLayout.desktop,
          label: 'Soccer',
          icon: Icons.sports_soccer,
          accent: const Color(0xFF22C55E),
          selected: false,
          onTap: () {},
        ),
      ),
    );

    final icons = tester.widgetList<Icon>(find.byType(Icon));
    expect(
      icons.any((i) => i.size == ShellTokens.moodCircleIconSizeTv),
      isTrue,
      reason: 'icon should use TV size, not desktop 26',
    );
    // Outer chip slot is itemWidth × rowHeight.
    expect(
      tester.getSize(find.byType(ShellMoodCircleItem)).width,
      ShellTokens.moodCircleItemWidthTv,
    );
  });

  testWidgets('ShellMoodCircleLayout.resolve picks tvScrollable on TV', (
    tester,
  ) async {
    late MoodCircleLayout layout;
    await tester.pumpWidget(
      _wrap(
        tv: true,
        child: Builder(
          builder: (context) {
            layout = ShellMoodCircleLayout.resolve(
              context,
              itemCount: 8,
              maxWidth: 900,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(layout.circleSize, ShellTokens.moodCircleSizeTv);
  });
}
