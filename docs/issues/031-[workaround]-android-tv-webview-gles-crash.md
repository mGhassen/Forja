# 031 — Android TV WebView GLES crash (Chromium GPU abort)

**Status:** workaround  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/android/`, `apps/forja/lib/shared/webview/`, WebView extractors, live embeds, trailer hero

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** workaround · **0 / 1** root |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I31-T01 | Dart wrappers — `hardwareAcceleration: false` (View `LAYER_TYPE_NONE`; insufficient alone for Chromium GPU) | ✅ |
| 2 | I31-T02 | Unit test + repo guard — no direct plugin WebView outside `shared/webview/` | ✅ |
| 3 | I31-T03 | Native TV prep — `ForjaApplication` software WebView warm-up + defer boot `setWebContentsDebuggingEnabled` on TV | ✅ |

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

**Dart (View layer — supplement only):** [`forja_webview_settings.dart`](../../apps/forja/lib/shared/webview/forja_webview_settings.dart) sets `hardwareAcceleration: false` when [`PlatformInfo.isAndroidTv`](../../apps/forja/lib/shared/platform/platform_info.dart) is true. All app WebViews go through [`ForjaInAppWebView`](../../apps/forja/lib/shared/webview/forja_in_app_webview.dart) / [`ForjaHeadlessInAppWebView`](../../apps/forja/lib/shared/webview/forja_headless_in_app_webview.dart). This maps to `LAYER_TYPE_NONE` in the plugin and does **not** stop `Chrome_InProcGp` from starting.

**Native (Chromium layer):** [`ForjaApplication.kt`](../../apps/forja/android/app/src/main/kotlin/com/forja/app/ForjaApplication.kt) calls [`WebViewTvWorkaround.kt`](../../apps/forja/android/app/src/main/kotlin/com/forja/app/WebViewTvWorkaround.kt) on TV — `WebView.enableSlowWholeDocumentDraw()` plus a one-shot software-layer WebView warm-up. Trichrome 143+ has no Java `org.chromium.base.CommandLine` in the provider APK, so `--disable-gpu` reflection does not apply. [`bootstrap.dart`](../../apps/forja/lib/app/bootstrap.dart) skips boot-time `setWebContentsDebuggingEnabled` on TV (loads Chromium only when a feature needs WebView) and calls `PlatformChannel.prepareWebViewForTv()` first.

Desktop and phone profiles are unchanged — both patches are no-ops outside Android TV.

## Root fix (open)

- Emulator/device GLES stack exposes a valid ES version to Chromium, **or**
- Extractors move off WebView where possible (Rust engine / Pattern B per [ENGINE_BOUNDARY](../ENGINE_BOUNDARY.md))

## Verify

1. `sdk google atv64 arm64` emulator — boot past ~60s without crash  
2. Details hero trailer play  
3. Webstreaming play (headless `StreamExtractor`)  
4. Live matches CDN/DamiTV embed

**Dev fallback** (if reflection fails on a device): `adb shell 'echo "_ --disable-gpu" > /data/local/tmp/webview-command-line'` then cold-start the app.

## Related

- [010](fixed/010-[fixed]-webview-js-extractors-main-thread.md) — WebView stays on UI isolate by design  
- [025](025-[open]-android-tv-leanback-smoke-unverified.md) — broader ATV manual matrix
