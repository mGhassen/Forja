import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/tv/shell_tv_hold_accel.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/poster_card.dart';

Widget _wrapTv(Widget child) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1280, 720)),
      child: ShellScope(
        profile: ShellProfile.tv,
        config: shellPlatformConfigFor(ShellProfile.tv),
        // Loose constraints so the rail's own SizedBox width wins.
        child: FocusScope(
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    ),
  );
}

const double _pad = 24;
const double _cardW = 140;
const double _gap = 16;
const double _viewportW = 400;
const int _count = 10;

/// Hand-built rail: 10 cards, viewport fits ~2. [scrollCacheExtent] builds
/// every card so the test can focus far indices directly (the coordinator
/// only ever focuses mounted cards in the app).
Widget _plainRail(
  List<FocusNode> nodes,
  ScrollController scroll, {
  EdgeInsets? padding = const EdgeInsets.symmetric(horizontal: _pad),
}) {
  return SizedBox(
    width: _viewportW,
    height: 220,
    child: ListView.separated(
      controller: scroll,
      scrollDirection: Axis.horizontal,
      padding: padding,
      scrollCacheExtent: ScrollCacheExtent.pixels(4000),
      itemCount: _count,
      separatorBuilder: (_, _) => const SizedBox(width: _gap),
      itemBuilder: (_, i) => FocusableControl(
        key: ValueKey('card-$i'),
        focusNode: nodes[i],
        scaleOnFocus: 1.0,
        showFocusBorder: true,
        ensureVisibleMode: ShellPaintEnsureVisible.row,
        onTap: () {},
        child: const SizedBox(width: _cardW, height: 200),
      ),
    ),
  );
}

double _leftOf(WidgetTester tester, Finder f) =>
    tester.renderObject<RenderBox>(f).localToGlobal(Offset.zero).dx;

double _widthOf(WidgetTester tester, Finder f) =>
    tester.renderObject<RenderBox>(f).size.width;

Finder _card(int i) => find.byKey(ValueKey('card-$i'), skipOffstage: false);

Finder get _rail => find.byType(ListView);

/// Content-space x of card [i] (valid while the rail sits at offset 0).
double _contentX(WidgetTester tester, int i) =>
    _leftOf(tester, _card(i)) - _leftOf(tester, _rail);

