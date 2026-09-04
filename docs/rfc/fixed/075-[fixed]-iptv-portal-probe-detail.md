# RFC-075: IPTV portal probe status + desktop detail card

**Status:** fixed  
**Depends on:** [RFC-040](../040-[open]-iptv-catalog-ops.md) · [RFC-051](../051-[open]-iptv-multi-protocol-portals.md)  
**Area:** `crates/iptv/`, `apps/forja/lib/features/iptv/`, `apps/admin/` verify

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **4 / 4** components · **8 / 8** acceptance |
| **Current slice** | Structured probe + admin tighten + desktop 1s hover card shipped |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R75-C01 | Rust Xtream login: `server_info` on success; structured `auth_failed` with status/message | ✅ |
| 2 | R75-C02 | Dart `PortalProbeResult` cache (alive + account + server fields) | ✅ |
| 3 | R75-C03 | Desktop 1s-hover detail card left of portal row | ✅ |
| 4 | R75-C04 | Admin + worker alive = `auth=1` \|\| `status=active` only (R40-A31) | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R75-A01 | Login success returns `user_info` + `server_info` | ✅ |
| 2 | R75-A02 | Auth fail returns JSON with `error`, `status`, optional `message` / `server_info` (not bare string only) | ✅ |
| 3 | R75-A03 | Portal health cache stores full probe; `portalHealthFor` still exposes `bool?` | ✅ |
| 4 | R75-A04 | Desktop: hover portal row 1s → card left of row with status, seats, ports, timezone | ✅ |
| 5 | R75-A05 | Leave hover dismisses card; no geo/VPN claims | ✅ |
| 6 | R75-A06 | TV/leanback: no floating card; dots still green/red from probe | ✅ |
| 7 | R75-A07 | Admin Check status + worker match Rust alive rule (no `user_info != null` false green) | ✅ |
| 8 | R75-A08 | Feature docs + changelog | ✅ |

---

## Summary

Portal status dots were a boolean. Admin Check status marked portals green whenever `user_info` existed, even when `auth=0` / Banned / Expired. This slice:

1. Tighten admin/worker to the same rule as Rust (`auth=1` or `status=Active`).
2. Pass through Xtream account `status` / `message` and `server_info` (protocol, ports, timezone).
3. Desktop: after 1s hover, show a small card left of the portal row with that panel info.

**Not in API:** “needs VPN/geo.” Timezone only — never invent geo-block requirements.

### Related

- [RFC-040](../040-[open]-iptv-catalog-ops.md) — R40-A31 admin tighten
- [iptv-xtream](../../features/live/iptv-xtream.md)
- [iptv-catalog-ops](../../features/live/iptv-catalog-ops.md)
