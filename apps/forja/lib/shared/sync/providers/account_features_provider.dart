import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/sync/src/account_features.dart';

/// Bumps whenever [AccountFeatures.revision] changes (keepAlive session).
final accountFeaturesRevisionProvider =
    NotifierProvider<AccountFeaturesRevisionNotifier, int>(
  AccountFeaturesRevisionNotifier.new,
);

class AccountFeaturesRevisionNotifier extends Notifier<int> {
  @override
  int build() {
    final n = AccountFeatures.instance.revision;
    void listener() => state = n.value;
    n.addListener(listener);
    ref.onDispose(() => n.removeListener(listener));
    return n.value;
  }
}

/// Watch this for IPTV / Settings feature flags. Backend remains
/// [AccountFeatures.instance].
final accountFeaturesProvider = Provider<AccountFeatures>((ref) {
  ref.watch(accountFeaturesRevisionProvider);
  return AccountFeatures.instance;
});
