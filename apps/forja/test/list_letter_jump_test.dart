import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/widgets/list_letter_jump_scope.dart';

void main() {
  group('ListLetterJumpMatcher', () {
    final labels = ['France', 'Finland', 'USA', 'Uruguay'];

    int? jump(String letter, ListLetterJumpMatcher matcher, {int ms = 1}) {
      return matcher.nextIndex(
        letter: letter,
        timeStamp: Duration(milliseconds: ms),
        itemCount: labels.length,
        labelAt: (i) => labels[i],
      );
    }

    int? jumpAt(
      String letter,
      ListLetterJumpMatcher matcher,
      int ms, {
      int anchor = -1,
    }) {
      return matcher.nextIndex(
        letter: letter,
        timeStamp: Duration(milliseconds: ms),
        itemCount: labels.length,
        labelAt: (i) => labels[i],
        anchorIndex: anchor,
      );
    }

    test('first letter match', () {
      final m = ListLetterJumpMatcher();
      expect(jump('f', m), 0);
    });

    test('repeat letter cycles matches without wrapping', () {
      final m = ListLetterJumpMatcher();
      expect(jump('f', m), 0);
      expect(jump('f', m, ms: 2), 1);
      expect(jump('f', m, ms: 3), 1);
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

    test('fresh letter continues after anchor', () {
      final m = ListLetterJumpMatcher();
      expect(jumpAt('f', m, 0, anchor: 1), 0);
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

    test('new multi-char query after prior match (fr then es)', () {
      final labels = ['EU | FRANCE', 'DEPORTES', 'ESPN HD'];
      final m = ListLetterJumpMatcher();
      expect(
        m.nextIndices(
          letters: 'fr',
          timeStamp: const Duration(milliseconds: 1),
          itemCount: labels.length,
          labelAt: (i) => labels[i],
        ),
        0,
      );
      expect(
        m.nextIndices(
          letters: 'es',
          timeStamp: const Duration(milliseconds: 40),
          itemCount: labels.length,
          labelAt: (i) => labels[i],
        ),
        1,
      );
    });

    test('es matches deportes and espn', () {
      final labels = ['AF | AFRICA', 'DEPORTES', 'ESPN HD'];
      final m = ListLetterJumpMatcher();
      expect(
        m.nextIndices(
          letters: 'es',
          timeStamp: const Duration(milliseconds: 1),
          itemCount: labels.length,
          labelAt: (i) => labels[i],
        ),
        1,
      );
    });

    test('multi-letter matches token not buried in word', () {
      final labels = ['AF | AFRICA', 'EU | FRANCE', 'EU | FR - live'];
      final m = ListLetterJumpMatcher();
      expect(
        m.nextIndices(
          letters: 'fr',
          timeStamp: const Duration(milliseconds: 1),
          itemCount: labels.length,
          labelAt: (i) => labels[i],
        ),
        1,
      );
      expect(
        m.nextIndex(
          letter: 'f',
          timeStamp: const Duration(milliseconds: 40),
          itemCount: labels.length,
          labelAt: (i) => labels[i],
        ),
        2,
      );
    });

    test('multi-letter matches substring anywhere in label', () {
      final labels = ['Spain', 'EU | FR - live', 'Germany'];
      final m = ListLetterJumpMatcher();
      expect(
        m.nextIndices(
          letters: 'fr',
          timeStamp: const Duration(milliseconds: 1),
          itemCount: labels.length,
          labelAt: (i) => labels[i],
        ),
        1,
      );
    });

    test('lettersFromKeyDown uses logical key when character is null', () {
      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyF,
        logicalKey: LogicalKeyboardKey.keyF,
        character: null,
        timeStamp: Duration.zero,
      );
      expect(ListLetterJumpMatcher.lettersFromKeyDown(event), 'f');
    });

    test('tf finds TF1 channel codes', () {
      final labels = [
        'TMC',
        'TNT Sport',
        'France 2',
        'TF1',
        'TF1 HD',
        'FR | TF1 FHD',
        'M6',
      ];
      final m = ListLetterJumpMatcher();
      expect(
        m.nextIndices(
          letters: 'tf',
          timeStamp: const Duration(milliseconds: 1),
          itemCount: labels.length,
          labelAt: (i) => labels[i],
        ),
        3,
      );
    });
  });
}
