import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/app/boot_needs.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:rust/rust.dart';

/// Starts profile-activated engines. Idempotent — safe from intro splash,
/// profile splash, and settings toggles.
class ProfileEngineWarm {
  ProfileEngineWarm._();

  static Future<void> warm(
    BootNeeds needs, {
    bool startTorrent = true,
    String reason = 'boot',
    void Function(String status)? onStatus,
  }) async {
    debugPrint('[Init] warm ($reason): $needs');

    if (needs.webstreaming) {
      onStatus?.call('Starting stream proxy…');
      debugPrint('[Init] LocalServer start (webstreaming)');
      await LocalServerService().start().catchError((e) {
        debugPrint('[Init] LocalServer error: $e');
      });
      onStatus?.call('Starting WebStreamr…');
      debugPrint('[Init] WebStreamr start');
      unawaited(
        WebStreamrService.init().catchError((e) {
          debugPrint('[Init] WebStreamr error (non-fatal): $e');
        }),
      );
    } else if (!needs.playSourceWebstreaming) {
      debugPrint('[Init] LocalServer skip (webstreaming off)');
      debugPrint('[Init] WebStreamr skip (webstreaming off)');
    } else {
      debugPrint('[Init] LocalServer skip (no VOD tab)');
      debugPrint('[Init] WebStreamr skip (no VOD tab)');
    }

    if (needs.torrent) {
      onStatus?.call('Refreshing torrent addons…');
      debugPrint('[Init] Nuvio refresh (direct torrent)');
      unawaited(
        NuvioService.instance.refreshAllInstalled().catchError((e) {
          debugPrint('[Init] Nuvio refresh error (non-fatal): $e');
        }),
      );
      if (startTorrent && PlatformPlayback.capabilities.localTorrentEngine) {
        onStatus?.call('Starting torrent engine…');
        debugPrint('[Init] TorrentStream start (direct torrent)');
        final ok = await TorrentStreamService()
            .start()
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                debugPrint('[Init] TorrentStream timed out after 10s');
                return false;
              },
            )
            .catchError((e, st) {
              debugPrint('[Init] TorrentStream error: $e');
              debugPrint('[Init] Stack trace: $st');
              return false;
            });
        debugPrint(
          '[Init] TorrentStream ${ok ? "ready" : "failed"}',
        );
      } else if (!startTorrent) {
        debugPrint('[Init] TorrentStream skip (deferred to post-splash)');
      } else {
        debugPrint('[Init] TorrentStream skip (platform has no local engine)');
      }
    } else if (!needs.playSourceTorrent) {
      debugPrint('[Init] Nuvio skip (direct torrent off)');
      debugPrint('[Init] TorrentStream skip (direct torrent off)');
    } else {
      debugPrint('[Init] Nuvio skip (no VOD tab)');
      debugPrint('[Init] TorrentStream skip (no VOD tab)');
    }
  }
}
