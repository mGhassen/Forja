# 244 — Pending pack from Mac path fails on TV; no trash

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Settings → Forja Packs · cloud lean · Android TV

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 2** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I244-T01 | Pending download rows: trash (Yes/No) remove like installed packs | ✅ |
| 2 | I244-T02 | Unreachable local ForjaHQ path → official remote on install / lean apply | ✅ |
| 3 | I244-T03 | Cloud lean export never pushes absolute checkout paths | ✅ |
| 4 | I244-T04 | Unit tests + feature doc + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I244-A01 | ATV: pending Mac-path Live Sports Cards Download remaps to GitHub and installs, or trash removes the stub | ⬜ |
| 2 | I244-A02 | Desktop sync after fix exports official URL — other devices no longer receive `/Users/…` lean rows | ⬜ |

---

## Summary

Desktop installed a ForjaHQ hub from a local checkout path (`/Users/…/plugins/hubs/live_sports_cards/manifest.json`). That URL synced into cloud lean. On Android TV the pending row only had **Download**, which called `install` on the Mac path → `file not found`. No trash on pending tiles.

**Root fix:** rewrite unreachable ForjaHQ locals to the official GitHub raw manifest; skip non-ForjaHQ locals from lean import; export cloud-safe URLs only. **UX:** trash on pending download rows.
