/// What a live MediaKit hardware-decode log line should do.
enum IptvHwDecodeFailAction {
  /// One-shot during a known seek or reconnect. Drop the line.
  ignore,

  /// Cold open. Leave the decoder alone.
  holdCold,

  /// Desktop, past cold open. Reopen once with software decode.
  softwareDecode,

  /// Android / TV, past cold open. Grace, then stop+open on hardware.
  grace,
}

/// [desktopSoftwareFallback] is Mac, Windows, and Linux only.
/// Android stays on hardware decode.
IptvHwDecodeFailAction iptvLiveHwDecodeFailAction({
  required bool insideIgnoreWindow,
  required bool pastColdOpen,
  required bool desktopSoftwareFallback,
}) {
  if (insideIgnoreWindow) return IptvHwDecodeFailAction.ignore;
  if (!pastColdOpen) return IptvHwDecodeFailAction.holdCold;
  if (desktopSoftwareFallback) return IptvHwDecodeFailAction.softwareDecode;
  return IptvHwDecodeFailAction.grace;
}

/// What to do when a live MediaKit glitch's grace window ends.
enum IptvLiveGraceAction {
  /// Playback moved forward. Leave the demuxer alone.
  hold,

  /// Playhead jumped backward into the provider's startup archive.
  /// Skip buffered media. Do not stop+open again.
  snapArchive,

  /// Still frozen. Stop and open the same URL.
  goLive,
}

/// `keep-open=always` pauses at EOF, so position often does not move even
/// while lavf is stitching. [playing] and [playheadRecentlyMoved] are read
/// after an explicit resume.
IptvLiveGraceAction iptvLiveGraceAction({
  required bool playing,
  required Duration position,
  required Duration startPosition,
  required bool playheadRecentlyMoved,
}) {
  if (!playing) return IptvLiveGraceAction.goLive;
  if (position > startPosition) return IptvLiveGraceAction.hold;
  if (playheadRecentlyMoved &&
      position + const Duration(seconds: 2) < startPosition) {
    return IptvLiveGraceAction.snapArchive;
  }
  return IptvLiveGraceAction.goLive;
}

/// Seconds of demuxer cushion to skip after a live reopen.
///
/// A fresh Xtream `.ts` GET starts inside the panel archive (often ~10–20s).
/// Seeking by the buffered amount lands on the newest packet. Under 2s is
/// normal jitter. Over the live cache window is a PTS spike — do not seek.
double iptvReconnectArchiveSkipSeconds(double cacheAheadSecs) {
  const minSkip = 2.0;
  const maxSkip = 30.0;
  if (cacheAheadSecs < minSkip || cacheAheadSecs > maxSkip) return 0;
  return cacheAheadSecs;
}
