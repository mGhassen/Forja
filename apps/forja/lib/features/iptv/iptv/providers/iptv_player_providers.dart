import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/iptv/iptv/data/storage.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:rust/rust.dart';

/// IPTV player boot prefs (last volume + EPG). Engine choice is per-surface KV
/// (`vod` for Movies/Series, `iptv` for Live) via Settings / Player menu.
@immutable
class IptvPlayerBootPrefs {
  const IptvPlayerBootPrefs({
    required this.volume,
    required this.epgEnabled,
    required this.liveRecoveryMode,
  });

  final double volume;
  final bool epgEnabled;
  /// [SettingsService.iptvLiveRecoveryStall] (default), buffered, or classic.
  final String liveRecoveryMode;
}

final iptvPlayerBootPrefsProvider =
    FutureProvider.autoDispose<IptvPlayerBootPrefs>((ref) async {
  final playback = await ref.watch(settingsPlaybackProvider.future);
  final volume = await IptvStore.loadPlayerVolume();
  final recovery = await SettingsService().getIptvLiveRecoveryMode();
  return IptvPlayerBootPrefs(
    volume: volume,
    epgEnabled: playback.iptvEpgEnabled,
    liveRecoveryMode: recovery,
  );
});

/// Live EPG toggle for IPTV chrome (tracks Settings playback snapshot).
final iptvEpgEnabledProvider = Provider.autoDispose<bool>((ref) {
  final snap = ref.watch(settingsPlaybackProvider).valueOrNull;
  if (snap != null) return snap.iptvEpgEnabled;
  return SettingsService.iptvEpgEnabledNotifier.value;
});
