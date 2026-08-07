# 026 — LAN stream URLs require Bearer token; player does not send it

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `crates/lan`, `apps/forja/lib/shared/lan`, `apps/forja/lib/shared/player`

## Status at a glance

| | |
|--|--|
| **Progress** | **1 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I26-T01 | Mint short-lived stream ticket on `POST /open`; append `?st=` to `play_url`; validate ticket on media GETs (not Bearer) | ✅ |
| 2 | I26-T02 | Manual smoke: paired phone/ATV plays torrent stream from desktop LAN server (no 401 on `/torrents/…` or `/proxy/…`) | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I26-A01 | After pair, magnet play on mobile/ATV client reaches first frame without HTTP 401 on stream GET | ⬜ |
| 2 | I26-A02 | Proxy-gated relay plays on client when desktop serves | ⬜ |

---

## Summary

[RFC-022](../rfc/022-[open]-lan-server-client.md) token-gates LAN stream routes (`/torrents/…`, `/proxy/…`). Early designs used Bearer on every GET; media_kit / ExoPlayer often cannot attach `Authorization` to media requests, so stream GETs 401 even when pairing succeeds.

**Symptom fix (wrong):** disable auth on stream routes — do not ship.

**Root fix (shipped in code — I26-T01):** `POST /open` mints a short-lived stream ticket; `play_url` includes `?st=…` (also `X-Forja-Stream-Ticket`). Control plane keeps Bearer device tokens. Media middleware validates the ticket only.

**Still open:** I26-T02 / I26-A* manual smoke.

**Blocks:** RFC-022 R22-A07, R22-A08, R22-A13 until smoke passes.

## Related

- [RFC-022](../rfc/022-[open]-lan-server-client.md)
- [027](027-[draft]-lan-server-client-manual-qa.md) — full acceptance matrix
