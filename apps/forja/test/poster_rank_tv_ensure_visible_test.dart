import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja_foundation/widgets/catalog/poster_card.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

Widget _wrapTv(Widget child) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1280, 720)),
      child: ShellScope(
        profile: ShellProfile.tv,
        config: shellPlatformConfigFor(ShellProfile.tv),
        child: FocusScope(child: child),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'focusing first ranked poster scrolls so the rank digit stays on-screen',
    (tester) async {
      final first = FocusNode(debugLabel: 'ranked-0');
      final second = FocusNode(debugLabel: 'ranked-1');
      final scroll = ScrollController();

      await tester.pumpWidget(
        _wrapTv(
          SizedBox(
            width: 400,
            height: 220,
            child: ListView(
              controller: scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                PosterRankRow(
                  rank: 1,
                  child: FocusableControl(
                    focusNode: first,
                    scaleOnFocus: 1.0,
                    showFocusBorder: true,
                    ensureVisibleMode: ShellPaintEnsureVisible.row,
                    onTap: () {},
                    child: const SizedBox(width: 140, height: 200),
                  ),
                ),
                const SizedBox(width: 16),
                PosterRankRow(
                  rank: 2,
                  child: FocusableControl(
                    focusNode: second,
                    scaleOnFocus: 1.0,
                    showFocusBorder: true,
                    ensureVisibleMode: ShellPaintEnsureVisible.row,
                    onTap: () {},
                    child: const SizedBox(width: 140, height: 200),
                  ),
                ),
                const SizedBox(width: 16),
                const SizedBox(width: 400, height: 200),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll past the first card so ensureVisible must bring it back.
      scroll.jumpTo(220);
      await tester.pump();
      expect(scroll.offset, greaterThan(100));

      second.requestFocus();
      await tester.pump();
      first.requestFocus();
      await tester.pump();

      expect(first.hasFocus, isTrue);

      final rankMark = find.text('1');
      expect(rankMark, findsOneWidget);
      final rankBox = tester.renderObject<RenderBox>(rankMark);
      final listBox = tester.renderObject<RenderBox>(find.byType(ListView));
      final rankLeft = rankBox.localToGlobal(Offset.zero).dx;
      final viewportLeft = listBox.localToGlobal(Offset.zero).dx;
      // Rank digit must not sit left of the horizontal viewport (clipped).
      expect(rankLeft, greaterThanOrEqualTo(viewportLeft - 0.5));
      expect(scroll.offset, lessThan(40));

      first.dispose();
      second.dispose();
      scroll.dispose();
    },
  );
}
