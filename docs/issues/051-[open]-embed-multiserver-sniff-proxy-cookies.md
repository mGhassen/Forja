# 051 — Embed multi-server sniff, proxy body, cookies

**Status:** open
**Priority:** P1
**Severity:** High
**Area:** `StreamExtractor` / `EmbedExtractProfiles` / `HostProviderAdapter`

## Status at a glance

| | |
|--|--|
| **Progress** | **12 / 12** fix tasks · **0 / 7** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I51-T01 | Auto-click internal server chips (VidLove Neta/Gogo/Mafia/Fabric and similar) during sniff | ✅ |
| 2 | I51-T02 | Parse `/api/proxy`, `/api/sources`, and XHR/fetch bodies for embedded `.m3u8` (VidSrc.sbs / 1embed) | ✅ |
| 3 | I51-T03 | Harvest WebView cookies into playback headers; prefer embed Referer over CDN FRAME | ✅ |
| 4 | I51-T04 | Defer early-complete for `vidlove` / `vidsrc.sbs` / `1embed`; `forceDirect` + embed referer for those hosts | ✅ |
| 5 | I51-T05 | Per-provider `EmbedExtractProfile` registry — `StreamExtractor` stays generic; VidLove/VidSrc.sbs policy does not apply to other hosts | ✅ |
| 6 | I51-T06 | Headless WebView native popup window cancellation (`onCreateWindow`) | ✅ |
| 7 | I51-T07 | Generic headless navigation guard: block ad/tracker navigations and cancel main-frame hijacks away from the embed/player site | ✅ |
| 8 | I51-T08 | Cancel mid-sniff keeps a captured playable URL (complete + cookies) instead of discarding as `null` | ✅ |
| 9 | I51-T09 | Deferred-strong sniff ignores audio-only CDN clips (`tran-audio`) and waits for HLS/DASH before early-complete | ✅ |
| 10 | I51-T10 | Source panel: tapping another server clears the previous spinner and cancels the in-flight host sniff | ✅ |
| 11 | I51-T11 | VidSrc.sbs: rotate Server dropdown (`.srv-menu-item`); prefer PRO Multi / Cinesrc / Vlux over Star | ✅ |
| 12 | I51-T12 | `rotateBeforeComplete` — do not early-complete on default-server dead playlists; clear captures on `SERVER_CLICK` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I51-A01 | VidLove HOTD S1E1: sniff detects `.m3u8` and player opens (probe + progress) | ⬜ |
| 2 | I51-A02 | VidSrc.sbs HOTD S1E1: `VIDEO/STREAM DETECTED` (not only proxy/blob) then opens | ⬜ |
| 3 | I51-A03 | Multi-server chips: sniffer logs server-chip clicks; default LOADMAXING does not strand forever | ⬜ |
| 4 | I51-A04 | Template embed with popup/ad redirect: headless sniff blocks popup/main-frame hijack and still captures a playable stream | ⬜ |
| 5 | I51-A05 | Manual switch to another provider after a stream was detected: previous provider still returns that hit (not hard-null discard) | ⬜ |
| 6 | I51-A06 | Source panel: tap server A then B — only B shows the checking spinner; A stops loading | ⬜ |
| 7 | I51-A07 | VidSrc.sbs TMDB 279323 S1E1: sniff logs `SERVER_CLICK` for PRO Multi (or later) and opens a working stream (not only Star/1embed dead hits) | ⬜ |

---

## Summary

Browser works because users (or the page) pick a working internal server and the player keeps session cookies + correct Referer. Forja’s headless sniffer only clicked play overlays, ignored `/api/proxy` bodies without `.m3u8` in the URL, and opened CDN playlists with UA/Referer/Origin only (no Cookie). VidSrc.sbs nested into `1embed.cc` and never produced `VIDEO/STREAM DETECTED`. VidLove sometimes detected HLS then failed probe/open without cookies.

### VidSrc.sbs Server dropdown (I51-T11–T12)

`vidsrc.sbs/embed/tv/…` boots on **Star** (`1embed.cc`) and hides the other mirrors (PRO Multi / `web.nxsha.app`, Cinesrc, Vlux) in a closed `.srv-menu`. Star often emits dead proxy playlists that looked “strong” enough for early-complete, so Forja returned 1–2 broken streams and never switched. The sniffer now opens the dropdown, prefers PRO Multi → Cinesrc → Vlux → Star, clears captures on each `SERVER_CLICK`, and holds completion until after at least one server switch (`rotateBeforeComplete`).

### Ad / redirect hardening (I51-T06–T07)

Template embeds often work in a browser because popup ads open in another tab or the user dismisses them. The production headless sniffer did not have native `shouldOverrideUrlLoading` / `onCreateWindow` guards, so automated play/overlay clicks could send the main frame to an ad page before the real media request was captured.

The generic headless path now:

- disables JavaScript window creation and support for multiple windows,
- treats every `onCreateWindow` callback as handled/blocked,
- blocks obvious ad/tracker navigation URLs,
- cancels main-frame redirects away from the original embed/player site while still allowing subframe/player resources and playable media URLs.

### Architecture (I51-T05)

Rust already has one plugin file per HostRequired provider. Host sniff now mirrors that:

- **`EmbedExtractProfile`** — per-provider policy (`forceDirect`, chip rotation, proxy body, defer, CDN referer hosts)
- **`EmbedExtractProfiles.catalog`** — one entry per template embed (plus videasy sniff fallback)
- **`StreamExtractor`** — generic WebView engine; reads the active profile only
- **`HostProviderAdapter`** — `EmbedExtractProfiles.resolve(providerId)` then extract

VidLove chip labels / VidSrc.sbs proxy acceptance are **not** global if-ladders anymore.

### Cancel + audio-clip hardening (I51-T08–T09)

Manual provider switch and race teardown call `cancelAllPending()` → shared `StreamExtractor.cancel()`. That used to dispose the WebView and complete `null` even after `VIDEO/STREAM DETECTED`, and cookie harvest aborted when `_cancelled` was set. Cancel now:

- finishes an in-flight cookie harvest, or
- completes with the best non-audio playable URL already captured.

Deferred-strong profiles (VidLove, 111movies, VidSrc.sbs, …) no longer early-complete on progressive `tran-audio` mp4 clips — they wait for HLS/DASH (`isDeferredStrongStreamUrl`).

### Source panel one-at-a-time (I51-T10)

The in-player Source menu kept every tapped server in `_loadingProviders` until that future finished, so tapping VidRock while Vidzee was checking left **both** spinners on. The overlay now supersedes other loads (clear spinner, bump gen, drop status-roulette / probe `trying`), and `_loadProvider` cancels other in-flight host sniffs before starting the new one.

---

## Related

- [048](048-[open]-vidsrc-sbs-iframe-playback-restricted.md) — `forceDirect` for iframe “Playback Restricted” (kept; now on `vidsrcsbs` profile)
- [041](fixed/041-[fixed]-videasy-hangs-before-cdn-yoru.md) — similar “wrong first server” pattern
- [050](fixed/050-[fixed]-template-embed-one-file-per-plugin.md) — Rust one-file-per-plugin layout
