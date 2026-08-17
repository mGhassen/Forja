import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/app/boot_needs.dart';
import 'package:forja/shared/lan/lan.dart';
import 'package:rust/rust.dart';

/// Starts profile-activated engines. Idempotent - safe from post-splash,
/// profile splash post-dismiss, and settings toggles.
///
/// Intro / profile splash should pass [startPlaySources]: false and
/// [startTorrent]: false so LocalServer / WebStreamr / Nuvio / torrent stay
/// off the animation floor (they belong with Sources / details, not boot).
class ProfileEngineWarm {
  ProfileEngineWarm._();

  static Future<void> warm(
    BootNeeds needs, {
    bool startTorrent = true,
    bool startPlaySources = true,
    String reason = 'boot',
    void Function(String status)? onStatus,
  }) async {
    debugPrint('[Init] warm ($reason): $needs');

    if (!startPlaySources) {
      debugPrint('[Init] LocalServer / WebStreamr / Nuvio skip (deferred)');
    } else {
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

      if (needs.nuvio) {
        // Lean list from cloud sync is enough at warm — fetch scrapers only
        // when Settings / Sources actually opens Nuvio (not while on IPTV).
        debugPrint('[Init] Nuvio defer hydrate to first Sources/Settings use');
      } else if (!needs.playSourceNuvio) {
        debugPrint('[Init] Nuvio skip (play source off)');
      } else {
        debugPrint('[Init] Nuvio skip (no VOD tab)');
      }

      if (needs.engine) {
        debugPrint('[Init] engineJS defer hydrate to first Sources/Settings use');
      } else if (!needs.playSourceEngine) {
        debugPrint('[Init] engineJS skip (play source off)');
      } else {
        debugPrint('[Init] engineJS skip (no VOD tab)');
      }
    }

    if (needs.torrent) {
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
      debugPrint('[Init] TorrentStream skip (direct torrent off)');
    } else {
      debugPrint('[Init] TorrentStream skip (no VOD tab)');
    }

    // After torrent/proxy warm — never race Engine.init (sticky port miss).
    if (startTorrent && LanServerService.canRunServer) {
      unawaited(
        LanServerService.instance.restoreIfEnabled().then((ok) {
          if (ok) {
            debugPrint(
              '[Init] LAN server restored on :${LanServerService.instance.port}',
            );
          }
        }),
      );
    }
  }
}
