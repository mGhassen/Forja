import 'package:flutter/foundation.dart';

import '../../platform_profile.dart';
import '../../settings_service.dart';

/// How Stremio `infoHash` streams are handled on this platform.
enum StremioInfoHashPolicy {
  /// Local librqbit engine or debrid.
  localEngine,

  /// Debrid only — show streams but reject play without debrid.
  debridOnly,

  /// Hide hash-based streams in the UI (TV / web without debrid).
  hidden,
}

/// Platform playback capabilities (Stremio desktop vs constrained/TV model).
class PlaybackProfile {
  final bool localTorrentEngine;
  final StremioInfoHashPolicy stremioInfoHash;
  final bool stremioUrl;
  final bool builtinTorrentSearch;

  /// Whether Settings / Sources may expose Direct torrent (not admin-gated).
  final bool playSourceTorrent;

  /// Whether Settings / Sources / Home catalogs may expose Stremio.
  final bool playSourceStremio;

  /// Whether Settings / Sources may expose Nuvio.
  final bool playSourceNuvio;

  const PlaybackProfile({
    required this.localTorrentEngine,
    required this.stremioInfoHash,
    this.stremioUrl = true,
    required this.builtinTorrentSearch,
    required this.playSourceTorrent,
    required this.playSourceStremio,
    required this.playSourceNuvio,
  });

  /// Desktop / Android / iOS — full torrent engine + hash playback.
  static const desktop = PlaybackProfile(
    localTorrentEngine: true,
    stremioInfoHash: StremioInfoHashPolicy.localEngine,
    builtinTorrentSearch: true,
    playSourceTorrent: true,
    playSourceStremio: true,
    playSourceNuvio: true,
  );

  /// Web — URL Stremio/Nuvio; hash streams need debrid; no local torrent.
  static const constrained = PlaybackProfile(
    localTorrentEngine: false,
    stremioInfoHash: StremioInfoHashPolicy.debridOnly,
    builtinTorrentSearch: false,
    playSourceTorrent: false,
    playSourceStremio: true,
    playSourceNuvio: true,
  );

  /// Android TV — no local librqbit. HTTP Stremio/Nuvio play on device;
  /// magnets / infoHash play via paired desktop (pair dialog if not).
  static const androidTv = PlaybackProfile(
    localTorrentEngine: false,
    stremioInfoHash: StremioInfoHashPolicy.localEngine,
    builtinTorrentSearch: true,
    playSourceTorrent: true,
    playSourceStremio: true,
    playSourceNuvio: true,
  );

  bool get canPlayInfoHashLocally =>
      localTorrentEngine &&
      stremioInfoHash == StremioInfoHashPolicy.localEngine;
}

/// Compile-time platform playback profile (RFC-010 web uses [constrained]).
abstract final class PlatformPlayback {
  static PlaybackProfile? _override;

  /// Test-only override; reset with [clearOverride].
  static set override(PlaybackProfile? profile) => _override = profile;

  static void clearOverride() => _override = null;

  static PlaybackProfile get capabilities => _override ?? _detect();

  static PlaybackProfile _detect() {
    if (kIsWeb) return PlaybackProfile.constrained;
    if (SettingsService.platformProfile == PlatformProfile.androidTv) {
      return PlaybackProfile.androidTv;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return PlaybackProfile.desktop;
      case TargetPlatform.fuchsia:
        return PlaybackProfile.constrained;
    }
  }

  /// Nav IDs unavailable on this profile (e.g. magnet tab on web).
  static const Set<String> torrentNavIds = {'magnet'};
}
