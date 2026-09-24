# 359 — Live Sports / Stremio holds on VT fail with corrupt frames

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** Live Sports · Stremio · MediaKit · macOS VideoToolbox

**Related:** [295](295-[fixed]-mediakit-live-vt-hold-no-golive.md) · [321](321-[fixed]-live-sports-stremio-rfc113-cushion-stutter.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** tasks · **0 / 2** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I359-T01 | Live Sports mpv VT log: past cold open → soft-reopen keep HW (not forever healthy hold) | ✅ |
| 2 | I359-T02 | `_forceSoftwareDecode` Live Sports path: same soft-reopen (never TextureSW) | ✅ |
| 3 | I359-T03 | `_triggerRecovery` bypass healthy-hold for `hw decode fail (live VT)` (playhead ticks on garbage) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I359-A01 | macOS Stremio Live Sports: after `hardware accelerator failed` / `vt decoder cb` past cold open, log shows soft reopen keep HW and picture recovers without manual Reload | ⬜ |
| 2 | I359-A02 | Cold-open one-shot VT after live-edge `drop-buffers` still ignored (no reopen thrash in first 8s) | ⬜ |

---

## Summary

Live Sports player (issue 321 v1.5.36 stack) **held** on VideoToolbox fails while demux/playhead kept advancing — `_streamWorking` stayed true, recovery skipped, UI showed macroblocked / chroma-smeared frames. Logs: `skip recovery (hw decode fail (live hold)) — working` then endless `ignoring transient hw fail`, then `Error decoding audio` also skipped.

Issue 295 already required reconnect on VT black-frame for Stremio; issue 321 restored indefinite VT hold and regressed that path for sports. TextureSW remains wrong for Stremio HLS (Brightcove black).

**Root fix:** past cold open (8s), Live Sports VT fail soft-reopens the same URL with hardware decode; healthy-hold does not apply to that recovery reason.
