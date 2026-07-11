# 031 — Android TV WebView GLES crash (Chromium GPU abort)

**Status:** workaround  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/android/`, `apps/forja/lib/shared/webview/`, WebView extractors, live embeds, trailer hero

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** workaround · **0 / 1** root |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I31-T01 | Dart wrappers — `hardwareAcceleration: false` (View `LAYER_TYPE_NONE`; insufficient alone for Chromium GPU) | ✅ |
| 2 | I31-T02 | Unit test + repo guard — no direct plugin WebView outside `shared/webview/` | ✅ |
| 3 | I31-T03 | Native TV prep — software WebView warm-up + defer boot `setWebContentsDebuggingEnabled` on TV | ✅ |
| 4 | I31-T04 | Block headless WebView on TV; route play via WebStreamr/Vidsrc/111477; [`scripts/atv-run.sh`](../../scripts/atv-run.sh) for emulator GPU flags | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I31-A01 | ATV emulator: app survives WebView init (boot, trailer, webstream extract, live embed) without `gl_version_info.cc` fatal | ⬜ |

---

## Summary

On Android TV emulators (and some leanback devices), Chromium's in-process GPU thread aborts when WebView initializes with an empty GLES version string:

```
[FATAL:ui/gl/gl_version_info.cc:73] Chrome runs only on top of OpenGL ES through either ANGLE or native: VERSION =
```

Thread name: `Chrome_InProcGp`. This is **not** `media_kit` / player UI — it is WebView/Chromium.

## Workaround (shipped)

**Dart (View layer — supplement):** [`forja_webview_settings.dart`](../../apps/forja/lib/shared/webview/forja_webview_settings.dart) sets `hardwareAcceleration: false` on TV. Maps to `LAYER_TYPE_NONE` — does **not** stop `Chrome_InProcGp`.

**Native (boot):** [`ForjaApplication.kt`](../../apps/forja/android/app/src/main/kotlin/com/forja/app/ForjaApplication.kt) + [`WebViewTvWorkaround.kt`](../../apps/forja/android/app/src/main/kotlin/com/forja/app/WebViewTvWorkaround.kt) — software warm-up; boot skips `setWebContentsDebuggingEnabled` on TV.

**Stream play (TV — no headless WebView):** [`atv_webview_guard.dart`](../../apps/forja/lib/shared/webview/atv_webview_guard.dart) blocks `StreamExtractor`, `AmriExtractor`, and Videasy WASM WebView on TV. [`tv_stream_fallback.dart`](../../apps/forja/lib/shared/playback/tv_stream_fallback.dart) resolves via WebStreamr / Vidsrc / 111477. Details webstreaming extraction prioritizes Rust providers on TV.

**Emulator dev (embedded WebView — trailers/live):** [`scripts/atv-run.sh`](../../scripts/atv-run.sh) writes `/data/local/tmp/webview-command-line` with `--disable-gpu` before `flutter run`.

## Root fix (open)

- Emulator/device GLES stack exposes a valid ES version to Chromium, **or**
- Extractors move off WebView where possible (Rust engine / Pattern B per [ENGINE_BOUNDARY](../ENGINE_BOUNDARY.md))

## Verify

1. `scripts/atv-run.sh` or manual adb flags — cold start  
2. Play webstream title on ATV — must use WebStreamr/Vidsrc (no headless sniff crash)  
3. Trailer / live embed with adb GPU flags  
4. Boot past 60s idle

## Related

- [010](fixed/010-[fixed]-webview-js-extractors-main-thread.md) — WebView stays on UI isolate by design  
- [025](025-[open]-android-tv-leanback-smoke-unverified.md) — broader ATV manual matrix
