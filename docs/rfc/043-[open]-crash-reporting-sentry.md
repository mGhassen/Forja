# RFC-043: Crash reporting (Sentry) + product analytics (PostHog)

**Status:** open  
**Depends on:** —  
**Area:** `apps/forja` telemetry, Settings → About; `apps/web` PostHog

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** components · **8 / 8** Sentry · **7 / 7** PostHog (app) · **4 / 4** PostHog (web) · **6 / 6** PostHog member identity · **0 / 0** deferred |
| **Current slice** | Session replay disabled — events/pageviews only |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R43-C01 | `Telemetry` facade (`captureError` / `track` / enable gates) | ✅ |
| 2 | R43-C02 | Sentry Flutter init + scrubbing (`beforeSend`) | ✅ |
| 3 | R43-C03 | Settings → About opt-in toggles (crash + product analytics) | ✅ |
| 4 | R43-C04 | PostHog SDK + allowlisted events + mobile session replay | ✅ |
| 5 | R43-C05 | Web portal PostHog (`posthog-js`) + SPA pageviews + masked replay | ✅ |
| 6 | R43-C06 | PostHog `identify(accounts.id)` + runtime person props (opt-in) | ✅ |

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
| 7 | R43-A24 | Session replay disabled in Flutter app; allowlisted events only when opted in | ✅ |

---

## Acceptance (web portal PostHog)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R43-A15 | Empty `VITE_POSTHOG_KEY` → portal SDK never starts (no network) | ✅ |
| 2 | R43-A16 | Configured key → SPA `$pageview` on route changes; session replay masks inputs/text; no email identify | ✅ |
| 3 | R43-A17 | Env docs (`apps/web` + root bridge) + feature/changelog | ✅ |
| 4 | R43-A25 | Web portal session recording disabled; SPA pageviews remain when key configured | ✅ |

---

## Acceptance (PostHog member identity)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R43-A18 | Opt-in + signed-in → `identify` with `accounts.id` (auth user UUID); never email as distinct id | ✅ |
| 2 | R43-A19 | Person props set/refreshed: `app_version`, `platform`, `os_version`, `arch`, `last_seen_at` (start, auth change, resume/focus) | ✅ |
| 3 | R43-A20 | Sign-out or analytics off → PostHog `reset`; unsigned still may set anonymous person props only | ✅ |
| 4 | R43-A21 | ~~Signed-in person prop `email`~~ → replaced by `member_number` (R43-A22) | ✅ |
| 5 | R43-A22 | `accounts.member_number` (opaque bigint, unique) + PostHog person prop; no email in PostHog | ✅ |
| 6 | R43-A23 | Admin Accounts page loads PostHog person runtime (app/platform/arch/last_seen) via server API | ✅ |

---

## Summary

**Sentry** = crashes / Issues (Flutter). **PostHog** = product events (Flutter opt-in; web pageviews when key configured). Session replay was shipped then disabled — replays did not surface reliably in PostHog. Flutter dual **opt-in** toggles (default off). Strict scrubbing — no stream URLs, magnets, cookies, JWTs. When product analytics is on and the user is signed in, PostHog Persons are keyed by **account id**, with runtime version/platform props plus opaque **`member_number`** (not email). Admin Accounts joins Supabase rows to PostHog person props (server-side personal API key).

**Out of scope:** Sentry Logs dump, Sentry Replay, identify-by-email (email as distinct id or person prop), Supabase `client_runtimes` inventory table.

### Privacy contract

| Allowed | Forbidden |
|---------|-----------|
| App version, platform, OS, arch | Stream / CDN / embed URLs |
| Exception type + scrubbed message | Magnets, IPTV credentials |
| Allowlisted event names (`app_start`, `play_started`, …) | Auth tokens, cookies, Authorization headers |
| Anonymous distinct id (SDK default) when signed out | Email / display name as distinct id **or** person prop |
| Signed-in distinct id = `accounts.id` (UUID) | Form passwords / IPTV credentials on web |
| Person props: `member_number`, `app_version`, `platform`, `os_version`, `arch`, `last_seen_at` | |
| Web portal page paths (scrubbed URL props) | |

### Related

- Settings hub: [RFC-033](033-[open]-settings-ux-redesign.md)
- Web portal: [RFC-034](034-[partial]-web-portal-landing.md)
