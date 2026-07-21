# RFC-043: Crash reporting (Sentry)

**Status:** open  
**Depends on:** —  
**Area:** `apps/forja` telemetry, Settings → About

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** components · **8 / 8** acceptance · **0 / 1** deferred |
| **Current slice** | Sentry + Telemetry facade + opt-in Settings toggle shipped; PostHog deferred |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R43-C01 | `Telemetry` facade (`captureError` / `captureEvent` / enable gate) | ✅ |
| 2 | R43-C02 | Sentry Flutter init + scrubbing (`beforeSend`) | ✅ |
| 3 | R43-C03 | Settings → About opt-in toggle (default off) | ✅ |

---

## Acceptance (Sentry slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R43-A01 | Crash reporting defaults **off**; no network to Sentry until opted in | ✅ |
| 2 | R43-A02 | Opt-in + non-empty `SENTRY_DSN` dart-define → Flutter / zone / platform errors report | ✅ |
| 3 | R43-A03 | Scrub strips stream URLs, magnets, auth headers/tokens from events | ✅ |
| 4 | R43-A04 | Empty DSN or opt-out → `Telemetry` is a no-op (no SDK traffic) | ✅ |
| 5 | R43-A05 | Settings → About shows Crash reporting toggle; enable/disable without requiring rebuild | ✅ |
| 6 | R43-A06 | Feature doc + changelog | ✅ |
| 7 | R43-A07 | Release CI passes `SENTRY_DSN` from GitHub secret when set | ✅ |
| 8 | R43-A08 | Unit tests cover scrub + disabled no-op | ✅ |

---

## Acceptance (later)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R43-A09 | PostHog product analytics (allowlisted events only) | ⏭️ |

---

## Summary

Ship **Sentry** for crashes and uncaught errors behind a thin `Telemetry` facade. **Opt-in** (default off). DSN via `--dart-define=SENTRY_DSN`. Strict scrubbing — no stream URLs, magnets, cookies, JWTs.

**Out of scope (this slice):** PostHog, OpenTelemetry spans, full log shipping, web/admin Sentry.

### Privacy contract

| Allowed | Forbidden |
|---------|-----------|
| App version, platform, OS | Stream / CDN / embed URLs |
| Exception type + scrubbed message | Magnets, IPTV credentials |
| Allowlisted event names (`app_start`, …) | Auth tokens, cookies, Authorization headers |
| Anonymous install id (Sentry default) | Account email / display name unless user later opts into identity |

### Related

- PostHog deferred as `R43-A09`
- Settings hub: [RFC-033](033-[open]-settings-ux-redesign.md)
