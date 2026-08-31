import 'dart:async';
import 'dart:math' as math;

/// Run [work] over [items] with at most [concurrency] in flight.
///
/// Preserves input order in the returned list (nulls omitted when [work]
/// returns null). Stops launching new work when [isCancelled] is true.
Future<List<R>> mapBoundedParallel<T, R>({
  required List<T> items,
  required Future<R?> Function(T item, int index) work,
  int concurrency = 3,
  bool Function()? isCancelled,
}) async {
  if (items.isEmpty) return const [];
  final limit = math.max(1, math.min(concurrency, items.length));
  final slots = List<R?>.filled(items.length, null);
  var next = 0;

  Future<void> worker() async {
    while (true) {
      if (isCancelled?.call() ?? false) return;
      final i = next++;
      if (i >= items.length) return;
      slots[i] = await work(items[i], i);
    }
  }

  await Future.wait(List.generate(limit, (_) => worker()));
  return [
    for (final slot in slots) ?slot,
  ];
}
