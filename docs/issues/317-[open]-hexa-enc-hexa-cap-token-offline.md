# 317 — Hexa sources empty (`enc-hexa` Cap token offline)

**Status:** open
**Priority:** P1
**Severity:** High
**Area:** `hexa` provider · enc-dec.app · Cap

## Status at a glance

| | |
|--|--|
| **Progress** | **1 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I317-T01 | Surface `enc-hexa` upstream error in pack logs (no cascade empty-response noise) | ✅ |
| 2 | I317-T02 | When `enc-hexa` is online again: verify movie + TV extract → Sources rows | ⬜ |
| 3 | I317-T03 | Optional root: Cap solve without enc-dec (pack or host) if dependency keeps failing | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I317-A01 | Pin Hexa — Sources gets stream(s) when hexa.su plays (manual) | ⬜ |
| 2 | I317-A02 | Log on Cap miss names upstream (`Generation failure…` / offline), not only `no enc token` | ✅ |

---

## Summary

Hexa extract needs a Cap token from `GET https://enc-dec.app/api/enc-hexa`, then encrypted images from `theemoviedb.hexa.su` + `dec-hexa`. Without Cap, the TMDB images API returns `403 captcha_required`. Direct Cap at `cap.hexa.su/15d2cf0395/challenge` returns `Blocked` to scripted clients.

**Verified 2026-09-22:** enc-dec status stream reports `enc-hexa` **offline**; probe returns HTTP 500 `Generation failure: worker response timeout` (~30s). `dec-hexa` remains online. Pack flow matches EncDecEndpoints `samples/hexa.py` — not a path/fingerprint mismatch.

**Symptom (logs):** `hexa: no enc token` then `empty or blocked api response` (cascade). Pack now logs `hexa: enc-hexa failed (…)` once.

**Root:** upstream Cap-solver worker for Hexa is down. Streams cannot return until `enc-hexa` recovers or Forja ships an independent Cap path (T03).

## Related

- Pack: `forja-packs/providers/hexa.js`
- Upstream: [enc-dec.app/status](https://enc-dec.app/status) · [EncDecEndpoints hexa sample](https://github.com/smy778/EncDecEndpoints/blob/main/samples/hexa.py)
- Similar EncDec dependency: [169](169-[open]-vidfast-w-path-bundled-hls.md)
