# 475 — Release TV login shows `dev.forjahq.xyz`

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Android TV · account · device-link  
**Reported:** 2026-10-24 (shipped ATV build showed Connect → `dev.forjahq…/connect`)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Released Android TV Sign in / device-link UI shows **connect to `dev.forjahq.xyz`** (QR + host label) instead of production `www.forjahq.xyz`. Users hit Vercel Authentication / wrong portal.

## Root cause

`FORJA_WEB_URL` is baked via `--dart-define` at build time (`DesktopBrowserAuth.webUrl`). Release CI / local release only rejected **localhost**, not staging `dev.forjahq.xyz`. A bad GitHub secret or `.env` shipped staging into the ATV APK.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I475-T01 | Release builds rewrite staging/localhost portal → `https://www.forjahq.xyz` | ✅ |
| 2 | I475-T02 | CI + `release_local` fail if `FORJA_WEB_URL` contains `dev.forjahq.xyz` | ✅ |
| 3 | I475-T03 | Unit test for release portal resolve | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I475-A01 | Set `FORJA_WEB_URL` GitHub secret to `https://www.forjahq.xyz` (forjahq + origin mirrors) | ⬜ |
| 2 | I475-A02 | Re-ship Android TV; Sign in shows `www.forjahq.xyz/connect` | ⬜ |

## Links

- [docs/DEVELOPMENT.md](../../DEVELOPMENT.md) — portal URL vs Vercel protection
- [tv-connect](../../features/accounts/tv-connect.md)
