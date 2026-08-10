# 170 — Vidzee sniff blocked by Cloudflare shell

**Status:** open
**Priority:** P1
**Severity:** High
**Area:** `vidzee` EmbedExtractProfile · `StreamExtractor` CF wait

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix tasks · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I170-T01 | `waitForCloudflare` on profile; Miruro-style poll after WebView boot (sniff timer starts after clear) | ✅ |
| 2 | I170-T02 | Vidzee: forceDirect + defer + rotateServerChips + 90s sniff / 120s SimpleResolve | ✅ |
| 3 | I170-T03 | Issue/docs/changelog + unit profile asserts | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I170-A01 | Unit: vidzee `waitForCloudflare` + forceDirect + rotate | ✅ |
| 2 | I170-A02 | App: pin Vidzee when browser plays — sniff clears CF or logs CF wait timeout (manual) | ⬜ |

---

## Summary

Browser plays `player.vidzee.wtf`; Forja headless often lands on Cloudflare error/challenge shell (`cdn-cgi`, `cf-icon-error`, sometimes origin **522**). Same class as AutoEmbed Turnstile / Miruro CF — not a chip-rotate bug.

**Symptom fix (shipped):** wait for CF interstitial clear (Miruro poll), then full sniff budget; forceDirect + defer + server rotate.

**Root / hard gate (open):** origin 522 or Turnstile that never clears in WKWebView — needs non-WebView API or FlareSolverr-class path (see [167](167-[open]-autoembed-cloudflare-turnstile.md)).

## Related

- [080](080-[open]-miruro-cf-pipe-webview-unlock.md) — Miruro CF pipe
- [167](167-[open]-autoembed-cloudflare-turnstile.md) — AutoEmbed Turnstile
- [169](169-[open]-vidfast-w-path-bundled-hls.md) — VidFast (separate)
