# RFC-034: Web portal + landing + Flutter APIs

**Status:** partial  
**Depends on:** [RFC-006](006-[partial]-supabase-sync.md), [RFC-015](015-[partial]-in-app-updates.md)  
**Area:** `apps/web`, Supabase, Flutter SyncService / AppUpdaterService / announcements

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** components · **11 / 11** acceptance (v1 portal) |
| **Current slice** | TanStack Start scaffold — configure live Supabase project + deploy Edge Function to verify end-to-end |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R34-C01 | `apps/web` Vite/React/TanStack/shadcn scaffold | ✅ |
| 2 | R34-C02 | Creative-agency landing + `/download` | ✅ |
| 3 | R34-C03 | Auth + `/account` + `/account/settings` portal | ✅ |
| 4 | R34-C04 | Supabase schema (releases, announcements, user_settings) + Edge sync | ✅ |
| 5 | R34-C05 | Flutter consumers (updater, SyncService, announcements banner) | ✅ |
| 6 | R34-C06 | Migrate `apps/web` to TanStack Start (file routes + SSR build) | ✅ |

---

## Acceptance (v1 portal)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R34-A01 | Landing sells Forja experience (agency layout, brand tokens) | ✅ |
| 2 | R34-A02 | `/download` lists platform assets from `releases` / `release_assets` | ✅ |
| 3 | R34-A03 | Email/password sign-up and sign-in via Supabase Auth | ✅ |
| 4 | R34-A04 | Authenticated account home + settings sync status UI | ✅ |
| 5 | R34-A05 | Edge Function mirrors GitHub Releases into Supabase | ✅ |
| 6 | R34-A06 | Public read RLS for releases and active announcements | ✅ |
| 7 | R34-A07 | `user_settings` RLS own-rows only | ✅ |
| 8 | R34-A08 | Flutter `AppUpdaterService` prefers Supabase, falls back to GitHub | ✅ |
| 9 | R34-A09 | Flutter `SyncService` uses same Supabase project (domains deferred) | ✅ |
| 10 | R34-A10 | Flutter announcement banner from active announcements | ✅ |
| 11 | R34-A11 | `pnpm build` produces TanStack Start client + SSR output | ✅ |

---

## Summary

Marketing site and account portal under `apps/web`, backed by one Supabase project shared with the Flutter app. Not the v3 product web client ([RFC-010](010-[draft]-web-client.md)).

### Goals

- Creative-agency landing that presents Forja (not a generic SaaS template)
- User account portal for cloud settings sync ([RFC-006](006-[partial]-supabase-sync.md))
- Public APIs: latest release metadata, announcements feed, authenticated settings blobs
- GitHub Releases remain the publish source of truth; Supabase mirrors them

### Non-goals (v1)

- Admin CMS for landing copy
- Choosing which settings domains sync
- Flutter-in-browser playback
- Magic-link / OAuth beyond email-password

### Stack

TanStack Start (React + file routes + SSR) + TanStack Query, Tailwind + shadcn, Supabase Auth / Postgres / Storage / Edge Functions. Package manager: `pnpm` in `apps/web` only.

### Related

- [RFC-006](006-[partial]-supabase-sync.md) — settings sync
- [RFC-015](015-[partial]-in-app-updates.md) — in-app updates
- Backlog [1.0.4](../backlog/1.0.4-[draft].md)
