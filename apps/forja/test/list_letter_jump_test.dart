import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/widgets/list_letter_jump_scope.dart';

void main() {
  group('ListLetterJumpMatcher', () {
    final labels = ['France', 'Finland', 'USA', 'Uruguay'];

    int? jump(String letter, ListLetterJumpMatcher matcher) {
      return matcher.nextIndex(
        letter: letter,
        timeStamp: const Duration(milliseconds: 1),
        itemCount: labels.length,
        labelAt: (i) => labels[i],
      );
    }

    int? jumpAt(String letter, ListLetterJumpMatcher matcher, int ms) {
      return matcher.nextIndex(
        letter: letter,
        timeStamp: Duration(milliseconds: ms),
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
      expect(jumpAt('u', m, 0), 2);
      expect(jumpAt('s', m, 50), 2);
      expect(jumpAt('a', m, 100), 2);
    });

    test('extend prefix fi finds finland', () {
      final m = ListLetterJumpMatcher();
      expect(jumpAt('f', m, 0), 0);
      expect(jumpAt('i', m, 40), 1);
    });

    test('batched letters in one event', () {
      final m = ListLetterJumpMatcher();
      expect(
        m.nextIndices(
          letters: 'fi',
          timeStamp: const Duration(milliseconds: 1),
          itemCount: labels.length,
          labelAt: (i) => labels[i],
        ),
        1,
      );
    });

    test('reset clears prefix', () {
      final m = ListLetterJumpMatcher();
      expect(jump('u', m), 2);
      m.reset();
      expect(jump('f', m), 0);
    });

    test('letterFromKeyDown uses keyLabel when character is null', () {
      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyF,
        logicalKey: LogicalKeyboardKey.keyF,
        character: null,
        timeStamp: Duration.zero,
      );
      expect(ListLetterJumpMatcher.lettersFromKeyDown(event), 'f');
    });
  });
}
