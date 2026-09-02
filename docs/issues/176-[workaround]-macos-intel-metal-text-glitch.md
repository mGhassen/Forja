# 176 — macOS Intel: glitched subtitles, cards, and text (Metal)

**Status:** workaround  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/macos/Runner/` · Flutter Metal (Skia)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** workaround · **0 / 1** root · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I176-T01 | Info.plist `FLTEnableImpeller=false` (keep Skia; do not opt into Impeller) | ✅ |
| 2 | I176-T02 | Info.plist `FLTDisablePartialRepaint=true` (full-frame Metal present) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I176-A01 | Intel Mac: play with subtitles + browse Home/details cards — no jagged spikes, no static bar, no garbled labels | ⬜ |

---

## Summary

On **macOS Intel (x86_64)**, player subtitles / bottom chrome and sometimes catalog cards and labels show GPU garbage: jagged white spikes and a static band where text is drawn. Apple Silicon is fine.

**Root (upstream, still open):** Flutter’s Metal backend on Intel GPUs (Iris / UHD). Dirty-rect (`partial repaint`) presents leave uninitialized / stale glyph-atlas tiles. Same class of failure as Android TV Impeller-off ([114](114-[open]-android-tv-movie-mediakit-audio-only.md)), different surface.

This Flutter macOS embed already **defaults Impeller off** (`settings.enable_impeller = false`; `FLTEnableImpeller` only *adds* `--enable-impeller=true`). T01 is an explicit opt-out so we never ask the embedder to turn Impeller on. T02 is the symptom fix on the Skia Metal path macOS actually runs — Intel dirty-rect presents leave glyph/chrome garbage. Keys live in the shared macOS Info.plist (split DMGs share this file; Apple Silicon already had Impeller off, and full-frame present is cheap next to a video texture).

## Workaround (shipped)

[`Info.plist`](../../apps/forja/macos/Runner/Info.plist):

- `FLTEnableImpeller=false`
- `FLTDisablePartialRepaint=true`

Not a root fix of Flutter/Skia Metal on Intel. Drop `FLTDisablePartialRepaint` when upstream presents Intel dirty rects without garbage. Keep `FLTEnableImpeller=false` until Impeller on Intel is actually good.

Same atlas-garbage class on Android TV Skia: [215](215-[open]-android-tv-skia-glyph-atlas-glitch.md) (Impeller OpenGLES).

## Root fix (open)

Flutter engine Metal present on Intel (partial damage / glyph atlas). Track upstream; do not patch Skia in-tree.

## Verify

1. Intel Mac DMG: Info.plist has both keys
2. Play a title with subtitles — chrome and cues stay sharp
3. Scroll Home / details — card titles do not tear
4. Apple Silicon: no new glitches (Impeller was already off)
