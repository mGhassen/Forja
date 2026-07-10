# 031 — Android TV WebView GLES crash (Chromium GPU abort)

**Status:** workaround  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/webview/`, WebView extractors, live embeds, trailer hero

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** workaround · **0 / 1** root |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I31-T01 | `ForjaInAppWebView` / `ForjaHeadlessInAppWebView` — TV software compositing patch | ✅ |
| 2 | I31-T02 | Unit test + repo guard — no direct plugin WebView outside `shared/webview/` | ✅ |

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

[`forja_webview_settings.dart`](../../apps/forja/lib/shared/webview/forja_webview_settings.dart) sets `hardwareAcceleration: false` when [`PlatformInfo.isAndroidTv`](../../apps/forja/lib/shared/platform/platform_info.dart) is true. All app WebViews go through [`ForjaInAppWebView`](../../apps/forja/lib/shared/webview/forja_in_app_webview.dart) / [`ForjaHeadlessInAppWebView`](../../apps/forja/lib/shared/webview/forja_headless_in_app_webview.dart) so the patch cannot be skipped.

Desktop and phone profiles are unchanged — patch is a no-op outside Android TV.

## Root fix (open)

- Emulator/device GLES stack exposes a valid ES version to Chromium, **or**
- Extractors move off WebView where possible (Rust engine / Pattern B per [ENGINE_BOUNDARY](../ENGINE_BOUNDARY.md))

## Verify

1. `sdk google atv64 arm64` emulator — boot past ~60s without crash  
2. Details hero trailer play  
3. Webstreaming play (headless `StreamExtractor`)  
4. Live matches CDN/DamiTV embed

## Related

- [010](fixed/010-[fixed]-webview-js-extractors-main-thread.md) — WebView stays on UI isolate by design  
- [025](025-[open]-android-tv-leanback-smoke-unverified.md) — broader ATV manual matrix
