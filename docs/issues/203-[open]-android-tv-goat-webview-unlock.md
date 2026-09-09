# 203 — Android / ATV GOAT unlock via off-screen WebView

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Live Matches · Forja Live · `LiveGoatUnlock` · Android TV

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 6** fix · **0 / 5** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I203-T01 | Off-screen WebView GOAT host (`LiveGoatWebviewUnlock`) + local asset server | ✅ |
| 2 | I203-T02 | `LiveGoatUnlock.unlock`: Node → else WebView (Android/iOS) | ✅ |
| 3 | I203-T03 | GASM / embedindia WebView path (PPV) | ✅ |
| 4 | I203-T04 | ATV + phone smoke: Streamed admin/delta play after unlock | ⬜ |
| 5 | I203-T05 | Enable GOAT/GASM WebView unlock on Windows/macOS when Node is missing | ✅ |
| 6 | I203-T06 | Desktop WebView bootstrap: same-origin loopback document (avoid WebView2 mixed-content block) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I203-A01 | ATV Forja Live Streamed row (admin/delta) unlocks without Node — Exo plays with embed Referer | ⬜ |
| 2 | I203-A02 | Desktop still uses Node GOAT (unchanged) | ⬜ |
| 3 | I203-A03 | PPV embedindia GASM unlock on ATV via WebView | ⬜ |
| 4 | I203-A04 | Windows without Node: Streamed Live Sports row unlocks via WebView2 — MediaKit plays | ⬜ |
| 5 | I203-A05 | Windows with Node: still prefers Node unlock (WebView unused) | ⬜ |

---

## Summary

Desktop GOAT decrypt shells out to Node + happy-dom + `lock.wasm`. Android has no Node → `node not found` → Engine resolve empty.

**Approach:** Dart still POST `/fetch`; off-screen Chromium WebView loads browser-ported `crack.js` + `lock.wasm` and returns m3u8 (same as Node `unlock.mjs`).

**Reuse bug (2026-08-24):** `lock-browser` caches wasm after the first `initLock`. A second crack on the same page hit the old import patch (`m3u8(import)` logged into a dead closure → `Reflect.get` → `ok:false`). Fix: serialize unlocks, reload the bootstrap page (cache-busted `crack.js` + dynamic `lock-browser.mjs` import) after each crack.

**GASM (PPV):** Same pattern — `LiveGasmWebviewUnlock` + `gasm/webview/crack.js` (ref `gasm.js`/`gasm.wasm`, then live `gasm-browser.mjs`/`gasm-live.wasm`) when Node is missing. `unlockGasm` → Node else WebView.

**Windows Streamed “No playable stream” (2026-09-09):** WebView unlock was Android/iOS-only. Typical Windows release boxes have no Node → unlock miss → toast. Mac often has Homebrew Node so it worked. `I203-T05`/`T06`: allow Windows/macOS WebView fallback; load crack from `http://127.0.0.1` (same-origin) because WebView2 blocks mixed content from an `https://embed.st` `loadData` document.
