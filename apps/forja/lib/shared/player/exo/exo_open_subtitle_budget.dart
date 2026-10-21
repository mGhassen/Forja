import 'dart:async';

/// How long the first video open waits for provider subtitle sideloads.
///
/// Sideloads are downloaded to local files before Media3 can mount them.
/// Anything slower than this opens later through the soft subtitle reload so
/// the picture is never held back by a slow or dead subtitle host.
const Duration exoOpenSubtitleBudget = Duration(milliseconds: 1500);

/// How long the late batch collects stragglers before the one soft reload.
///
/// A soft reload re-prepares the media, so late tracks are attached once,
/// together. Tracks still downloading after this stay listed in the subtitle
/// menu and load on pick.
const Duration exoLateSubtitleBudget = Duration(seconds: 8);

/// Results of [settleWithinBudget] split by whether they beat the budget.
class SettledWithinBudget<T> {
  const SettledWithinBudget({required this.ready, required this.pending});

  /// Non-null results that completed inside the budget, in input order.
  final List<T> ready;

  /// Futures that had not settled at the deadline, in input order. Each
  /// yields null on error so a caller can feed them straight back into
  /// [settleWithinBudget] for a second round.
  final List<Future<T?>> pending;
}

/// Wait up to [budget] for [futures]; return what finished, and the rest.
///
/// Null results are dropped from [SettledWithinBudget.ready]. Errors count
/// as null so one bad download never blocks the others. Returns as soon as
/// every future settles when that happens before the deadline.
Future<SettledWithinBudget<T>> settleWithinBudget<T>(
  List<Future<T?>> futures,
  Duration budget,
) async {
  if (futures.isEmpty) {
    return SettledWithinBudget<T>(ready: const [], pending: const []);
  }
  final results = List<T?>.filled(futures.length, null);
  final settled = List<bool>.filled(futures.length, false);
  var remaining = futures.length;
  final allDone = Completer<void>();

  final tracked = <Future<T?>>[];
  for (var i = 0; i < futures.length; i++) {
    tracked.add(
      futures[i].then<T?>((v) => v, onError: (Object _) => null).then((v) {
        results[i] = v;
        settled[i] = true;
        remaining--;
        if (remaining == 0 && !allDone.isCompleted) allDone.complete();
        return v;
      }),
    );
  }

  await Future.any<void>([allDone.future, Future<void>.delayed(budget)]);

  final ready = <T>[];
  final pending = <Future<T?>>[];
  for (var i = 0; i < futures.length; i++) {
    if (settled[i]) {
      final v = results[i];
      if (v != null) ready.add(v);
    } else {
      pending.add(tracked[i]);
    }
  }
  return SettledWithinBudget<T>(ready: ready, pending: pending);
}
