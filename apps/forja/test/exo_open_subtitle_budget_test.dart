import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/exo/exo_open_subtitle_budget.dart';

Future<T?> _after<T>(int ms, T? Function() build) =>
    Future<T?>.delayed(Duration(milliseconds: ms), build);

void main() {
  group('settleWithinBudget', () {
    test(
      'everything fast → all ready, nothing pending, returns early',
      () async {
        final sw = Stopwatch()..start();
        final out = await settleWithinBudget<String>([
          _after(10, () => 'a'),
          _after(20, () => 'b'),
        ], const Duration(seconds: 5));
        expect(out.ready, ['a', 'b']);
        expect(out.pending, isEmpty);
        expect(
          sw.elapsed,
          lessThan(const Duration(seconds: 2)),
          reason: 'must return when all settle, not at the deadline',
        );
      },
    );

    test(
      'slow results stay pending in order; a second round collects them',
      () async {
        final out = await settleWithinBudget<String>([
          _after(10, () => 'fast'),
          _after(300, () => 'slow-1'),
          _after(20, () => null),
          _after(400, () => null),
          _after(350, () => 'slow-2'),
        ], const Duration(milliseconds: 120));
        expect(out.ready, ['fast']);
        expect(out.pending.length, 3);

        final second = await settleWithinBudget<String>(
          out.pending,
          const Duration(seconds: 5),
        );
        expect(second.ready, ['slow-1', 'slow-2']);
        expect(second.pending, isEmpty);
      },
    );

    test(
      'a second short round drops stragglers but keeps what landed',
      () async {
        final first = await settleWithinBudget<String>([
          _after(200, () => 'mid'),
          _after(2000, () => 'never'),
        ], const Duration(milliseconds: 50));
        expect(first.ready, isEmpty);
        final second = await settleWithinBudget<String>(
          first.pending,
          const Duration(milliseconds: 400),
        );
        expect(second.ready, ['mid']);
        expect(second.pending.length, 1);
      },
    );

    test('errors count as null and never block the others', () async {
      final out = await settleWithinBudget<String>([
        _after<String>(5, () => throw StateError('boom')),
        _after(10, () => 'ok'),
        _after<String>(300, () => throw StateError('late boom')),
      ], const Duration(milliseconds: 120));
      expect(out.ready, ['ok']);
      final second = await settleWithinBudget<String>(
        out.pending,
        const Duration(seconds: 5),
      );
      expect(second.ready, isEmpty);
    });

    test('empty input resolves immediately', () async {
      final out = await settleWithinBudget<String>(
        const [],
        const Duration(seconds: 5),
      );
      expect(out.ready, isEmpty);
      expect(out.pending, isEmpty);
    });

    test('open budget is short; late budget is bounded', () {
      expect(
        exoOpenSubtitleBudget,
        lessThanOrEqualTo(const Duration(seconds: 2)),
      );
      expect(exoLateSubtitleBudget, greaterThan(exoOpenSubtitleBudget));
      expect(
        exoLateSubtitleBudget,
        lessThanOrEqualTo(const Duration(seconds: 15)),
      );
    });
  });
}
