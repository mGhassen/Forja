import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';

/// Bumps when [MyListService.changeNotifier] changes.
final myListRevisionProvider = NotifierProvider<MyListRevisionNotifier, int>(
  MyListRevisionNotifier.new,
);

class MyListRevisionNotifier extends Notifier<int> {
  @override
  int build() {
    final n = MyListService.changeNotifier;
    void listener() => state = n.value;
    n.addListener(listener);
    ref.onDispose(() => n.removeListener(listener));
    return n.value;
  }
}

/// My List tab items (backend remains [MyListService]).
final myListItemsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  ref.watch(myListRevisionProvider);
  return MyListService().items;
});
