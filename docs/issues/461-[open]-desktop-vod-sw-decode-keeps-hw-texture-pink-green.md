# 461 — Desktop VOD SW decode still used HW texture (pink/green)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** desktop · player · MediaKit  
**Reported:** 2026-10-23 (manual macOS playback — pink/green picture; SW setting unchanged)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

macOS desktop VOD shows inverted / pink+green colors. Player Settings → Video decode → **SW** did not fix it.

## Root cause

Desktop always created `VideoController` with `enableHardwareAcceleration: true` (TextureHW). The Video decode menu only set mpv `hwdec` — **SW** never flipped soft texture (TextureSW). Pink/green matches chroma misuse on the HW texture path.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I461-T01 | SW → `enableHardwareAcceleration: false` + `hwdec=no` on create / PiP restore | ✅ |
| 2 | I461-T02 | Live Video decode switch recreates VideoController when soft-texture boundary flips | ✅ |
| 3 | I461-T03 | If SW soft texture still pink/green: file follow-up for TextureHW/chroma root (media_kit) | ⬜ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I461-A01 | Hot-reload / restart → Settings → Video decode **SW** → colors normal on the failing title | ⬜ |
| 2 | I461-A02 | Log / behavior: SW uses soft texture; HW+/COPY keep TextureHW | ⬜ |

## Links

- Related: `033-[open]-vod-decoder-recovery.md` (hw→software fallback wiring)
- Related: `docs/issues/fixed/359-[fixed]-live-sports-stremio-vt-hold-corrupt-frames.md` (VT chroma-ish live)
