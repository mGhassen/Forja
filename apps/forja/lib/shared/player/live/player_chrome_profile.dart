/// IPTV player chrome: Live TV vs Movies/Series (catalog VOD).
///
/// Tracks (Audio / Subs / Episodes) follow **catalog** intent only
/// ([vodPlayback]). Seek chrome can still appear for seekable live via
/// duration heuristic in the UI (`vodSeekChrome || _isVod`).
enum LivePlayerChromeProfile {
  live,
  vod;

  static LivePlayerChromeProfile fromVodPlayback(bool vodPlayback) =>
      vodPlayback ? vod : live;

  /// Audio / Subs — Movies & Series only.
  bool get showAudioSubtitles => this == vod;

  /// Episodes — Series catalog only (caller still checks episode list).
  bool get showEpisodes => this == vod;

  /// Prefer scrubber when catalog says VOD (UI ORs duration heuristic).
  bool get vodSeekChrome => this == vod;

  /// Persist Player menu engine to this surface's KV (vod vs iptv).
  bool get persistEnginePref => true;

  /// Middle progress row while chrome is up (VOD scrubber, waiting track, or
  /// live EPG/LIVE status). Always on — ATV Exo live keeps a focusable slot so
  /// transport ↑ lands on progress, never jumps over it to Back (issue 130).
  ///
  /// [exoBackend] / [isVodHeuristic] kept for call-site stability.
  bool showProgressChrome({
    required bool exoBackend,
    required bool isVodHeuristic,
  }) => true;
}
