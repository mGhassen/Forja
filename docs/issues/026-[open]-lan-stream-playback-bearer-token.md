# 026 — LAN stream URLs require Bearer token; player does not send it

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `crates/lan`, `apps/forja/lib/shared/lan`, `apps/forja/lib/shared/player`

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I26-T01 | Return auth headers (or signed play URL) from `POST /open`; propagate through `LanClientService` → `StremioPlayable` / player `Media(httpHeaders: …)` | ⬜ |
| 2 | I26-T02 | Manual smoke: paired phone plays torrent stream from desktop LAN server (no 401 on `/torrents/…` or `/proxy/…`) | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I26-A01 | After pair, magnet play on mobile client reaches first frame without HTTP 401 on stream GET | ⬜ |
| 2 | I26-A02 | Proxy-gated relay (e.g. 111477) plays on client when desktop serves | ⬜ |

---

## Summary

[RFC-022](../rfc/022-[draft]-lan-server-client.md) token-gates LAN stream routes (`/torrents/…`, `/proxy/…`) with Bearer auth. `LanClientService.openStream` sends the token on `POST /open` only; the returned `play_url` is opened by media_kit **without** `Authorization`. Stream GETs fail with 401 even when pairing succeeds.

**Symptom fix (wrong):** disable auth on stream routes — do not ship; LAN exposure must stay token-gated per RFC-022 §8.

**Root fix:** one of:

- Include `Authorization: Bearer …` (or equivalent) in `OpenResponse.headers` and wire through player open path
- Short-lived signed query token on play URLs (no custom headers in mpv)
- Path-embedded stream token validated by gateway middleware

**Blocks:** RFC-022 R22-A07, R22-A08 until fixed.

## Related

- [RFC-022](../rfc/022-[draft]-lan-server-client.md)
- [027](027-[draft]-lan-server-client-manual-qa.md) — full acceptance matrix
