import 'package:forja/shared/catalog/kit/sources/live_schedule/data/live_iptv_sports_config.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:rust/rust.dart';

/// Host-owned Live Sports modes (RFC-071). Pack does not declare the list.
enum LiveModeId {
  forjaLive,
  forjaSports,
  stremio,
}

extension LiveModeIdX on LiveModeId {
  String get wireId => switch (this) {
        LiveModeId.forjaLive => 'forja_live',
        LiveModeId.forjaSports => 'forja_sports',
        LiveModeId.stremio => 'stremio',
      };

  String get label => switch (this) {
        LiveModeId.forjaLive => 'Forja Live',
        LiveModeId.forjaSports => 'Forja Sports',
        LiveModeId.stremio => 'Stremio',
      };

  String get subtitle => switch (this) {
        LiveModeId.forjaLive => 'Engine live plugins',
        LiveModeId.forjaSports => 'Catalog schedule · your Xtream',
        LiveModeId.stremio => 'Installed live addons',
      };

  static LiveModeId? tryParse(String? raw) {
    final s = (raw ?? '').trim();
    return switch (s) {
      'forja_live' || 'forjaLive' => LiveModeId.forjaLive,
      'forja_sports' || 'iptvSports' || 'iptv_sports' => LiveModeId.forjaSports,
      'stremio' => LiveModeId.stremio,
      // Legacy hidden server prefs clamp to Forja Live.
      'all' || 'ppv' || 'streamed' || 'mutStreams' => LiveModeId.forjaLive,
      _ => null,
    };
  }
}

/// Discovers which Live Sports modes are active from Settings / packs.
abstract final class LiveModeRegistry {
  LiveModeRegistry._();

  /// Pref key for selected mode (migrated from `live_matches_server_v1`).
  static const modePreferenceKey = 'live_matches_mode_v1';
  static const legacyServerPreferenceKey = 'live_matches_server_v1';

  /// Modes that share the Forja Live catalog schedule (switch play path only).
  static bool sharesCatalogSchedule(LiveModeId a, LiveModeId b) {
    bool shared(LiveModeId m) =>
        m == LiveModeId.forjaLive || m == LiveModeId.forjaSports;
    return shared(a) && shared(b);
  }

  static Future<bool> stremioLiveEnabled() =>
      StremioService().hasInstalledLiveAddons();

  static Future<bool> forjaSportsEnabled() async {
    return (await LiveMatchesIptvSportsConfig.load()).enabled;
  }

  static Future<bool> forjaLiveEnabled() async {
    final catalogs =
        await EngineService.instance.listEnabledLiveCatalogPlugins();
    return catalogs.isNotEmpty;
  }

  /// Active modes for the mode picker (order: Forja Live, Forja Sports, Stremio).
  static Future<List<LiveModeId>> activeModes() async {
    final sports = await forjaSportsEnabled();
    final stremio = await stremioLiveEnabled();
    // Forja Live stays listed even if catalogs temporarily empty (Settings path).
    return [
      LiveModeId.forjaLive,
      if (sports) LiveModeId.forjaSports,
      if (stremio) LiveModeId.stremio,
    ];
  }

  static Future<LiveModeId> clamp(LiveModeId mode) async {
    final allowed = await activeModes();
    if (allowed.contains(mode)) return mode;
    return LiveModeId.forjaLive;
  }
}
