/// How many catalog rows below the visible one to warm-fetch.
const int kKitRowPrefetchAhead = 1;

/// Shell row index → warm callback registry. Row [index] calls [notifyVisible]
/// to start fetching for [index + 1] … [index + ahead] without waiting for
/// their [VisibilityDetector].
class KitRowPrefetchLane {
  KitRowPrefetchLane({this.ahead = kKitRowPrefetchAhead});

  final int ahead;
  final List<void Function()> _warmers = [];

  void reset() => _warmers.clear();

  void register(int index, void Function() warm) {
    while (_warmers.length <= index) {
      _warmers.add(() {});
    }
    _warmers[index] = warm;
  }

  void notifyVisible(int index) {
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
