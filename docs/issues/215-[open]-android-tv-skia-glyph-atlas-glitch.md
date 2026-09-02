# 215 — Android TV: garbled text and icons (Skia glyph atlas)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Flutter Impeller / Skia · `ForjaApplication` / `MainActivity`  
**Reported:** 2026-09-02 (physical leanback — details synopsis + action icons as blue/purple noise)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I215-T01 | `TvFlutterShellArgs` — Impeller on + `--impeller-backend=opengles` for leanback | ✅ |
| 2 | I215-T02 | `ForjaApplication` + `MainActivity` use those args (stop `--enable-impeller=false`) | ✅ |
| 3 | I215-T03 | `atv-run.sh` / manifest comments / player feature doc match Impeller OpenGLES | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I215-A01 | Physical ATV: Home + movie details — synopsis, meta, and action icons stay sharp (no blue/purple glyph garbage) after browse + open details | ⬜ |
| 2 | I215-A02 | Physical ATV: MediaKit movie/IPTV still shows picture (not audio-only) with Impeller OpenGLES + `mediacodec_embed` | ⬜ |

---

## Summary

Physical Android TV showed **GPU garbage** where Flutter `Text` and Material icons draw (synopsis blocks, meta row, bottom actions). Raster bits (title logo image, backdrop, solid progress bar) stayed fine — classic **glyph/icon atlas corruption**.

**Root cause:** [114](114-[open]-android-tv-movie-mediakit-audio-only.md) forced **Skia** on leanback (`--enable-impeller=false`) so MediaKit SurfaceProducer showed frames. Weak TV GLES + Skia atlas presents leave uninitialized tiles; crashes often follow the same driver thrash. Same visual class as [176](176-[workaround]-macos-intel-metal-text-glitch.md) (Intel Metal), different backend.

## Symptom fix (shipped)

[`TvFlutterShellArgs`](../../apps/forja/android/app/src/main/kotlin/com/forjahq/app/TvFlutterShellArgs.kt) + Application / MainActivity:

- `--enable-impeller=true`
- `--impeller-backend=opengles`

Phones unchanged (default Impeller / Vulkan). MediaKit keeps `vo=mediacodec_embed` (no Impeller EGL for video). `scripts/atv-run.sh` no longer passes `--no-enable-impeller`.

Not a Flutter engine root fix. If MediaKit goes black again under Impeller OpenGLES, keep Exo as the default path and reopen MediaKit surface work — do not re-enable Skia as the UI fix ([no-hide-as-fix](../../.cursor/rules/no-hide-as-fix.mdc)).

## Related

- [114](114-[open]-android-tv-movie-mediakit-audio-only.md) — prior Impeller-off for MediaKit  
- [176](176-[workaround]-macos-intel-metal-text-glitch.md) — macOS Intel glyph garbage  
- [031](031-[workaround]-android-tv-webview-gles-crash.md) — WebView GLES (separate)

## Verify

1. Logcat on boot: Impeller OpenGLES (not Skia) for leanback  
2. Browse Home → open a title — body text and icons readable  
3. Play with MediaKit — video + audio  
4. Phone: Impeller path unchanged
