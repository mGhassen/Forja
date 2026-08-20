# 167 — AutoEmbed sniff blocked by Cloudflare Turnstile

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** AutoEmbed · `nextgencloudfabric.com` · headless WebView sniff

## Status at a glance

| | |
|--|--|
| **Progress** | **1 / 2** fix tasks · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I167-T01 | Find non-WebView resolve path (API / decrypt) that bypasses Turnstile, or document hard CF gate | ✅ |
| 2 | I167-T02 | Ship host/Rust extract or FlareSolverr path so AutoEmbed yields streams without interactive Turnstile | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I167-A01 | Pin AutoEmbed on a title that works in browser — Forja resolves ≥1 playable stream without manual CF | ⬜ |
| 2 | I167-A02 | Log no longer ends only on Turnstile `600010` + sniff timeout | ⬜ |

---

## Summary

`player.autoembed.co` → `nextgencloudfabric.com/embed/…` now gates with Cloudflare Turnstile. Headless sniff logs `[Cloudflare Turnstile] Error: 600010`, rejects turnstile blobs, times out → `no streams`. Issue [056](fixed/056-[fixed]-autoembed-player-sandbox-playback-blocked.md) fixed iframe sandbox nesting; this is a new CF bot gate — chip-rotate will not help until the challenge is cleared or bypassed.

**Forja pack:** AutoEmbed HTTP chip removed (`engine.json` 1.5.7+) — no working non-Turnstile extract. Green Play sniff may still hit the host. Remaining work is FlareSolverr / attest API (I167-T02), not another empty Forja stub.

## Related

- [056](fixed/056-[fixed]-autoembed-player-sandbox-playback-blocked.md) — sandbox / player URL
- [166](166-[open]-vidlove-opaque-media-proxy.md) — VidLove opaque proxy (fixed separately)
- [031](031-[workaround]-android-tv-webview-gles-crash.md) — ATV skips WebView hosts
