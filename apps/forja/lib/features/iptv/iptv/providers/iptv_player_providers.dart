import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/iptv/iptv/data/storage.dart';
import 'package:forja/features/iptv/iptv/m3u/m3u_models.dart';
import 'package:forja/features/iptv/iptv/m3u/m3u_store.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:rust/rust.dart';

/// IPTV player boot prefs (last volume + EPG). Engine choice is per-surface KV
/// via [SettingsService.getBuiltInPlayerEngine] + [BuiltInPlayerContext].
@immutable
class IptvPlayerBootPrefs {
  const IptvPlayerBootPrefs({
    required this.volume,
    required this.epgEnabled,
  });

  final double volume;
  final bool epgEnabled;
}

final iptvPlayerBootPrefsProvider =
    FutureProvider.autoDispose<IptvPlayerBootPrefs>((ref) async {
  final playback = await ref.watch(settingsPlaybackProvider.future);
  final volume = await IptvStore.loadPlayerVolume();
  return IptvPlayerBootPrefs(
    volume: volume,
    epgEnabled: playback.iptvEpgEnabled,
  );
});

/// Live EPG toggle for IPTV chrome (tracks Settings playback snapshot).
final iptvEpgEnabledProvider = Provider.autoDispose<bool>((ref) {
  final snap = ref.watch(settingsPlaybackProvider).valueOrNull;
  if (snap != null) return snap.iptvEpgEnabled;
  return SettingsService.iptvEpgEnabledNotifier.value;
});

final m3uPlaylistsProvider =
    AsyncNotifierProvider<M3uPlaylistsNotifier, List<M3uPlaylist>>(
  M3uPlaylistsNotifier.new,
);

class M3uPlaylistsNotifier extends AsyncNotifier<List<M3uPlaylist>> {
  @override
  Future<List<M3uPlaylist>> build() => M3uStore.loadAll();

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(M3uStore.loadAll);
  }

  Future<void> save(List<M3uPlaylist> list) async {
    await M3uStore.saveAll(list);
    state = AsyncData(list);
  }
}
