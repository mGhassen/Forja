import 'package:rust/rust.dart';

/// Where the in-player **Player** menu is shown — gates which engines can
/// actually decode the current stream (not just which are installed).
enum BuiltInPlayerMenuSurface {
  /// Home / Search / Anime / Drama / etc. ([PlayerScreen]).
  catalogVod,

  /// IPTV live channels ([IptvPtPlayerScreen] with `vodPlayback: false`).
  iptvLive,

  /// IPTV Movies / Series ([IptvPtPlayerScreen] with `vodPlayback: true`).
  iptvVod,
}

/// Why [engine] should stay visible but not selectable for this stream.
///
/// `null` = OK to pick. Never hide engines ([no-hide-as-fix]); grey + reason.
String? builtInPlayerEngineUnsuitableReason(
  BuiltInPlayerEngine engine, {
  required BuiltInPlayerMenuSurface surface,
  required String streamUrl,
  bool torrentLocalhost = false,
  bool needsWidevine = false,
  bool separateAudioUrl = false,
}) {
  final hls = _looksLikeHls(streamUrl);

  switch (engine) {
    case BuiltInPlayerEngine.mediaKit:
      if (needsWidevine) return 'DRM needs ExoPlayer';
      return null;

    case BuiltInPlayerEngine.exoPlayer:
      if (torrentLocalhost) return 'Torrent streams need MediaKit';
      if (separateAudioUrl) return 'Separate audio needs MediaKit';
      return null;

    case BuiltInPlayerEngine.avPlayer:
    case BuiltInPlayerEngine.vlc:
      switch (surface) {
        case BuiltInPlayerMenuSurface.catalogVod:
          return 'Movies & series use MediaKit';
        case BuiltInPlayerMenuSurface.iptvLive:
        case BuiltInPlayerMenuSurface.iptvVod:
          if (!hls) return 'MPEG-TS needs MediaKit';
          return null;
      }
  }
}

bool _looksLikeHls(String url) {
  final lower = url.trim().toLowerCase();
  if (lower.isEmpty) return false;
  return lower.contains('.m3u8');
}
