import 'package:forja/shared/lan/lan_client_service.dart';
import 'package:forja/shared/lan/lan_prefs.dart';
import 'package:rust/rust.dart';

/// Effective Direct torrent / Stremio / Nuvio for UI, boot, and details.
///
/// Android TV honors stored toggles without pairing. Magnets still need a
/// paired desktop at play time (`ensureLanP2pPlayback`); HTTP plays locally.
abstract final class PlaySourceEffective {
  /// Test-only: force LAN desktop online/offline after pair. `null` = real health.
  static bool? debugForceLanDesktopOnline;

  /// Paired + desktop answering `/health` (LAN client path).
  static Future<bool> lanDesktopReady() async {
    if (!await LanPrefs.instance.isPaired) return false;
    final forced = debugForceLanDesktopOnline;
    if (forced != null) return forced;
    return LanClientService.instance.verifyPairedConnection();
  }

  static Future<bool> showTorrentToggle() async =>
      PlatformPlayback.capabilities.playSourceTorrent;

  static Future<bool> showStremioToggle() async =>
      PlatformPlayback.capabilities.playSourceStremio;

  static Future<bool> showNuvioToggle() async =>
      PlatformPlayback.capabilities.playSourceNuvio;

  static Future<bool> showEngineToggle() async =>
      PlatformPlayback.capabilities.playSourceEngine;

  /// Play-source toggles always accept input when the platform exposes them.
  static Future<bool> lanPlaySourcesEditable() async =>
      PlatformPlayback.capabilities.playSourceTorrent ||
      PlatformPlayback.capabilities.playSourceStremio ||
      PlatformPlayback.capabilities.playSourceNuvio ||
      PlatformPlayback.capabilities.playSourceEngine;

  static Future<bool> torrent([
    SettingsService? settings,
    bool? lanReady,
  ]) async {
    final s = settings ?? SettingsService();
    return s.isPlaySourceTorrentEnabled();
  }

  static Future<bool> stremio([
    SettingsService? settings,
    bool? lanReady,
  ]) async {
    final s = settings ?? SettingsService();
    return s.isPlaySourceStremioEnabled();
  }

  static Future<bool> nuvio([
    SettingsService? settings,
    bool? lanReady,
  ]) async {
    final s = settings ?? SettingsService();
    return s.isPlaySourceNuvioEnabled();
  }

  static Future<bool> engine([
    SettingsService? settings,
    bool? lanReady,
  ]) async {
    final s = settings ?? SettingsService();
    return s.isPlaySourceEngineEnabled();
  }
}
