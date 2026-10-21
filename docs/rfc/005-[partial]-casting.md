# RFC-005: Casting (AirPlay + Chromecast)

**Status:** partial  
**Area:** `apps/forja/lib/shared/casting/src/casting_service.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 9** components · **0 / 4** acceptance |
| **Current slice** | AirPlay online + offline + seek sync + chrome + next-episode handoff + HLS in-stream subs + idle wake hold (macOS + iOS); Chromecast not started |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R05-C01 | CastingService (`casting_service.dart`) | 🔄 |
| 2 | R05-C02 | AirPlay hand-off: `ForjaAirPlayChannel.swift` (iOS + macOS) — AVPlayer + AVRoutePickerView, local player pauses on external playback and resumes at the receiver's position | ✅ |
| 3 | R05-C03 | AirPlay subtitles: in-stream track selected on the receiver; external SRT/VTT added as a WebVTT rendition by `ForjaAirPlaySubtitleRelay.swift` (tokenized LAN HLS wrapper, HLS sources only) | ✅ |
| 4 | R05-C04 | AirPlay offline: `ForjaAirPlayLocalFileRelay.swift` serves `file://` downloads over LAN HTTP with Range so the TV can fetch them ([422](../issues/fixed/422-[fixed]-airplay-offline-file-cannot-open.md)) | ✅ |
| 5 | R05-C05 | AirPlay playhead + transport sync: periodic `position`, `seek`, `play`/`pause`, rate mirror; Forja seek bar and play/pause control the receiver ([451](../issues/fixed/451-[fixed]-airplay-seek-bar-not-synced.md)) | ✅ |
| 6 | R05-C06 | AirPlay casting chrome: sticky "Playing on AirPlay" + active cast button while `airPlayActive` ([452](../issues/fixed/452-[fixed]-airplay-no-casting-indicator.md)) | ✅ |
| 7 | R05-C07 | AirPlay survives next episode: retain across player replace + native `replace` URL ([453](../issues/fixed/453-[fixed]-airplay-drops-on-next-episode.md)) | ✅ |
| 8 | R05-C08 | AirPlay HLS in-stream subs: merge subtitle media playlist to WebVTT for the LAN relay ([455](../issues/fixed/455-[fixed]-airplay-hls-instream-subtitles.md)) | ✅ |
| 9 | R05-C09 | AirPlay keeps the host awake while casting — macOS `NoIdleSleep` + session `WakelockPlus` ([456](../issues/fixed/456-[fixed]-airplay-mac-idle-stops-cast.md)) | ✅ |

---


## Summary

Cast resolved VOD/IPTV streams to external devices. Native platform channels; independent of media_kit widget.


## Stub

`apps/forja/lib/shared/casting/src/casting_service.dart`

```dart
enum CastTarget { airplay, chromecast }

class CastingService {
  bool get isAirPlayAvailable;      // macOS, iOS
  bool get isChromecastAvailable;   // Android, iOS, Windows
  Future<bool> castUrl({ url, target, headers, title });
  Future<void> stopCasting();
}
```

## Platform matrix

| Platform | AirPlay | Chromecast |
|----------|---------|------------|
| macOS | AVRoutePickerView | N/A |
| iOS | AVPlayer route | Google Cast SDK |
| Android | N/A | Google Cast SDK |
| Windows | N/A | Cast button (stub; native TBD) |
| Linux | N/A | DLNA (v2+, optional) |

## Architecture

```
PlayerScreen → CastingService → AirPlay route
                              → Cast SDK
                              → LocalServerService (Referer proxy) → Cast
```

- **VOD:** cast resolved HLS/MP4 URL; proxy when CDN needs Referer
- **IPTV live:** transmux to HLS via local proxy when needed; best-effort

## Implementation steps (v1.1)

1. macOS/iOS: MethodChannel wrapping AVRoutePickerView / route picker
2. Android/iOS: integrate `google_cast` or platform Cast SDK
3. Player overlay: Cast button when `isAirPlayAvailable || isChromecastAvailable`
4. Pass active stream URL + headers from player state

