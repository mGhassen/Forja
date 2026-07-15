# Issue 046 — Streamed live match embed: white screen / unlimited loading

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `features/live_matches/` embed WebView (`live_matches_widgets.dart`)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 1** device smoke |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I46-T01 | Load Streamed/PPV embeds via iframe wrapper under catalog origin (`document.referrer`) | ✅ |
| 2 | I46-T02 | Content-block parser-blocking ad hosts; only cancel main-frame hijacks (allow player subframes) | ✅ |
| 3 | I46-T03 | Loading watchdog + iframe autoplay/fullscreen permissions | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I46-A01 | Open a live Streamed match on macOS: player shows video (not white / infinite spinner); website stream still works as reference | ⬜ |

---

## Summary

Streamed.pk works in a browser; Forja opened `embed.st` as a **top-level** WebView URL. That page injects a **parser-blocking** ad script (`therocketlanguages.com`) before the player, and the site normally hosts the player in an **iframe** under `streamed.pk` (so `document.referrer` is set). Forja also cancelled **any** navigation whose URL did not contain the embed host — including player CDN / nested iframe loads — which left a blank white player when the override was active.

**Symptom:** Unlimited loading spinner and/or white embed screen when playing a Streamed live match.

**Root:** Top-level embed load + aggressive `shouldOverrideUrlLoading` + ad script stall — not the Streamed API failing (match list / `embedUrl` resolve were fine).

**Related:** Windows-only see-through white surface (Escape still pops) is [053](053-[workaround]-windows-live-embed-webview2-transparent.md) — WebView2 `DefaultBackgroundColor` alpha bug, not this embed/ad stall track.
