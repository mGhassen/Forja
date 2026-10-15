# 144 — IPTV catalog channel health never updates on re-check

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** IPTV catalog · live channel cards · in-player guide

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** fix · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I144-T01 | Catalog lazy health: 2‑min TTL + stale-while-revalidate (keep last border until re-probe) | ✅ |
| 2 | I144-T02 | In-player channel guide: same TTL freshness gate | ✅ |
| 3 | I144-T03 | In-player guide: probe on TV paint-focus (`didUpdateWidget`), not MouseRegion-only | ✅ |
| 4 | I144-T04 | Drop TTL skip — every hover/focus dwell re-probes; border/dot updates when alive/dead flips | ✅ |
| 5 | I144-T05 | Restore 2‑min freshness skip (T01) — re-hover must not wait on CDN; skip probes while player surface active; Stalker create_link only when stale | ✅ |
| 6 | I144-T06 | Red/miss never counts as fresh — re-hover re-probes and can flip green (`isFresh` only when alive) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I144-A01 | Hover/focus a live channel → green; after TTL expires, kill the feed → re-hover/focus → border/dot turns red | ⬜ |
| 2 | I144-A02 | First-time check on a sibling channel still goes red/green correctly while a prior green card stays fresh | ⬜ |
| 3 | I144-A03 | Android TV: ↑/↓ on in-player guide channel list shows green/red status after debounce; red re-dwell can flip green | ⬜ |
| 4 | I144-A04 | Catalog: hover a red channel → feed recovers → re-hover → border/dot turns green (no 2‑min wait) | ⬜ |

---

## Summary

Live catalog cards probe on hover/focus and tint the border green/red. After the first result, `streamHealth.containsKey` skipped forever for the session — a later probe never refreshed the card even when the stream flipped.

**Root fix (T01–T03):** Same **2‑minute** freshness window as portal status dots. Stale entries stay painted until the new probe lands, then the border updates. In-player guide uses the same TTL. Guide rows probe on TV paint-focus.

**Follow-up (I144-T04):** TTL still left a green card stuck until expiry while first-time checks on other channels correctly went red after the portal died. Catalog + guide briefly **re-probed on every dwell** (350ms debounce, in-flight dedupe, TV `onlyThis` queue trim). Last color stays until the new result lands; `notifyListeners` / `setState` only when the value flips.

**Follow-up (I144-T05):** Every-dwell re-probe made catalog hover hang (CDN wait up to ~8s) on Xtream/Stalker/M3U. Restored **2‑min freshness** for **alive** results — green border/dot skips create_link + probe; stale dwell re-checks and can flip. Catalog host also no-ops while `playerSurfaceActive`.

**Follow-up (I144-T06):** `isFresh` treated red misses like alive, so a dead channel stayed red for the full TTL and never flipped green on re-hover. Alive-only freshness — red always re-probes.

## Related

- [iptv-xtream](../../features/live/iptv-xtream.md) — catalog live health
- Portal status TTL — `iptv_controller_browser.dart` `_portalHealthTtl` (unchanged — portals still use 2‑min cache)
