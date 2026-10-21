Casting for the player Cast button.

- AirPlay (macOS, iOS): `ForjaAirPlayChannel.swift` in each Runner. A muted AVPlayer follows the stream, the system route picker opens, and `CastHandoff` pauses or resumes the local player as external playback starts or ends. Subtitles: a demuxed in-stream track is selected on the AirPlay item; HLS in-stream renditions (and online SRT/WebVTT) are merged to WebVTT and served as a rendition by `ForjaAirPlaySubtitleRelay.swift` (HLS sources only).
- Chromecast: not wired yet.
