# 223 — Live Providers open raw embeds → Failed to recognize file format

**Priority:** P1  
**Severity:** High  
**Status:** fixed  
**Area:** Live Matches Providers, `plugins/live/streamic.js`, `live_play_dispatch.dart`, `crates/live-matches`  
**Reported:** 2026-09-06

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** fix · **2 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I223-T01 | Host: require `.m3u8`/`.mp4` (or local proxy) after live resolve — never open catalog embed HTML | ✅ |
| 2 | I223-T02 | Host: skip streamed.pk `/api/stream` for non-GOAT sources (streamic, …) | ✅ |
| 3 | I223-T03 | Rust: invent embed.st fallback only for admin/delta/golf/ppv/bravo | ✅ |
| 4 | I223-T04 | Streamic catalog emits `streams` embeds; live resolve omits unlock misses | ✅ |
| 5 | I223-T05 | TimStreams resolve omits unlock misses (same no-embed contract) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I223-A01 | Streamed Providers row for a live fixture unlocks to native HLS or toast “No playable stream” — no `Failed to recognize file format` reconnect loop on embed HTML | ✅ |
| 2 | I223-A02 | Streamic sibling no longer invents `embed.st/embed/streamic/…` via streamed.pk fallback | ✅ |

---

## Summary

Opening a Streamed fixture hydrated Providers with Streamic + Streamed. Streamic resolve returned unlock-failed embed page URLs as if they were streams. The host treated any `https://` handoff as playable, MediaKit opened HTML → **Failed to recognize file format**, IPTV watchdog reconnect loop.

Separately, Rust `streamed_streams` invented `https://embed.st/embed/{source}/{id}/1` for any empty API result — including `source=streamic`.

## Root cause

1. Plugin returned raw embed URLs when unlock failed.
2. Host accepted any `http(s)` URL as a playable handoff.
3. Rust invented embed.st for foreign source tokens.

## Fix

- Host opens live engine sources only when the URL is m3u8/mp4/local proxy.
- Catalog stream fetch + Rust fallback limited to streamed.pk GOAT slots.
- Streamic catalog ships embed `streams` for unlock-on-tap; resolve returns unlocked HLS only.
- Failed unlock → toast, not format-fail loop.

## Related

- [no-embed-playback](../../../.cursor/rules/no-embed-playback.mdc)
- [046](../046-[open]-streamed-live-embed-white-screen.md) — legacy WebView white screen (separate)
