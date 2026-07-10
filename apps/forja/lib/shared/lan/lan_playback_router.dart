import 'package:rust/rust.dart';

import 'lan_client_service.dart';
import 'lan_prefs.dart';
import 'lan_server_service.dart';

enum LanRouteDecision {
  playDirect,
  desktopServes,
  localEngine,
  unavailable,
}

/// Playback routing for LAN server/client (RFC-022 §4).
class LanPlaybackRouter {
  LanPlaybackRouter._();

  static bool get isDesktopServer => LanServerService.canRunServer;

  static Future<bool> hasPairedServer() => LanPrefs.instance.isPaired;

  static Future<bool> isServerOnline() =>
      LanClientService.instance.verifyPairedConnection();

  static Future<bool> shouldPreferDesktop(PlaybackProfile profile) async {
    if (isDesktopServer) return false;
    if (profile.localTorrentEngine &&
        await LanPrefs.instance.allowLocalTorrentOnDevice()) {
      return false;
    }
    if (!profile.preferDesktopServer &&
        profile.stremioInfoHash != StremioInfoHashPolicy.desktopServes) {
      return false;
    }
    return isServerOnline();
  }

  static Future<LanRouteDecision> routeDirectUrl() async =>
      LanRouteDecision.playDirect;

  static Future<LanRouteDecision> routeTorrent(PlaybackProfile profile) async {
    if (isDesktopServer) return LanRouteDecision.localEngine;
    if (profile.localTorrentEngine &&
        await LanPrefs.instance.allowLocalTorrentOnDevice()) {
      return LanRouteDecision.localEngine;
    }
    if (await shouldPreferDesktop(profile)) {
      return LanRouteDecision.desktopServes;
    }
    if (profile.stremioInfoHash == StremioInfoHashPolicy.desktopServes) {
      return LanRouteDecision.unavailable;
    }
    return LanRouteDecision.localEngine;
  }

  static Future<LanRouteDecision> routeProxyGated(
    PlaybackProfile profile,
  ) async {
    if (isDesktopServer) return LanRouteDecision.localEngine;
    if (await shouldPreferDesktop(profile)) {
      return LanRouteDecision.desktopServes;
    }
    return LanRouteDecision.localEngine;
  }

  static String unavailableMessage({required bool neverPaired}) {
    if (neverPaired) {
      return 'Pair with a desktop Forja server in Settings → LAN.';
    }
    return 'Desktop server is offline. Direct streams still work.';
  }

  static bool needsProxyRelay(String url) {
    final u = url.toLowerCase();
    return u.contains('127.0.0.1') ||
        u.contains('localhost') ||
        u.startsWith('mega://');
  }
}
