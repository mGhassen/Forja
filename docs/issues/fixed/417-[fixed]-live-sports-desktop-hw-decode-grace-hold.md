# 417 — Live Sports desktop: VT grace holds on a dead decoder, Windows runs hw decode

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** Live Sports · MediaKit · macOS VideoToolbox · Windows D3D11  
**Reported:** 2026-10-07

**Related:** [295](295-[fixed]-mediakit-live-vt-hold-no-golive.md) · [092](../092-[open]-windows-iptv-stream-freeze-after-20s.md) · [359](359-[fixed]-live-sports-stremio-vt-hold-corrupt-frames.md) · [361](361-[fixed]-live-sports-mediakit-soft-reopen-storm.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2/2** tasks · **0 / 2** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I417-T01 | `iptvLiveGraceAction`: hw-decode grace always ends in goLive (restores I295-T03) — Live Sports and IPTV callers pass the reason | ✅ |
| 2 | I417-T02 | Live Sports `_useSoftwareDecode` honors `_windowsSoftwareDecode` on the live path (I092 intent) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I417-A01 | macOS Streamic Live Sports: after `hw decode fail (live VT)` the log shows `live glitch unrecovered — goLive` at the end of the grace, picture returns without manual Reload | ⬜ |
| 2 | I417-A02 | Windows Streamic Live Sports: app stays responsive on open, stream plays 2+ minutes without sticking on the last frame | ⬜ |

---

## Summary

**Symptom:** Streamic live stream on Mac and Windows stutters and stops a few seconds after open. On Windows the whole app freezes first.

**Root (two layers):**

1. VideoToolbox fails past cold open. The engine schedules a 6s grace and an 8s ignore window. The grace end checks only that the position moved. The audio clock moves while the decoder drops every frame, so the grace logs "recovered — no reopen" and the loop repeats. Issue 295 task 3 required a hw-decode grace to always goLive; that rule was never in the shared grace helper.
2. Live Sports `_useSoftwareDecode` returned early on the live path with `_desktopLiveHwDecodeFallback && _softwareDecodeForced` (always false), so the Windows software-decode flag from issue 092 never applied. Windows ran `hwdec=auto-safe` + `vd-lavc-dr=yes` on live HLS, the setup issue 092 recorded as sticking the D3D11 surface.

**Root fix:** the grace helper takes `hwDecodeFail` (derived from the reason) and returns goLive regardless of position. The Live Sports decode getter checks the Windows flag before the desktop fallback gate. Mac and Linux stay on hardware decode.
