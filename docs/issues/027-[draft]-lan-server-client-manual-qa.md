# 027 — RFC-022 LAN server/client manual QA matrix unverified

**Status:** draft  
**Priority:** P2  
**Severity:** Medium  
**Area:** `apps/forja`, `crates/lan`, QA

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 10** verification |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I27-A01 | R22-A01 — mDNS discover; no typed IP | ⬜ |
| 2 | I27-A02 | R22-A02 — manual IP:port pair when mDNS blocked | ⬜ |
| 3 | I27-A03 | R22-A03 — one-time code; reuse rejected | ⬜ |
| 4 | I27-A04 | R22-A04 — reconnect without code prompt | ⬜ |
| 5 | I27-A05 | R22-A05 — revoke forces re-pair | ⬜ |
| 6 | I27-A06 | R22-A06 — direct URL plays with server off | ⬜ |
| 7 | I27-A07 | R22-A07 — proxy-gated source via desktop relay | ⬜ |
| 8 | I27-A08 | R22-A08 — torrent via desktop; Android TV local opt-in | ⬜ |
| 9 | I27-A09 | R22-A09 — debrid resolves direct without server | ⬜ |
| 10 | I27-A10 | End-to-end: macOS server + Android phone same Wi‑Fi | ⬜ |

---

## Summary

RFC-022 acceptance rows R22-A01–A09 and the primary ship smoke (desktop server + phone client) are **not verified**. Code may land without manual QA; this issue tracks verification only.

**Prerequisite:** [026](026-[open]-lan-stream-playback-bearer-token.md) for A07/A08 stream playback.

## Test matrix (reference)

| Setup | Action | Pass |
|-------|--------|------|
| Desktop | Enable LAN server; note code | Code visible, `/health` 200 on LAN |
| Phone | Discover or manual IP → pair | Token stored; `/devices` lists device |
| Phone | Play WebStreamr title, server off | Direct play |
| Phone | Play torrent title, server on | Stream from desktop URL |
| Desktop | Revoke phone | Phone must re-pair |
| Phone | Relaunch app | No code prompt if token valid |

## Related

- [RFC-022](../rfc/022-[draft]-lan-server-client.md)
- [026](026-[open]-lan-stream-playback-bearer-token.md)
