import 'package:forja/shared/lan/lan_client_service.dart';
import 'package:forja/shared/lan/lan_prefs.dart';
import 'package:rust/rust.dart';

/// Effective Direct torrent / Stremio / Nuvio for UI, boot, and details.
///
/// [SettingsService.isPlaySource*Enabled] stays hard-off on Android TV so
/// unpaired leanback never inherits phone cloud prefs. When the TV is LAN
/// paired **and the desktop is online**, honor stored toggles (desktop relay).
/// Offline / unpaired → effective off; stored checks are kept for when the
/// desktop returns.
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

  /// Show Settings → Playback Direct torrent toggle (paired ATV, even offline).
  static Future<bool> showTorrentToggle() async {
    if (PlatformPlayback.capabilities.playSourceTorrent) return true;
    return LanPrefs.instance.isPaired;
  }

  /// Show Settings → Playback Stremio toggle.
  static Future<bool> showStremioToggle() async {
    if (PlatformPlayback.capabilities.playSourceStremio) return true;
    return LanPrefs.instance.isPaired;
  }

  /// Show Settings → Playback Nuvio toggle.
  static Future<bool> showNuvioToggle() async {
    if (PlatformPlayback.capabilities.playSourceNuvio) return true;
    return LanPrefs.instance.isPaired;
  }

  /// Whether LAN-client play-source toggles accept input.
  static Future<bool> lanPlaySourcesEditable() async {
    final caps = PlatformPlayback.capabilities;
    if (caps.playSourceTorrent ||
        caps.playSourceStremio ||
        caps.playSourceNuvio) {
      return true;
    }
    return lanDesktopReady();
  }

  static Future<bool> torrent([
    SettingsService? settings,
    bool? lanReady,
  ]) async {
    final s = settings ?? SettingsService();
    final caps = PlatformPlayback.capabilities;
    if (caps.playSourceTorrent) return s.isPlaySourceTorrentEnabled();
    final ready = lanReady ?? await lanDesktopReady();
    if (!ready) return false;
    return s.isPlaySourceTorrentStored();
  }

  static Future<bool> stremio([
    SettingsService? settings,
    bool? lanReady,
  ]) async {
    final s = settings ?? SettingsService();
    final caps = PlatformPlayback.capabilities;
    if (caps.playSourceStremio) return s.isPlaySourceStremioEnabled();
    final ready = lanReady ?? await lanDesktopReady();
    if (!ready) return false;
    return s.isPlaySourceStremioStored();
  }

  static Future<bool> nuvio([
    SettingsService? settings,
    bool? lanReady,
  ]) async {
    final s = settings ?? SettingsService();
    final caps = PlatformPlayback.capabilities;
    if (caps.playSourceNuvio) return s.isPlaySourceNuvioEnabled();
    final ready = lanReady ?? await lanDesktopReady();
    if (!ready) return false;
    return s.isPlaySourceNuvioStored();
  }
}
