Casting for the player Cast button.

- AirPlay (macOS, iOS): `ForjaAirPlayChannel.swift` in each Runner. A muted AVPlayer follows the stream, the system route picker opens, and `CastHandoff` pauses or resumes the local player as external playback starts or ends. Subtitles: an in-stream track is selected on the AirPlay item; an external SRT/WebVTT is served as a WebVTT rendition by `ForjaAirPlaySubtitleRelay.swift` (HLS sources only).
- Chromecast: not wired yet.
