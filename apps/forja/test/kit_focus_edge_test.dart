import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/shell/focus_edge.dart';

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
  });
}
