# 411 — TryEmbed Sources empty (bootstrap ticket)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/tryembed.js` · Anime Sources · TryEmbed

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I411-T01 | Parse `BOOTSTRAP_TICKET` from the embed page | ✅ |
| 2 | I411-T02 | `POST /api/bootstrap` with `X-TryEmbed-Bootstrap` and map provider tokens | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I411-A01 | Anime → One Piece E1 → TryEmbed lists a playable stream | ⬜ |

---

## Summary

TryEmbed embed HTML no longer sets `EMBED_NONCE`. It issues a one-time `BOOTSTRAP_TICKET`; the player `POST`s `/api/bootstrap` with `X-TryEmbed-Bootstrap` to get `embedNonce` and HLS tokens. Extract called `/api/stream_data` with an empty nonce and got 403 (`Invalid Request Signature`).

**Root fix:** exchange the bootstrap ticket, then reuse the same provider/token mapping. Providers pack **1.6.38**.
