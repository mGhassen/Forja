import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/chrome/status_tabs.dart';
import 'package:forja_foundation/widgets/chrome/top_bar_actions.dart';
import 'package:forja_foundation/widgets/feedback/bottom_sheet_panel.dart';

const _phone = Size(411, 914);

Future<void> _surface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

const _tabs = [
  (id: 'a', title: 'Plan to Watch'),
  (id: 'b', title: 'Watching'),
  (id: 'c', title: 'On Hold'),
  (id: 'd', title: 'Completed'),
  (id: 'e', title: 'Dropped'),
];

Widget _statusTabs({
  required bool scrollable,
  ValueChanged<String>? onSelect,
}) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: ForjaStatusTabs(
        tabId: 'page',
        tabs: _tabs,
        selected: 'a',
        onSelect: onSelect ?? (_) {},
        scrollable: scrollable,
      ),
    ),
  ),
);

void main() {
  group('TopBarActions centerBelow', () {
    Widget bar({required bool below}) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 411,
            child: TopBarActions(
              padding: EdgeInsets.zero,
              leading: const [
                SizedBox(key: ValueKey('sports'), width: 120, height: 32),
              ],
              trailing: const [
                SizedBox(key: ValueKey('search'), width: 48, height: 32),
              ],
              centerBelow: below,
              center: const SizedBox(
                key: ValueKey('progress'),
                width: 300,
                height: 12,
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('paints progress under the strip, never over actions', (
      tester,
    ) async {
      await _surface(tester, _phone);
      await tester.pumpWidget(bar(below: true));
      expect(tester.takeException(), isNull);

      final progress = tester.getRect(find.byKey(const ValueKey('progress')));
      for (final id in ['sports', 'search']) {
        final action = tester.getRect(find.byKey(ValueKey(id)));
        expect(progress.overlaps(action), isFalse, reason: id);
        expect(progress.top, greaterThanOrEqualTo(action.bottom));
      }
    });

    testWidgets('default keeps the centered overlay', (tester) async {
      await _surface(tester, _phone);
      await tester.pumpWidget(bar(below: false));
      final progress = tester.getRect(find.byKey(const ValueKey('progress')));
      final sports = tester.getRect(find.byKey(const ValueKey('sports')));
      expect(progress.overlaps(sports), isTrue);
    });
  });

  group('ForjaStatusTabs scrollable', () {
    testWidgets('phone strip keeps full labels', (tester) async {
      await _surface(tester, _phone);
      String? picked;
      await tester.pumpWidget(
        _statusTabs(scrollable: true, onSelect: (id) => picked = id),
      );
      expect(tester.takeException(), isNull);

      final para = tester.renderObject<RenderParagraph>(
        find.text('Plan to Watch'),
      );
      expect(para.didExceedMaxLines, isFalse);
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // Strip scrolls sideways to reach the last tab.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      final dropped = tester.getRect(find.text('Dropped'));
      expect(dropped.right, lessThanOrEqualTo(_phone.width));
      await tester.tap(find.text('Dropped'));
      await tester.pump();
      expect(picked, 'e');
    });

    testWidgets('default stays an equal-width row', (tester) async {
      await _surface(tester, _phone);
      await tester.pumpWidget(_statusTabs(scrollable: false));
      expect(find.byType(SingleChildScrollView), findsNothing);
      final a = tester.getSize(find.text('Plan to Watch').first);
      expect(a.width, lessThanOrEqualTo(411 / 5));
    });
  });

  group('ForjaBottomSheetPanel', () {
    Widget sheet({required VoidCallback onClose}) => MaterialApp(
      home: Scaffold(
        body: ForjaBottomSheetPanel(
          title: 'Sources',
          enableBlur: false,
          onClose: onClose,
          child: const SizedBox(key: ValueKey('body')),
        ),
      ),
    );

    testWidgets('shows handle, title and close; close button closes', (
      tester,
    ) async {
      await _surface(tester, _phone);
      var closed = 0;
      await tester.pumpWidget(sheet(onClose: () => closed++));
      await tester.pumpAndSettle();

      expect(find.byType(ForjaSheetHandle), findsOneWidget);
      expect(find.text('Sources'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      final body = tester.getRect(find.byKey(const ValueKey('body')));
      expect(body.bottom, lessThanOrEqualTo(_phone.height));
      expect(body.top, greaterThan(0));

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(closed, 1);
    });

    testWidgets('dragging the handle down closes the sheet', (tester) async {
      await _surface(tester, _phone);
      var closed = 0;
      await tester.pumpWidget(sheet(onClose: () => closed++));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ForjaSheetHandle), const Offset(0, 800));
      await tester.pumpAndSettle();
      expect(closed, 1);
    });

    testWidgets('a short drag snaps back open', (tester) async {
      await _surface(tester, _phone);
      var closed = 0;
      await tester.pumpWidget(sheet(onClose: () => closed++));
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byKey(const ValueKey('body')));

      await tester.timedDrag(
        find.byType(ForjaSheetHandle),
        const Offset(0, 40),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();
      expect(closed, 0);
      expect(tester.getRect(find.byKey(const ValueKey('body'))), before);
    });

    testWidgets('marks its subtree for nested overlays', (tester) async {
      await _surface(tester, _phone);
      late bool inside;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForjaBottomSheetPanel(
              enableBlur: false,
              onClose: () {},
              child: Builder(
                builder: (context) {
                  inside = ForjaBottomSheetScope.isInside(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      expect(inside, isTrue);
    });
  });
}
