import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/widgets/list_letter_jump_scope.dart';

void main() {
  group('ListLetterJumpMatcher', () {
    final labels = ['France', 'Finland', 'USA', 'Uruguay'];

    int? jump(String letter, ListLetterJumpMatcher matcher) {
      return matcher.nextIndex(
        letter: letter,
        itemCount: labels.length,
        labelAt: (i) => labels[i],
      );
    }

    test('first letter match', () {
      final m = ListLetterJumpMatcher();
      expect(jump('f', m), 0);
    });

    test('repeat letter cycles matches', () {
      final m = ListLetterJumpMatcher();
      expect(jump('f', m), 0);
      expect(jump('f', m), 1);
      expect(jump('f', m), 0);
    });

    test('multi-letter prefix within timeout', () {
      final m = ListLetterJumpMatcher();
      expect(jump('u', m), 2);
      expect(jump('s', m), 2);
      expect(jump('a', m), 2);
    });

    test('reset clears prefix', () {
      final m = ListLetterJumpMatcher();
      expect(jump('u', m), 2);
      m.reset();
      expect(jump('f', m), 0);
    });
  });
}
