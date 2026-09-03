# 150 — Android TV IPTV MediaKit: 4K live stutters / not fluid

**Status:** open
**Priority:** P2
**Severity:** Medium
**Area:** IPTV / playback (Android TV, MediaKit)

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 6** investigation · **1** ⏭️ · **0 / 4** acceptance |
| **Current slice** | Admin live buffer override shipped (I150-T07) — device smoke still open |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Investigation

| # | ID | Description | Status |
|--:|----|----|-----|
| 1 | I150-T01 | UHD diagnostic snapshot — log `container-fps`, `display-fps`, `estimated-vf-fps`, `avsync`, `frame-drop-count`, `decoder-frame-drop-count`, `video-bitrate`, `demuxer-cache-duration`, `hwdec-current` on a timer while UHD is playing | ✅ |
| 2 | I150-T02 | Capture a stutter session on the box; classify against the decision table below | ⬜ |
| 3 | I150-T03 | A/B `framedrop=decoder` vs `framedrop=vo` on UHD with audio verified (must not regress `I138-A03`) — **`framedrop=decoder` removed in [issue 155](155-[open]-android-tv-iptv-4k-mediakit-crash.md)** (crash path); re-open only if stutter remains with `vo` | ⏭️ |
| 4 | I150-T04 | A/B `video-sync=audio` vs `display-resample` on UHD once audio is known good — **do not re-enable `audio` without crash smoke (`I155-A01`)**; known-good is `display-resample` | ⬜ |
| 5 | I150-T05 | Bitrate-aware cache sizing if `demuxer-max-bytes` is the binding limit at 4K | ✅ |
| 6 | I150-T06 | ATV MediaKit IPTV: Settings **IPTV match display refresh** (default **on**; admin toggle to disable); when on, read `container-fps` and call display mode match; clear on exit / hot-swap; keep `framedrop=vo` | ✅ |
| 7 | I150-T07 | ATV MediaKit IPTV: Settings **IPTV live buffer** (admin) — Auto by resolution or force 15 / 20 / 30 s demuxer cushion with matching `demuxer-max-bytes`; apply on next open (cold + height retune) | ✅ |

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
non-fluid. HD/FHD on the same box and the same portal are smooth. A common
report is **stats FPS = 50** while motion feels slower — that is **50 fps
content on a fixed 60 Hz panel** (uneven cadence), not a lying counter.

## Fix shipped — display mode match (I150-T06)

MediaKit paints via `mediacodec_embed` into Flutter — it never got the Exo-only display frame-rate window switch. After open, IPTV MediaKit can read `container-fps` and ask the TV for a refresh that divides cleanly (e.g. 50 Hz for a 50 fps channel). Clears when leaving the player or hot-swapping engines. Keeps `video-sync=display-resample` + `framedrop=vo` (no I138 `framedrop=decoder`).

**Default on** — Settings → Playback → **IPTV match display refresh** (Android TV, admin-only toggle to disable). Existing installs get match unless disabled.

Requires the set to expose a matching mode at the current resolution; otherwise no-op (log: display frame-rate match failed).

## Fix shipped — height/bitrate live cache tiers (I150-T05)

ATV MediaKit **live** uses a 32 MiB Player buffer (demuxer owns readahead). After decode height is known: HD 48 MiB / 15 s, FHD **and UHD** 96 MiB / 20 s ([issue 155](155-[open]-android-tv-iptv-4k-mediakit-crash.md) T05 — 150 MiB UHD + 4K MediaCodec OOMed physical boxes). Bitrate may bump HD→FHD only. VOD never inherits live fat profile ([163](163-[open]-android-tv-iptv-vod-live-profile.md)). Cold open uses the FHD-sized window until height probes. Admin **30 seconds** still forces 150 MiB.

## Fix shipped — admin live buffer override (I150-T07)

Settings → Playback → **IPTV live buffer** (Android TV, admin-only): **Auto (by resolution)** keeps the height/bitrate tiers from T05 (UHD now shares FHD RAM — [issue 155](155-[open]-android-tv-iptv-4k-mediakit-crash.md)); **15 / 20 / 30 seconds** forces `cache-secs` + matching `demuxer-readahead-secs` / `demuxer-max-bytes` (30 s = 150 MB). Applied on cold open and after height probe. Use for underrun vs RAM A/B — does not fix cadence judder (T06) or Exo TextureView chop ([108](108-[open]-android-tv-iptv-exo-choppy-fps.md)).

## Suspected cause — the UHD path traded smoothness for audio (historical)

`_tuneAtvMediaKitAfterOpen` **used to** change sync on UHD. [Issue 155](155-[open]-android-tv-iptv-4k-mediakit-crash.md) restored known-good ≤v1.3.80: **no** mid-open UHD retune — HD and UHD both stay on `display-resample` + `framedrop=vo`.

```dart
// tunables (all resolutions, including UHD):
await p.setProperty('video-sync', 'display-resample');
await p.setProperty('framedrop', 'vo');
```

| Setting | HD / UHD (now) | Effect |
|---|---|----|
| `video-sync` | `display-resample` | Matches display refresh (known-good 4K path) |
| `framedrop` | `vo` | Clean VO drops |

I138’s `video-sync=audio` + `framedrop=decoder` stay gone. Cadence judder is
handled by display mode match (`I150-T06`), not by reintroducing those knobs.

## Second candidate — byte cap binds before the seconds target at 4K

ATV MediaKit uses the known-good `cache-secs=30` / `demuxer-max-bytes=150000000` again ([issue 155](155-[open]-android-tv-iptv-4k-mediakit-crash.md) T04).

| Bitrate | 30 s wants | Hits 150 MB cap? |
|---|---|---|
| HD ~5 Mbps | ~19 MB | No |
| 4K ~25 Mbps | ~94 MB | Close |
| 4K ~40 Mbps | ~150 MB | **Yes** |

When mpv reaches `demuxer-max-bytes` it stops reading the socket until the cache
drains. On a live feed that presents as a stalled reader to the server, and some
portals throttle or drop at that point. Only 4K reaches the cap, which matches
the HD/UHD split. Still tracked as `I150-T05` if stutter remains after mode match.

## Decision table for I150-T02

Read the diagnostic line during a stutter and classify:

| Observation | Conclusion | Next |
|----|----|---|
| `decoder-frame-drop-count` climbing, `frame-drop-count` flat | pre-decode drops (legacy `framedrop=decoder`) | `I150-T03` ⏭️ — removed in 155 |
| Both drop counts flat, `container-fps` ≠ `display-fps`, `avsync` small | Cadence judder — expect `I150-T06` display match; if still stuck on 60 Hz, TV has no 50 Hz mode | `I150-T04` only if mode match impossible |
| `frame-drop-count` climbing, `avsync` drifting | Decoder cannot keep up — check `hwdec-current` is `mediacodec`, not a software fallback | new task |
| `demuxer-cache-duration` sawtoothing well under target secs | Byte cap binding — feed is being throttled | `I150-T05` |

## Related

- [issue 138](138-[open]-android-tv-iptv-4k-audio.md) — origin of the UHD branch; any change here must keep `I138-A03`
- [issue 155](155-[open]-android-tv-iptv-4k-mediakit-crash.md) — 4K MediaKit process death; removed `framedrop=decoder` + ATV demuxer cap
- [issue 108](108-[open]-android-tv-iptv-exo-choppy-fps.md) — Exo-side choppy FPS on the same surface
- [RFC-052](../rfc/canceled/052-[canceled]-iptv-progress-aware-recovery.md) — canceled; cache sizing notes remain historical for `I150-T05`
