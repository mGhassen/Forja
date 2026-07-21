# RFC-043: Crash reporting (Sentry) + product analytics (PostHog)

**Status:** open  
**Depends on:** —  
**Area:** `apps/forja` telemetry, Settings → About

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **8 / 8** Sentry · **6 / 6** PostHog · **0 / 0** deferred |
| **Current slice** | Sentry Issues + PostHog events/replay (mobile); dual opt-in toggles |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R43-C01 | `Telemetry` facade (`captureError` / `track` / enable gates) | ✅ |
| 2 | R43-C02 | Sentry Flutter init + scrubbing (`beforeSend`) | ✅ |
| 3 | R43-C03 | Settings → About opt-in toggles (crash + product analytics) | ✅ |
| 4 | R43-C04 | PostHog SDK + allowlisted events + mobile session replay | ✅ |

---

## Acceptance (Sentry slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R43-A01 | Crash reporting defaults **off**; no network to Sentry until opted in | ✅ |
| 2 | R43-A02 | Opt-in + non-empty `SENTRY_DSN` dart-define → Flutter / zone / platform errors report | ✅ |
| 3 | R43-A03 | Scrub strips stream URLs, magnets, auth headers/tokens from events | ✅ |
| 4 | R43-A04 | Empty DSN or opt-out → crash path is a no-op (no SDK traffic) | ✅ |
| 5 | R43-A05 | Settings → About shows Crash reporting toggle; enable/disable without requiring rebuild | ✅ |
| 6 | R43-A06 | Feature doc + changelog | ✅ |
| 7 | R43-A07 | Release CI passes `SENTRY_DSN` from GitHub secret when set | ✅ |
| 8 | R43-A08 | Unit tests cover scrub + disabled no-op | ✅ |

---

## Acceptance (PostHog slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R43-A09 | Product analytics defaults **off**; PostHog setup only after opt-in + API key | ✅ |
| 2 | R43-A10 | Allowlisted `Telemetry.track` events only; scrub string props | ✅ |
| 3 | R43-A11 | Session replay enabled with analytics opt-in (masked); SDK may no-op on unsupported platforms | ✅ |
| 4 | R43-A12 | Settings → About Product analytics toggle + debug Verify PostHog | ✅ |
| 5 | R43-A13 | CI dart-defines `POSTHOG_API_KEY` / `POSTHOG_HOST`; feature doc + changelog | ✅ |
| 6 | R43-A14 | No Sentry Session Replay (product replay is PostHog) | ✅ |

---

## Summary

**Sentry** = crashes / Issues. **PostHog** = product events + mobile session replay. Dual **opt-in** toggles (default off). Strict scrubbing — no stream URLs, magnets, cookies, JWTs.

**Out of scope:** Sentry Logs dump, Sentry Replay, web/admin SDKs, identify-by-email.

### Privacy contract

| Allowed | Forbidden |
|---------|-----------|
| App version, platform, OS | Stream / CDN / embed URLs |
| Exception type + scrubbed message | Magnets, IPTV credentials |
| Allowlisted event names (`app_start`, `play_started`, …) | Auth tokens, cookies, Authorization headers |
| Anonymous distinct id (SDK default) | Account email / display name |

### Related

- Settings hub: [RFC-033](033-[open]-settings-ux-redesign.md)
