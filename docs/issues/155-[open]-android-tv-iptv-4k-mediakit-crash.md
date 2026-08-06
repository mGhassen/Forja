# 155 — Android TV IPTV MediaKit: 4K live crashes the app

**Status:** open
**Priority:** P1
**Severity:** High
**Area:** Android TV · IPTV · MediaKit · 4K live

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|----|-----|
| 1 | I155-T01 | Never fall back to software decode on ATV MediaKit — soft-reopen on MediaCodec instead | ✅ |
| 2 | I155-T02 | Drop UHD `framedrop=decoder` (keep `framedrop=vo`) | ✅ |
| 3 | I155-T03 | Restore known-good ≤v1.3.80 UHD path: no mid-open `video-sync=audio`; keep `display-resample` for all resolutions | ✅ |
| 4 | I155-T04 | Restore known-good demuxer cache (30 s / 150 MB) — do not shrink below what played 4K before | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|----|-----|
| 1 | I155-A01 | Android TV MediaKit: open a 4K live IPTV channel — app stays alive, picture + audio play | ⬜ |
| 2 | I155-A02 | HD/FHD MediaKit on the same box unchanged (no new black screen / silent audio) | ⬜ |

---

## Summary

On **Android TV**, some **4K** IPTV channels on **MediaKit** force-closed the app. The same channels played on MediaKit before (**≤v1.3.80**, before [issue 138](138-[open]-android-tv-iptv-4k-audio.md) landed in **v1.3.81**).

### Known-good (what worked)

| Knob | ≤v1.3.80 |
|---|---|
| `vo` / `hwdec` | `mediacodec_embed` / `mediacodec` |
| `video-sync` | `display-resample` (**all** resolutions, including 4K) |
| `framedrop` | `vo` |
| demuxer | 30 s / 150 MB |
| post-open UHD retune | **none** |

### Regression (v1.3.81+)

`_tuneAtvMediaKitAfterOpen` (I138) mid-open flipped UHD to `video-sync=audio` + `framedrop=decoder`. That is the first change that only hits 4K after open.

Also: `_forceSoftwareDecode` on a transient MediaCodec fail before first frame (common on slow UHD join) set `hwdec=no` and recreated — software UHD on leanback OOMs/ANRs.

### Fix now

1. ATV never hw→sw — soft reopen, stay on MediaCodec
2. No UHD `video-sync` / `framedrop` retune — same as ≤v1.3.80
3. Demuxer back to 30 s / 150 MB
4. Keep post-open `ao=audiotrack` + unmute + track pick (exit-path silence only; not a sync change)

**Not device-verified yet** — `I155-A01`/`A02` still ⬜. Possible trade-off: some 4K channels that were picture-only under `display-resample` (I138 symptom) may go silent again; crash > silence — fix audio separately if it returns.

## Related

- [138](138-[open]-android-tv-iptv-4k-audio.md) — introduced UHD `video-sync=audio` (partially reverted here)
- [150](150-[open]-atv-iptv-4k-mediakit-stutter.md) — stutter investigation
- [128](128-[open]-android-tv-iptv-mediakit-exit-anr.md) — MediaKit teardown ANR
- [IPTV Xtream](../features/live/iptv-xtream.md) · [Player](../features/playback/player.md)
