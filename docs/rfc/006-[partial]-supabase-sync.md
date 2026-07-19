# RFC-006: Supabase settings sync

**Version:** v1.2  
**Status:** partial  
**Area:** `apps/forja/lib/shared/sync/src/sync_service.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 3** components · **3 / 4** acceptance (v1.2 slice) · **4 / 5** acceptance (web portal slice) · **8 / 8** acceptance (profiles slice) · **7 / 8** acceptance (desktop account slice) · **4 / 4** acceptance (desktop browser auth) · **3 / 3** acceptance (desktop captcha) · **2 / 2** acceptance (session inactivity) · **2 / 5** acceptance (accounts hub slice) |
| **Current slice** | 7-day Auth inactivity + client refreshSession — accounts hub / global IPTV remains [RFC-036](036-[open]-accounts-iptv-profile-settings.md) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R06-C01 | SyncService (`sync_service.dart`) | ✅ |
| 2 | R06-C02 | Account profiles with profile-scoped settings | ✅ |
| 3 | R06-C03 | Optional desktop account entry and profile-aware shell | 🔄 |

---

## Acceptance (v1.2 slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R06-A01 | Email/password sign-in from Settings → Account | ✅ |
| 2 | R06-A02 | Push/pull settings blobs when signed in | ✅ |
| 3 | R06-A03 | Merge by latest `updated_at` per domain | ⬜ |
| 4 | R06-A04 | Sign-out clears remote session; local data retained | ✅ |

---

## Acceptance (web portal slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R06-A05 | `supabase_flutter` client init from dart-defines | ✅ |
| 2 | R06-A06 | Real Auth signIn / signOut against shared Supabase project | ✅ |
| 3 | R06-A07 | `pushSettings` / `pullSettings` against `user_settings` | ✅ |
| 4 | R06-A08 | Same schema/RLS as `apps/web` account portal | ✅ |
| 5 | R06-A09 | Concrete sync domain allowlist | ⏭️ |

---

## Acceptance (profiles slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R06-A10 | Each account can create, rename, select, and delete multiple profiles | ✅ |
| 2 | R06-A11 | Every settings domain belongs to exactly one profile | ✅ |
| 3 | R06-A12 | Existing account settings migrate into a default profile without data loss | ✅ |
| 4 | R06-A13 | Profile selection is local to each web/app device | ✅ |
| 5 | R06-A14 | Flutter sync reads and writes only the selected profile | ✅ |
| 6 | R06-A15 | RLS prevents access to profiles and profile settings owned by another account | ✅ |
| 7 | R06-A16 | Netflix-style profile chooser with account-owned avatar selection | ✅ |
| 8 | R06-A17 | Avatar picker offers 30 choices grouped into categories of up to eight | ✅ |

---

## Acceptance (desktop account slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R06-A18 | Unauthenticated desktop launches show account entry before the splash | ✅ |
| 2 | R06-A19 | Continue without an account preserves the existing local-only app flow | ✅ |
| 3 | R06-A20 | A restored authenticated session bypasses account entry and opens the splash directly | ✅ |
| 4 | R06-A21 | Interactive sign-in or account creation opens the account profile chooser before the splash | ✅ |
| 5 | R06-A22 | Choosing a profile activates and pulls that profile before app startup | ✅ |
| 6 | R06-A23 | The desktop rail replaces the Settings glyph with the active profile avatar while still opening Settings | ✅ |
| 7 | R06-A24 | Settings exposes a dedicated Profile & account page for switching profiles and managing the Forja session | ✅ |
| 8 | R06-A25 | Local and CI builds inject the shared Supabase URL and public client key without committing a service-role secret | 🔄 |

---

## Acceptance (desktop browser auth)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R06-A30 | Desktop account entry offers **Web login** that opens the portal and returns a session via localhost callback | ✅ |
| 2 | R06-A31 | In-app signup removed; create-account CTA opens web `/signup` only | ✅ |
| 3 | R06-A32 | Web `/login?desktop_callback=…` hands access/refresh tokens back to the desktop app after sign-in | ✅ |
| 4 | R06-A34 | Web login wait is cancellable — Cancel / guest unlock the desktop sign-in screen if the browser never returns | ✅ |

---

## Acceptance (desktop captcha)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R06-A35 | `TURNSTILE_SITE_KEY` dart-define enables in-app Turnstile on desktop email/password sign-in | ✅ |
| 2 | R06-A36 | Account entry + Settings → Profile & account pass `captchaToken` to Supabase Auth | ✅ |
| 3 | R06-A37 | Failed auth remounts Turnstile for a fresh token; empty site key hides the widget | ✅ |

---

## Acceptance (session inactivity)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R06-A38 | GoTrue `inactivity_timeout` = 7 days (`168h`); JWT expiry stays 1h | ✅ |
| 2 | R06-A39 | App + web call `refreshSession` on boot/resume/focus (debounced) to keep sessions alive while in use | ✅ |

---

## Acceptance (accounts hub slice — RFC-036)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R06-A26 | Sync uses `profile_settings` single payload (not multi-domain `user_settings`) | ⬜ |
| 2 | R06-A27 | IPTV credentials live in global `iptv_portals`; profile stores portalId + label | ⬜ |
| 3 | R06-A28 | Flutter profile switch shows dedicated splash until pull/merge finishes | ✅ |
| 4 | R06-A29 | Schema/RLS match web portal accounts hub ([RFC-036](036-[open]-accounts-iptv-profile-settings.md)) | ⬜ |
| 5 | R06-A33 | Mid-session profile switch lands on that profile’s saved default nav tab (not the previous screen) | ✅ |

---

## Summary

Optional account to backup and restore settings across devices. Offline-first — no auth required to use Forja.


## Stub

`apps/forja/lib/shared/sync/src/sync_service.dart`

## Auth

- Supabase Auth: email/password (app + web); desktop **Web login** via portal localhost callback
- When Auth captcha is enabled, desktop password login embeds Cloudflare Turnstile (`TURNSTILE_SITE_KEY`) and sends `captchaToken`
- Sign-up is web-only (`/signup`); desktop links out for account creation
- Sign-in from desktop startup / Settings → Profile & account
- Sign-out clears remote session only; local data retained
- Sessions end after **7 days without refresh** (`[auth.sessions] inactivity_timeout`); clients refresh on resume/focus
- Hosted projects must set the same inactivity timeout in Dashboard → Authentication → Sessions

## Schema

```sql
create table profiles (
  id uuid primary key,
  user_id uuid references auth.users not null,
  name text not null
);

create table user_settings (
  user_id uuid references auth.users not null,
  profile_id uuid references profiles not null,
  domain text not null,
  payload jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (profile_id, domain)
);

alter table user_settings enable row level security;
create policy "own rows" on user_settings
  for all using (auth.uid() = user_id);
```

## Sync domains

| Domain | Payload | Encryption |
|--------|---------|------------|
| iptv | portals, groups, M3U refs | client-side (credentials) |
| stremio | addon URLs | plain |
| providers | order, enabled, lastUsed | plain |
| watch_history | continue watching | plain |
| preferences | theme, subtitles, player | plain |

**Local-only (never sync):** torrent cache, temp files, LAN pairing tokens.

## Merge strategy

On login: pull remote → merge with local per domain; conflict = latest `updated_at` wins per key.

On change: debounced push (5s) when signed in.

Profile selection is stored locally on each device. Switching a profile on one
device does not switch other signed-in devices.

## Client API (to implement)

```dart
class SyncService {
  Future<void> signIn({ email, password });
  Future<void> signOut();
  Future<void> pullAll();
  Future<void> pushDomain(String domain, Map<String, dynamic> payload);
  Stream<SyncStatus> get status;
}
```

## Migrations

Use `supabase migration new <name>` — never create SQL files manually.

