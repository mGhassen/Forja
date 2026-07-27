import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/sync/src/sync_service.dart';

/// Mirrors [SyncService.identityRevision] for profile chrome rebuilds.
final syncIdentityRevisionProvider =
    NotifierProvider<SyncIdentityRevisionNotifier, int>(
  SyncIdentityRevisionNotifier.new,
);

class SyncIdentityRevisionNotifier extends Notifier<int> {
  @override
  int build() {
    final n = SyncService.instance.identityRevision;
    void listener() => state = n.value;
    n.addListener(listener);
    ref.onDispose(() => n.removeListener(listener));
    return n.value;
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  ref.watch(syncIdentityRevisionProvider);
  return SyncService.instance;
});
