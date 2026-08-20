# 188 — Forja engine tab manual play QA

**Priority:** P2  
**Severity:** Medium  
**Status:** draft  
**Area:** Sources → Forja, `apps/forja/lib/shared/engine/`, player playback  
**Depends on:** [RFC-060](../rfc/fixed/060-[fixed]-enginejs-sources-forja-tab.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 2** verification |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I188-A01 | Manual: Sources → Forja — Videasy HTTP rows open and play | ⬜ |
| 2 | I188-A02 | Manual: Forja HTTP pack + hop-resolved dood/voe rows open and play | ⬜ |

---

## Summary

[RFC-060](../rfc/fixed/060-[fixed]-enginejs-sources-forja-tab.md) provider migration is shipped (`engine.json` 1.5.2, dedicated `extract(ctx)` plugins, hops). Automated pack/tests pass; in-app play for representative HTTP + hop paths was never run on device.

Deferred RFC rows: **R60-A09**, **R60-A29**.

## How to verify

1. Settings → Playback → enable **Forja** play source.
2. Open a known-good title (movie + TV episode).
3. Sources → **Forja** tab → pick **Videasy** (or **All** and wait for Videasy row) → play. Confirm HLS starts with Referer policy (no immediate 403).
4. Repeat with a plugin that returns a dood/voe embed URL resolved via hop (e.g. MalluMV / CinemaCity chain) — confirm hop row plays in player.

## Related

- [stream-providers.md](../features/sources/stream-providers.md)
- RFC-060 R60-A09 · R60-A29 (⏭️ deferred here)
