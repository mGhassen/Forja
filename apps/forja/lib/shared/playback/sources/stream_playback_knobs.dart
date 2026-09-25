import 'package:flutter/foundation.dart';

/// How the player probes a stream before open. Packs set this on the stream row.
enum StreamProbeMode {
  /// GET playlist 200 + `#EXTM3U`.
  masterOnly,

  /// Sample media segments for PNG ads vs PNG-wrapped TS.
  segmentPoisonSample,

  /// HEAD / Range GET.
  headOrRange,

  /// Trust extract; open and let the player fail over.
  skip,
}

/// PNG-shell unwrap policy. Packs set this on the stream row.
enum PngStripMode {
  /// Sample a media segment; strip only when bytes wrap MPEG-TS.
  auto,

  /// Always route HLS through `/hls-proxy?strip=png`.
  force,

  /// Never strip.
  never,
}

/// Probe mode from a pack stream field. Empty / unknown → null (URL heuristic).
StreamProbeMode? streamProbeModeFrom(String? raw) {
  final key = raw?.trim().toLowerCase() ?? '';
  if (key.isEmpty) return null;
  return switch (key) {
    'segmentpoisonsample' || 'segment_poison_sample' =>
      StreamProbeMode.segmentPoisonSample,
    'headorrange' || 'head_or_range' => StreamProbeMode.headOrRange,
    'skip' => StreamProbeMode.skip,
    'masteronly' || 'master_only' => StreamProbeMode.masterOnly,
    _ => null,
  };
}

/// PNG-strip mode from a pack stream field. Empty / unknown → [never].
PngStripMode pngStripModeFrom(String? raw) {
  return switch (raw?.trim().toLowerCase() ?? '') {
    'auto' => PngStripMode.auto,
    'force' => PngStripMode.force,
    _ => PngStripMode.never,
  };
}

/// Optional per-stream playback knobs. The host does not key these by plugin id.
@immutable
class StreamPlaybackKnobs {
  const StreamPlaybackKnobs({this.probe, this.pngStrip = PngStripMode.never});

  final StreamProbeMode? probe;
  final PngStripMode pngStrip;

  factory StreamPlaybackKnobs.fromFields({String? probe, String? pngStrip}) {
    return StreamPlaybackKnobs(
      probe: streamProbeModeFrom(probe),
      pngStrip: pngStripModeFrom(pngStrip),
    );
  }
}
