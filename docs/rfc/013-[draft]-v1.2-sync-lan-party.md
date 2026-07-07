# RFC-013: v1.2 — Sync, LAN companion, watch party

**Version:** v1.2  
**Status:** draft  
**Target version:** v2 (Diwan & mer)  
**Depends on:** RFC-012 (v1.1)

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 6** acceptance (v1.2 bundle) · child RFCs: [006](006-[partial]-supabase-sync.md) 0/1·0/4, [007](007-[draft]-lan-companion.md) 0/4, [008](008-[partial]-watch-party.md) 0/4 |
| **Current slice** | v1.2 — sync + LAN remote + watch party |
| **Backlog** | v2 |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Acceptance (v1.2 bundle)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R13-A01 | Sign up / sign in optional; offline-first unchanged | ⬜ |
| 2 | R13-A02 | IPTV credentials encrypted before upload | ⬜ |
| 3 | R13-A03 | Settings restore on new device after login | ⬜ |
| 4 | R13-A04 | LAN companion pairs and controls playback | ⬜ |
| 5 | R13-A05 | Watch party works on same Wi-Fi (2+ clients) | ⬜ |
| 6 | R13-A06 | Internet watch party scoped separately if Phase B | ⬜ |

---

## Goal

Optional cloud account for settings portability, LAN remote control, and synchronized group playback.

## Deliverables

### 1. Supabase settings sync (RFC-006)

**Auth:** optional — app fully usable without account.

**Synced domains** (encrypted client-side for credentials):

| Domain | Keys |
|--------|------|
| IPTV | portals, groups, M3U refs |
| Stremio | addon list |
| Providers | order, enabled, lastUsed |
| Watch history | continue watching |
| Preferences | theme, subtitles, external player |

**Schema:**

```sql
create table user_settings (
  user_id uuid references auth.users not null,
  domain text not null,
  payload jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, domain)
);
-- RLS: auth.uid() = user_id
```

**Client:** implement `SyncService` in `apps/forja/lib/shared/sync/` — merge local ↔ remote on login; conflict = latest `updated_at` per domain.

**Migration:** use `supabase migration new <name>` (never manual files).

### 2. LAN companion (RFC-007)

Extend `packages/streaming/lib/src/local_server_service.dart`:

- Bind LAN interface with pairing token (QR or 6-digit code)
- REST: `GET /api/status`, `POST /api/playback/{play,pause,seek}`, `GET/PATCH /api/settings/{domain}`
- WebSocket for realtime playback state

Use cases: phone remote for TV app, second-screen controls.

### 3. Watch party (RFC-008)

**Phase A — LAN:** WebSocket room on host device; sync stream URL, position, play/pause.

**Phase B — Internet:** Supabase Realtime or dedicated signaling server.

Player overlay: enable Watch Party button (currently placeholder).

**Host controls:** play/pause/seek; guests follow within ±2s tolerance.


## Related RFCs

RFC-006, RFC-007, RFC-008
