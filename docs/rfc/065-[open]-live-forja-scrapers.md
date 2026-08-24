# RFC-065: Live sports Forja scrapers

**Status:** open  
**Depends on:** [RFC-060](fixed/060-[fixed]-enginejs-sources-forja-tab.md)  
**Area:** `apps/forja/assets/providers/live/`, Live Matches, Settings

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** components · **12 / 14** acceptance · **0 / 2** Android WebView GOAT |
| **Current slice** | Desktop Node GOAT shipped — Android/ATV WebView GOAT in progress ([203](../issues/203-[open]-android-tv-goat-webview-unlock.md)) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R65-C01 | `types: live` engine plugins + VOD Sources filter | ✅ |
| 2 | R65-C02 | Settings **Stream resolve** (Sniff \| Engine) + Live Forja plugin toggles | ✅ |
| 3 | R65-C03 | Live Matches **Forja Live** server + All merge | ✅ |
| 4 | R65-C04 | `live-streamed.js` + `ctx.live.goatUnlock` host bridge | ✅ |
| 5 | R65-C05 | `live-ppv.js` + extra live-sport provider plugins | ✅ |
| 6 | R65-C06 | Engine playback path (native proxy) vs existing sniff/embed | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R65-A01 | Settings → Live **Stream resolve** defaults Sniff; Engine runs plugins | ✅ |
| 2 | R65-A02 | Settings → **Live Forja plugins** enable list (bundled live entries only) | ✅ |
| 3 | R65-A03 | Movie Sources → Forja ignores `types: live` plugins | ✅ |
| 4 | R65-A04 | Live Matches **Forja Live** server lists enabled plugin catalogs | ✅ |
| 5 | R65-A05 | **All** merges Rust PPV/Streamed with Forja Live rows | ✅ |
| 6 | R65-A06 | Engine resolve: Streamed golf + GOAT paths → native player via HLS proxy | ✅ |
| 7 | R65-A07 | Engine resolve: PPV direct `source` / detail API when playable | ✅ |
| 8 | R65-A08 | Engine fail → toast only (no silent sniff fallback) | ✅ |
| 9 | R65-A09 | Sniff mode unchanged (embed WebView / existing sniff) | ✅ |
| 10 | R65-A10 | Bundled plugins: streamed, ppv, timstreams, streamfree, watchfooty, streamic (removed dead strims24, sportyhunter, ntv) | ✅ |
| 11 | R65-A11 | `engine_test.dart` covers live plugin entries | ✅ |
| 12 | R65-A12 | Feature doc + changelog Live & IPTV bullets | ✅ |
| 13 | R65-A13 | Manual: Engine Streamed admin/echo on desktop | ⏭️ |
| 14 | R65-A14 | Manual: Engine PPV direct source on live event | ⏭️ |
| 15 | R65-A15 | Android/ATV: GOAT unlock via off-screen WebView when Node missing | 🔄 |
| 16 | R65-A16 | Android/ATV: GASM (embedindia) unlock via WebView | ⬜ |

---

## Summary

Bundled live `extract(ctx)` plugins (upstream: [live-sport-plugin](https://github.com/rajhodedara/live-sport-plugin), [streamed-pk-hls-stream-resolver](https://github.com/sharoon7171/streamed-pk-hls-stream-resolver), [stremio-addon-ppvstreams](https://github.com/jpants36/stremio-addon-ppvstreams)) run beside existing Rust Live Matches fetch. **Stream resolve** setting picks Sniff (today) vs Engine (plugin → native player). Rust schedule APIs for PPV/Streamed/Mut stay.

### Contract

Live `extract(ctx)` receives `action` (`catalog` \| `resolve`), `matchId`, `source`, `stream`, `embedUrl`, `url`, `title`, `category`, `config`. Returns catalog match rows or `{ url, headers?, webviewOnly? }` stream rows. `ctx.live.goatUnlock(bodyHex, goat, slot)` decrypts embed.st GOAT responses (**desktop:** Node worker; **Android/iOS:** off-screen WebView + `lock.wasm`; golf path pure HTTP in JS).

### Related

- [RFC-060](fixed/060-[fixed]-enginejs-sources-forja-tab.md)
- [RFC-062](062-[open]-native-iptv-sports-matching.md)
- [Issue 203](../issues/203-[open]-android-tv-goat-webview-unlock.md) — ATV WebView GOAT
- [live-matches feature doc](../features/live/live-matches.md)
