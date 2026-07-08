# RFC-005: Casting (AirPlay + Chromecast)

**Status:** stub  
**Area:** `apps/forja/lib/shared/casting/src/casting_service.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 1** components · **0 / 4** acceptance |
| **Current slice** | Platform channels + player Cast button — not started |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R05-C01 | CastingService (`casting_service.dart`) | ⬜ |

---


## Summary

Cast resolved VOD/IPTV streams to external devices. Native platform channels; independent of media_kit widget.


## Stub

`apps/forja/lib/shared/casting/src/casting_service.dart`

```dart
enum CastTarget { airplay, chromecast }

class CastingService {
  bool get isAirPlayAvailable;      // macOS, iOS
  bool get isChromecastAvailable;   // Android, iOS
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
| Windows/Linux | N/A | DLNA (v2+, optional) |

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

