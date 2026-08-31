import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/app/boot_needs.dart';
import 'package:forja/app/hub_boot_prefetch.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/lan/lan.dart';
import 'package:rust/rust.dart';

/// Starts profile-activated engines. Idempotent - safe from splash,
/// profile splash post-dismiss, and settings toggles.
///
/// Intro / profile splash should pass [startPlaySources]: false and
/// [startTorrent]: false so LocalServer / Nuvio / torrent stay
/// off the animation floor. Official ForjaHQ packs (+ optional hub layout/rails
/// prefetch into CatalogCache) always await during splash so Catalog Shell is
/// ready on dismiss.
class ProfileEngineWarm {
  ProfileEngineWarm._();

  static Future<void> warm(
    BootNeeds needs, {
    bool startTorrent = true,
    bool startPlaySources = true,
    bool awaitOfficialPacks = true,
    bool prefetchDefaultHub = false,
    String reason = 'boot',
    void Function(String status)? onStatus,
  }) async {
    debugPrint('[Init] warm ($reason): $needs');

    if (awaitOfficialPacks) {
      onStatus?.call('Loading plugins…');
      debugPrint('[Init] ForjaHQ install (await)');
      await EngineService.instance.ensureOfficialInstalled().catchError((
        Object e,
      ) {
        debugPrint('[Init] ForjaHQ install error (non-fatal): $e');
      });
      if (prefetchDefaultHub) {
        onStatus?.call(
          needs.homeTab ? 'Opening Home…' : 'Warming catalog…',
        );
        await prefetchDefaultHubLayout(needs);
      }
    }

    if (!startPlaySources) {
      debugPrint('[Init] LocalServer / Nuvio skip (deferred)');
    } else {
      if (needs.webstreaming) {
        onStatus?.call('Starting stream proxy…');
        debugPrint('[Init] LocalServer start (webstreaming)');
        await LocalServerService().start().catchError((e) {
          debugPrint('[Init] LocalServer error: $e');
        });
      } else if (!needs.playSourceWebstreaming) {
        debugPrint('[Init] LocalServer skip (webstreaming off)');
      } else {
        debugPrint('[Init] LocalServer skip (no VOD tab)');
      }

      if (needs.nuvio) {
        debugPrint('[Init] Nuvio defer hydrate to first Sources/Settings use');
      } else if (!needs.playSourceNuvio) {
        debugPrint('[Init] Nuvio skip (play source off)');
      } else {
        debugPrint('[Init] Nuvio skip (no VOD tab)');
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
