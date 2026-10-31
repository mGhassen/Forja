import 'package:forja/l10n/l10n.dart';

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

/// Grace reasons where a forward playhead proves nothing — reopen.
///
/// Hardware decoder death (VideoToolbox / D3D11 / MediaCodec) **or** a
/// poisoned demuxer (`Error decoding audio` / video while AAC/H264
/// bitstream is garbage). The audio clock and PTS still advance on green /
/// macroblocked frames.
bool iptvLiveGraceReasonIsHwDecodeFail(String reason) {
  final lower = reason.toLowerCase();
  return lower.contains('hw decode fail') ||
      lower.contains('hardware decode fail') ||
      iptvLiveGraceReasonIsCorruptBitstream(reason);
}

/// AAC/H264 decode death from corrupt live segments (DISCONTINUITY /
/// truncated TS). Distinct from VT hw fail — caller may goLive immediately
/// instead of waiting out the lavf grace window.
bool iptvLiveGraceReasonIsCorruptBitstream(String reason) {
  final lower = reason.toLowerCase();
  return lower.contains('error decoding audio') ||
      lower.contains('error decoding video') ||
      lower.contains('decode fail:');
}

/// `keep-open=always` pauses at EOF, so position often does not move even
/// while lavf is stitching. [playing] and [playheadRecentlyMoved] are read
/// after an explicit resume.
///
/// [hwDecodeFail]: the audio clock keeps moving while the decoder drops
/// every frame (or feeds garbage), so a forward position proves nothing.
/// Always stop+open.
IptvLiveGraceAction iptvLiveGraceAction({
  required bool playing,
  required Duration position,
  required Duration startPosition,
  required bool playheadRecentlyMoved,
  bool hwDecodeFail = false,
}) {
  if (!playing) return IptvLiveGraceAction.goLive;
  if (hwDecodeFail) return IptvLiveGraceAction.goLive;
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

/// Display text for a live player `_statusBanner`.
///
/// The banner state stays English: recovery code compares it with `==` and
/// `startsWith`. Only what the viewer reads is mapped here; an unknown banner
/// (for example resolver progress text) is shown unchanged.
String iptvLocalizedStatusBanner(AppLocalizations l, String banner) {
  switch (banner) {
    case 'Stream ended':
      return l.playerLiveStreamEnded;
    case 'Reconnecting…':
      return l.playerLiveReconnecting;
    case 'Preparing playback…':
      return l.playerLivePreparingPlayback;
    case 'Refreshing stream…':
      return l.playerLiveRefreshingStream;
    case 'Unlocking source…':
      return l.playerLiveUnlockingSource;
    case 'Stream offline':
      return l.playerLiveStreamOffline;
    case 'Playback failed':
      return l.playerLivePlaybackFailed;
    case 'Switching player…':
      return l.playerLiveSwitchingPlayer;
    case 'Switching to software decode…':
      return l.playerLiveSwitchingSoftwareDecode;
    case 'Buffering…':
      return l.playerLiveBuffering;
  }
  const switching = 'Switching to ';
  const trying = 'Trying ';
  if (banner.startsWith(switching) && banner.endsWith('…')) {
    return l.playerLiveSwitchingTo(
      banner.substring(switching.length, banner.length - 1),
    );
  }
  if (banner.startsWith(trying) && banner.endsWith('…')) {
    return l.playerLiveTrying(
      banner.substring(trying.length, banner.length - 1),
    );
  }
  final offline = RegExp(r'^Stream offline - retrying every (\d+)s…$')
      .firstMatch(banner);
  if (offline != null) {
    return l.playerLiveOfflineRetrying(int.parse(offline.group(1)!));
  }
  final attempt = RegExp(r'^Reconnecting… \(attempt (\d+)/(\d+)\)$')
      .firstMatch(banner);
  if (attempt != null) {
    return l.playerLiveReconnectingAttempt(
      int.parse(attempt.group(1)!),
      int.parse(attempt.group(2)!),
    );
  }
  return banner;
}
