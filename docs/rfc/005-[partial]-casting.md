# RFC-005: Casting (AirPlay + Chromecast)

**Status:** partial  
**Area:** `apps/forja/lib/shared/casting/src/casting_service.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 3** components · **0 / 4** acceptance |
| **Current slice** | AirPlay done (macOS + iOS); Chromecast not started |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R05-C01 | CastingService (`casting_service.dart`) | 🔄 |
| 2 | R05-C02 | AirPlay hand-off: `ForjaAirPlayChannel.swift` (iOS + macOS) — AVPlayer + AVRoutePickerView, local player pauses on external playback and resumes at the receiver's position | ✅ |
| 3 | R05-C03 | AirPlay subtitles: in-stream track selected on the receiver; external SRT/VTT added as a WebVTT rendition by `ForjaAirPlaySubtitleRelay.swift` (tokenized LAN HLS wrapper, HLS sources only) | ✅ |

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

