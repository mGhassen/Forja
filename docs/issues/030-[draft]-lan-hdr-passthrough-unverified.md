# 030 — LAN HDR/DV passthrough relay unverified (R22-A10)

**Status:** draft  
**Priority:** P3  
**Severity:** Low  
**Area:** `crates/lan`, player, QA

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 1** verification |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I30-A01 | Relayed 4K HDR / Dolby Vision stream on capable LAN client plays without server-side re-encode | ⬜ |

---

## Summary

RFC-022 R22-A10 requires passthrough relay (no transcode) for HDR/DV/Atmos over LAN. Architecture is byte-forward / remux-only when needed — **no dedicated HDR LAN code path**. Acceptance is a **manual smoke** on a known HDR source after core LAN playback works.

**Does not block:** pairing, routing, or SDR playback.

**Prerequisite:** [026](026-[open]-lan-stream-playback-bearer-token.md), [027](027-[draft]-lan-server-client-manual-qa.md) torrent path green.

## Related

- [RFC-022](../rfc/022-[draft]-lan-server-client.md) R22-A10, R22-C06, §6
