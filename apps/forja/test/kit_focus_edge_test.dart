import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/focus/focus_edge.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';

void main() {
  group('kitFocusEdge', () {
    test('skips missing row ids', () {
      expect(kitFocusEdge('tab', null), isNull);
      expect(kitFocusEdge('tab', ''), isNull);
      expect(kitFocusEdge('tab', '  '), isNull);
      expect(kitFocusSide('tab', null), isNull);
      expect(kitFocusSide('tab', ''), isNull);
    });

    test('returns a jump for a named row', () {
      expect(kitFocusEdge('tab', 'grid'), isNotNull);
      expect(kitFocusEdge('tab', 'status', last: true), isNotNull);
      expect(kitFocusSide('tab', 'sources-kind'), isNotNull);
    });

    test('marks miss when target row is unregistered', () {
      ShellTvFocusCoordinator.beginKitEdgeAttempt();
      kitFocusEdge('orphan-tab', 'sources-kind', last: true)!.call();
      expect(ShellTvFocusCoordinator.takeKitEdgeMiss(), isTrue);
    });

    testWidgets('RIGHT does not swallow when kit edge misses', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Focus(
            focusNode: node,
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      );
      node.requestFocus();
      await tester.pump();

      final edge = kitFocusEdge('missing-tab', 'sources-kind', last: true)!;
      final result = shellTvHandleRowArrows(
        event: const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowRight,
          logicalKey: LogicalKeyboardKey.arrowRight,
          timeStamp: Duration.zero,
        ),
        onRightEdge: edge,
      );
      // Unregistered row → ignored so spatial / parent can handle.
      expect(result, KeyEventResult.ignored);
    });
  });
}
