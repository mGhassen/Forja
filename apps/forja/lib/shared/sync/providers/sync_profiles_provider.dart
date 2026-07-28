import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/sync/providers/sync_identity_provider.dart';
import 'package:forja/shared/sync/src/sync_service.dart';
import 'package:forja/shared/sync/src/tv_device_link_auth.dart';

@immutable
class SyncProfilesSnapshot {
  const SyncProfilesSnapshot({
    required this.profiles,
    this.activeProfileId,
  });

  final List<SyncProfile> profiles;
  final String? activeProfileId;
}

/// Profile list for Who's watching (TV + desktop gate).
final syncProfilesProvider =
    AsyncNotifierProvider<SyncProfilesNotifier, SyncProfilesSnapshot>(
  SyncProfilesNotifier.new,
);

class SyncProfilesNotifier extends AsyncNotifier<SyncProfilesSnapshot> {
  @override
  Future<SyncProfilesSnapshot> build() async {
    ref.watch(syncIdentityRevisionProvider);
    return _load();
  }

  Future<SyncProfilesSnapshot> _load() async {
    final sync = ref.read(syncServiceProvider);
    final profiles = await sync.listProfiles();
    final active = await sync.activeProfile(profiles: profiles);
    return SyncProfilesSnapshot(
      profiles: profiles,
      activeProfileId: active?.id,
    );
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

/// TV device-link session (create + hold for poll). UI owns step/focus.
final tvDeviceLinkSessionProvider = AsyncNotifierProvider.autoDispose<
    TvDeviceLinkSessionNotifier, TvDeviceLinkSession?>(
  TvDeviceLinkSessionNotifier.new,
);

class TvDeviceLinkSessionNotifier
    extends AutoDisposeAsyncNotifier<TvDeviceLinkSession?> {
  @override
  Future<TvDeviceLinkSession?> build() async => null;

  Future<TvDeviceLinkSession> create() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(TvDeviceLinkAuth.create);
    final session = state.valueOrNull;
    if (session == null) {
      throw state.error ?? StateError('TV device link create failed');
    }
    return session;
  }

  void clear() => state = const AsyncData(null);
}
