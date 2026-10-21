# 441 — Live Sports / IPTV: AAC decode storm holds on green frame

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** Live Sports · IPTV · MediaKit · macOS  

**Related:** [417](417-[fixed]-live-sports-desktop-hw-decode-grace-hold.md) · [359](359-[fixed]-live-sports-stremio-vt-hold-corrupt-frames.md) · [362](362-[fixed]-iptv-mediakit-log-eof-grace-storm.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** tasks · **0 / 2** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I441-T01 | Treat `Error decoding audio` / video as clock-unreliable (same as VT hw fail) in grace helper | ✅ |
| 2 | I441-T02 | Live Sports + IPTV MediaKit: corrupt decode → immediate goLive (not grace hold on playhead) | ✅ |
| 3 | I441-T03 | Decode-storm goLive throttle must not paint “Stream ended” | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I441-A01 | BZH / HLS live on Mac: after AAC scalefactor / H264 corrupt spam, log shows `goLive attempt … (decode fail:…)` and picture returns without manual Reload | ⬜ |
| 2 | I441-A02 | Decode storm during reconnect does not flip banner to “Stream ended” | ⬜ |

---

## Summary

**Symptom:** Live Sports (BZH) mid-match → flood of `Error decoding audio`, ffmpeg AAC/H264 “out of range” / “no frame”, then solid green texture. Log: `live glitch recovered (49s → 56s) — no reopen` while HLS still fetched new `.ts` segments.

**Root:** After HLS `EXT-X-DISCONTINUITY` / truncated TS, lavf feeds garbage into AAC + H264. MediaKit still advances the playhead. Grace recovery treated forward position as healthy and skipped reopen (same failure mode as issue 417 for VT, but the error string was `Error decoding audio`, not `hw decode fail`).

**Root fix:** corrupt bitstream reasons force goLive; Live Sports / IPTV error path reopens immediately on audio/video decode death; throttle during a decode storm stays quiet (no false “Stream ended”).
