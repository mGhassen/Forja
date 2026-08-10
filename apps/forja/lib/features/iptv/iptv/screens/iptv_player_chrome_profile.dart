import '../../../../shared/platform/platform_info.dart';

/// IPTV player chrome: Live TV vs Movies/Series (catalog VOD).
///
/// Tracks (Audio / Subs / Episodes) follow **catalog** intent only
/// ([vodPlayback]). Seek chrome can still appear for seekable live via
/// duration heuristic in the UI (`vodSeekChrome || _isVod`).
enum IptvPlayerChromeProfile {
  live,
  vod;

  static IptvPlayerChromeProfile fromVodPlayback(bool vodPlayback) =>
      vodPlayback ? vod : live;

  /// Audio / Subs — Movies & Series only.
  bool get showAudioSubtitles => this == vod;

  /// Episodes — Series catalog only (caller still checks episode list).
  bool get showEpisodes => this == vod;

  /// Prefer scrubber when catalog says VOD (UI ORs duration heuristic).
  bool get vodSeekChrome => this == vod;

  /// Persist Player menu engine to SharedPreferences (Live only).
  bool get persistEnginePref => this == live;

  /// Progress bar: hide only Android TV Exo **live**. VOD Exo keeps scrubber.
  bool showProgressChrome({
    required bool exoBackend,
    required bool isVodHeuristic,
  }) {
    if (vodSeekChrome || isVodHeuristic) return true;
    return !(exoBackend && PlatformInfo.isAndroidTv);
  }
}
