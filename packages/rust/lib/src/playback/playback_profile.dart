import 'package:flutter/foundation.dart';

/// How Stremio `infoHash` streams are handled on this platform.
enum StremioInfoHashPolicy {
  /// Local librqbit engine or debrid.
  localEngine,

  /// Debrid only — show streams but reject play without debrid.
  debridOnly,

  /// Routed to paired desktop LAN server (RFC-022).
  desktopServes,

  /// Hide hash-based streams in the UI (TV / web without debrid).
  hidden,
}

/// Platform playback capabilities (Stremio desktop vs constrained/TV model).
class PlaybackProfile {
  final bool localTorrentEngine;
  final StremioInfoHashPolicy stremioInfoHash;
  final bool stremioUrl;
  final bool builtinTorrentSearch;

  /// When true, mobile/constrained clients prefer desktop LAN for torrent/proxy paths.
  final bool preferDesktopServer;

  const PlaybackProfile({
    required this.localTorrentEngine,
    required this.stremioInfoHash,
    this.stremioUrl = true,
    required this.builtinTorrentSearch,
    this.preferDesktopServer = false,
  });

  /// Desktop / Android / iOS — full torrent engine + hash playback.
  static const desktop = PlaybackProfile(
    localTorrentEngine: true,
    stremioInfoHash: StremioInfoHashPolicy.localEngine,
    builtinTorrentSearch: true,
    preferDesktopServer: false,
  );

  /// Phone / tablet — can run engine locally but prefer desktop for heavy paths.
  static const mobile = PlaybackProfile(
    localTorrentEngine: true,
    stremioInfoHash: StremioInfoHashPolicy.localEngine,
    builtinTorrentSearch: true,
    preferDesktopServer: true,
  );

  /// Web, future TV — URL-only; hash streams need debrid, desktop, or are hidden.
  static const constrained = PlaybackProfile(
    localTorrentEngine: false,
    stremioInfoHash: StremioInfoHashPolicy.desktopServes,
    builtinTorrentSearch: false,
    preferDesktopServer: true,
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
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return PlaybackProfile.mobile;
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
