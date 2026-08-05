# 150 — Android TV IPTV MediaKit: 4K live stutters / not fluid

**Status:** open
**Priority:** P2
**Severity:** Medium
**Area:** IPTV / playback (Android TV, MediaKit)

## Status at a glance

| | |
|--|--|
| **Progress** | **1 / 5** investigation · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Investigation

| # | ID | Description | Status |
|--:|----|----|-----|
| 1 | I150-T01 | UHD diagnostic snapshot — log `container-fps`, `display-fps`, `estimated-vf-fps`, `avsync`, `frame-drop-count`, `decoder-frame-drop-count`, `video-bitrate`, `demuxer-cache-duration`, `hwdec-current` on a timer while UHD is playing | ✅ |
| 2 | I150-T02 | Capture a stutter session on the box; classify against the decision table below | ⬜ |
| 3 | I150-T03 | A/B `framedrop=decoder` vs `framedrop=vo` on UHD with audio verified (must not regress `I138-A03`) | ⬜ |
| 4 | I150-T04 | A/B `video-sync=audio` vs `display-resample` on UHD once audio is known good | ⬜ |
| 5 | I150-T05 | Bitrate-aware cache sizing if `demuxer-max-bytes` is the binding limit at 4K | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|----|-----|
| 1 | I150-A01 | Android TV MediaKit: 4K live channel plays with fluid motion — no periodic judder | ⬜ |
| 2 | I150-A02 | 4K audio still present and not starved (no `I138` regression) | ⬜ |
| 3 | I150-A03 | HD/FHD MediaKit smoothness unchanged | ⬜ |
| 4 | I150-A04 | Diagnostic logging is debug-only — no release log spam | ⬜ |

---

## Summary

4K live channels on Android TV with the MediaKit engine stutter and look
non-fluid. HD/FHD on the same box and the same portal are smooth.

## Suspected cause — the UHD path trades smoothness for audio

`_tuneAtvMediaKitAfterOpen` changes two settings when it detects UHD, and HD
never takes either branch:

```dart
final isUhd = h >= 2160 || w >= 3840;
if (isUhd) {
  await p.setProperty('video-sync', 'audio');
  await p.setProperty('framedrop', 'decoder');
}
```

| Setting | HD | UHD | Effect on motion |
|---|---|---|----|
| `video-sync` | `display-resample` | `audio` | Frames no longer land on display refreshes. 50 fps content on a 60 Hz output judders with a repeating 5-frame cadence. |
| `framedrop` | `vo` | `decoder` | `decoder` drops frames **before** decode; mpv documents this as the unsafe mode. Produces visibly jerky output rather than clean VO drops. |

Both came from [issue 138](138-[open]-android-tv-iptv-4k-audio.md) (4K played
picture-only, no sound). Note that `I138-T02` specifies **only** the
`video-sync=audio` change — `framedrop=decoder` was added beyond that task, so
it is the first candidate to remove, and doing so may not touch the audio fix at
all.

## Second candidate — byte cap binds before the seconds target at 4K

`cache-secs=30` with `demuxer-max-bytes=150000000`:

| Bitrate | 30 s wants | Hits 150 MB cap? |
|---|---|---|
| HD ~5 Mbps | ~19 MB | No |
| 4K ~25 Mbps | ~94 MB | Close |
| 4K ~40 Mbps | ~150 MB | **Yes** |

When mpv reaches `demuxer-max-bytes` it stops reading the socket until the cache
drains. On a live feed that presents as a stalled reader to the server, and some
portals throttle or drop at that point. Only 4K reaches the cap, which matches
the HD/UHD split. Also relevant as memory pressure — 150 MB of demuxer plus 4K
MediaCodec surfaces is heavy on a TV box.

## Decision table for I150-T02

Read the diagnostic line during a stutter and classify:

| Observation | Conclusion | Next |
|----|----|---|
| `decoder-frame-drop-count` climbing, `frame-drop-count` flat | `framedrop=decoder` is dropping frames pre-decode | `I150-T03` |
| Both drop counts flat, `container-fps` ≠ `display-fps`, `avsync` small | Cadence judder from `video-sync=audio` | `I150-T04` |
| `frame-drop-count` climbing, `avsync` drifting | Decoder cannot keep up — check `hwdec-current` is `mediacodec`, not a software fallback | new task |
| `demuxer-cache-duration` sawtoothing well under 30 s | Byte cap binding — feed is being throttled | `I150-T05` |

## Related

- [issue 138](138-[open]-android-tv-iptv-4k-audio.md) — origin of the UHD branch; any change here must keep `I138-A03`
- [issue 108](108-[open]-atv-iptv-exo-choppy-fps.md) — Exo-side choppy FPS on the same surface
- [RFC-052](../rfc/052-[partial]-iptv-progress-aware-recovery.md) — cache sizing interacts with `I150-T05`
