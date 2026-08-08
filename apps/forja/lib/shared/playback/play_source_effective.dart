import 'package:forja/shared/lan/lan_prefs.dart';
import 'package:rust/rust.dart';

/// Effective Direct torrent / Stremio / Nuvio for UI, boot, and details.
///
/// [SettingsService.isPlaySource*Enabled] stays hard-off on Android TV so
/// unpaired leanback never inherits phone cloud prefs. When the TV is LAN
/// paired, honor stored toggles so Playback settings and Sources can use the
/// desktop relay.
abstract final class PlaySourceEffective {
  /// Show Settings → Playback Direct torrent toggle.
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

  static Future<bool> torrent([SettingsService? settings]) async {
    final s = settings ?? SettingsService();
    final caps = PlatformPlayback.capabilities;
    if (caps.playSourceTorrent) return s.isPlaySourceTorrentEnabled();
    if (await LanPrefs.instance.isPaired) {
      return s.isPlaySourceTorrentStored();
    }
    return false;
  }

  static Future<bool> stremio([SettingsService? settings]) async {
    final s = settings ?? SettingsService();
    final caps = PlatformPlayback.capabilities;
    if (caps.playSourceStremio) return s.isPlaySourceStremioEnabled();
    if (await LanPrefs.instance.isPaired) {
      return s.isPlaySourceStremioStored();
    }
    return false;
  }

  static Future<bool> nuvio([SettingsService? settings]) async {
    final s = settings ?? SettingsService();
    final caps = PlatformPlayback.capabilities;
    if (caps.playSourceNuvio) return s.isPlaySourceNuvioEnabled();
    if (await LanPrefs.instance.isPaired) {
      return s.isPlaySourceNuvioStored();
    }
    return false;
  }
}