void main() {
  tearDown(ShellTvHoldAccel.clearForTest);

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

      // Scroll past the first card so the focus column must bring it back.
      scroll.jumpTo(220);
      await tester.pump();
      expect(scroll.offset, greaterThan(100));

      second.requestFocus();
      await tester.pumpAndSettle();
      first.requestFocus();
      await tester.pumpAndSettle();

      expect(first.hasFocus, isTrue);

      final rankMark = find.text('1');
      expect(rankMark, findsOneWidget);
      final rankLeft = _leftOf(tester, rankMark);
      final viewportLeft = _leftOf(tester, _rail);
      // Rank digit must not sit left of the horizontal viewport (clipped).
      expect(rankLeft, greaterThanOrEqualTo(viewportLeft - 0.5));
      // First item: its column is the rail padding → back to the start.
      expect(scroll.offset, closeTo(0, 0.5));

      first.dispose();
      second.dispose();
      scroll.dispose();
    },
  );

  group('TV rail focus column', () {
    testWidgets(
      'focusing index 5 tweens so its left edge sits at the rail padding '
      'and the next card is visible',
      (tester) async {
        final nodes = List.generate(_count, (i) => FocusNode());
        final scroll = ScrollController();
        await tester.pumpWidget(_wrapTv(_plainRail(nodes, scroll)));
        await tester.pumpAndSettle();
        expect(_widthOf(tester, _rail), _viewportW);

        nodes[0].requestFocus();
        await tester.pumpAndSettle();
        expect(scroll.offset, closeTo(0, 0.5));

        final viewportLeft = _leftOf(tester, _rail);
        final x5 = _contentX(tester, 5);
        expect(x5, greaterThan(_viewportW)); // off-screen to the right
        final expected = x5 - _pad;

        nodes[5].requestFocus();
        // Focus applies in a microtask; the tween's first tick is the frame
        // after. Mid-tween the offset is strictly between start and target.
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        expect(scroll.offset, greaterThan(0));
        expect(scroll.offset, lessThan(expected - 1));

        await tester.pumpAndSettle();
        expect(scroll.offset, closeTo(expected, 0.5));
        expect(_leftOf(tester, _card(5)) - viewportLeft, closeTo(_pad, 0.5));
        // Next card (6) starts inside the viewport.
        expect(_leftOf(tester, _card(6)) - viewportLeft, lessThan(_viewportW));

        // Stepping back one card re-aligns to the column.
        nodes[4].requestFocus();
        await tester.pumpAndSettle();
        expect(_leftOf(tester, _card(4)) - viewportLeft, closeTo(_pad, 0.5));

        for (final n in nodes) {
          n.dispose();
        }
        scroll.dispose();
      },
    );

    testWidgets('last cards stay packed — no over-scroll past the end', (
      tester,
    ) async {
      final nodes = List.generate(_count, (i) => FocusNode());
      final scroll = ScrollController();
      await tester.pumpWidget(_wrapTv(_plainRail(nodes, scroll)));
      await tester.pumpAndSettle();

      final naturalColumnTarget = _contentX(tester, _count - 1) - _pad;
      final max = scroll.position.maxScrollExtent;
      expect(max, greaterThan(0));
      // The last card's natural column lies past the end of the rail.
      expect(naturalColumnTarget, greaterThan(max));

      nodes[_count - 1].requestFocus();
      await tester.pumpAndSettle();

      expect(scroll.offset, closeTo(max, 0.5));
      final viewportLeft = _leftOf(tester, _rail);
      final last = _card(_count - 1);
      final lastRight = _leftOf(tester, last) + _widthOf(tester, last);
      // Flush with the trailing padding instead of over-scrolling.
      expect(lastRight - viewportLeft, closeTo(_viewportW - _pad, 0.5));

      for (final n in nodes) {
        n.dispose();
      }
      scroll.dispose();
    });

    testWidgets('held key jumps instead of tweening', (tester) async {
      final nodes = List.generate(_count, (i) => FocusNode());
      final scroll = ScrollController();
      await tester.pumpWidget(_wrapTv(_plainRail(nodes, scroll)));
      await tester.pumpAndSettle();
      nodes[0].requestFocus();
      await tester.pumpAndSettle();
      final expected = _contentX(tester, 3) - _pad;

      // Simulate an in-progress → hold (down + repeat already noted).
      const right = LogicalKeyboardKey.arrowRight;
      ShellTvHoldAccel.note(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowRight,
          logicalKey: right,
          timeStamp: Duration.zero,
        ),
      );
      ShellTvHoldAccel.note(
        const KeyRepeatEvent(
          physicalKey: PhysicalKeyboardKey.arrowRight,
          logicalKey: right,
          timeStamp: Duration.zero,
        ),
      );
      expect(ShellTvHoldAccel.isHolding, isTrue);

      nodes[3].requestFocus();
      // Focus applies in the microtask flush; the jump is synchronous after.
      await tester.pump();
      expect(scroll.offset, closeTo(expected, 0.5));

      for (final n in nodes) {
        n.dispose();
      }
      scroll.dispose();
    });

    testWidgets('token fallback column when the rail declares no padding', (
      tester,
    ) async {
      final nodes = List.generate(_count, (i) => FocusNode());
      final scroll = ScrollController();
      await tester.pumpWidget(
        _wrapTv(_plainRail(nodes, scroll, padding: null)),
      );
      await tester.pumpAndSettle();
      final expected =
          _contentX(tester, 5) - ShellTokens.tvKitRowFocusColumnInset;
      expect(expected, lessThan(scroll.position.maxScrollExtent));

      nodes[5].requestFocus();
      await tester.pumpAndSettle();
      expect(scroll.offset, closeTo(expected, 0.5));

      for (final n in nodes) {
        n.dispose();
      }
      scroll.dispose();
    });
  });
}
