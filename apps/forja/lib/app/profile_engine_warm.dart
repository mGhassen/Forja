import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/app/boot_needs.dart';
import 'package:forja/app/hub_boot_prefetch.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
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
      debugPrint('[Init] PluginInstallCoordinator (await)');
      final coordinator = PluginInstallCoordinator.instance;
      // Splash / profile warm already own the bottom status line — drive that
      // instead of the in-shell progress card.
      final statusCb = onStatus;
      void Function()? forwardProgress;
      if (statusCb != null) {
        forwardProgress = () {
          final p = coordinator.progress.value;
          if (p == null) return;
          statusCb(p.label);
        };
        coordinator.suppressBanner.value = true;
        coordinator.progress.addListener(forwardProgress);
      }
      try {
        await coordinator
            .ensureAllInstalled(
              checkUpdates: true,
              awaitCloudLean: true,
              includeNuvio: needs.nuvio || needs.playSourceNuvio,
            )
            .catchError((Object e) {
              debugPrint('[Init] Plugin install error (non-fatal): $e');
            });
      } finally {
        if (forwardProgress != null) {
          coordinator.progress.removeListener(forwardProgress);
          coordinator.suppressBanner.value = false;
        }
      }
      if (prefetchDefaultHub) {
        onStatus?.call(needs.openingStatusLabel);
        await prefetchDefaultHubLayout(needs);
      }
    }

    if (!startPlaySources) {
      debugPrint('[Init] LocalServer / Nuvio skip (deferred)');
    } else {
      if (needs.engine) {
        onStatus?.call('Starting stream proxy…');
        debugPrint('[Init] LocalServer start (engine VOD)');
        await LocalServerService().start().catchError((e) {
          debugPrint('[Init] LocalServer error: $e');
        });
      } else if (!needs.playSourceEngine) {
        debugPrint('[Init] LocalServer skip (engine off)');
      } else {
        debugPrint('[Init] LocalServer skip (no VOD tab)');
      }

      if (needs.nuvio) {
        debugPrint('[Init] Nuvio scripts already hydrated via coordinator');
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
