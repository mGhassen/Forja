/// How many catalog rows below the visible one to warm-fetch.
const int kKitRowPrefetchAhead = 2;

/// Shell row index → warm callback registry. Row [index] calls [notifyVisible]
/// to start fetching for [index + 1] … [index + ahead] without waiting for
/// their [VisibilityDetector].
///
/// Late-mounted rows (below-fold slivers that claim after a higher row is
/// already visible) warm immediately when their index is still inside the
/// ahead window — otherwise prefetch silently no-ops until the row itself
/// scrolls on-screen.
class KitRowPrefetchLane {
  KitRowPrefetchLane({this.ahead = kKitRowPrefetchAhead});

  final int ahead;
  final List<void Function()> _warmers = [];
  int _next = 0;
  int? _lastVisible;
  int generation = 0;

  /// Highest index that has called [notifyVisible] this generation.
  int? get lastVisible => _lastVisible;

  void reset() {
    _warmers.clear();
    _next = 0;
    _lastVisible = null;
    generation++;
  }

  /// Claim the next paint-order index and register [warm].
  int claim(void Function() warm) {
    final index = _next++;
    register(index, warm);
    final last = _lastVisible;
    if (last != null && index > last && index <= last + ahead) {
      warm();
    }
    return index;
  }

  void register(int index, void Function() warm) {
    while (_warmers.length <= index) {
      _warmers.add(() {});
    }
    _warmers[index] = warm;
  }

  void notifyVisible(int index) {
    final prev = _lastVisible;
    if (prev == null || index > prev) {
      _lastVisible = index;
    }
    for (var i = 1; i <= ahead; i++) {
      final next = index + i;
      if (next >= _warmers.length) break;
      _warmers[next]();
    }
  }
}

class KitRowPrefetchSlot {
  const KitRowPrefetchSlot({
    required this.lane,
    required this.index,
  });

  final KitRowPrefetchLane lane;
  final int index;

  void notifyVisible() => lane.notifyVisible(index);
}
