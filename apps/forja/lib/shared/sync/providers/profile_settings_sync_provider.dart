import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/sync/providers/account_features_provider.dart';
import 'package:forja/shared/sync/providers/settings_revision_providers.dart';
import 'package:forja/shared/sync/providers/sync_identity_provider.dart';
import 'package:forja/shared/sync/src/sync_domain_bridge.dart';

/// Pull cloud profile settings into local cache, then ensure Riverpod watches
/// refresh. [SettingsService] / [AccountFeatures] notifiers already bump;
/// this also invalidates providers for listeners that missed a no-op bump.
final profileSettingsSyncProvider =
    AsyncNotifierProvider<ProfileSettingsSyncNotifier, void>(
  ProfileSettingsSyncNotifier.new,
);

class ProfileSettingsSyncNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Focus/resume refresh — apply cloud over cache (no platform-default nav flash).
  Future<void> pullAndMergeAll() => _run(resetLocalFirst: false);

  /// Profile switch / first bind — wipe prior profile cache then apply cloud.
  Future<void> pullAndMergeForProfileSwitch() => _run(resetLocalFirst: true);

  Future<void> _run({required bool resetLocalFirst}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (resetLocalFirst) {
        await SyncDomainBridge.instance.pullAndMergeAll(resetLocalFirst: true);
      } else {
        await SyncDomainBridge.instance.syncFromCloud(force: true);
      }
      ref.invalidate(accountFeaturesRevisionProvider);
      ref.invalidate(navbarRevisionProvider);
      ref.invalidate(playSourceRevisionProvider);
      ref.invalidate(addonRevisionProvider);
      ref.invalidate(syncIdentityRevisionProvider);
    });
  }
}
