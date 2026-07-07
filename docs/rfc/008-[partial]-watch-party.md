# RFC-008: Watch party

**Version:** v1.2+  
**Status:** stub — placeholder (disabled button in player)  
**Target version:** v2 (Diwan & mer)  
**Depends on:** RFC-007 (LAN WebSocket)  
**Area:** player overlay Watch Party button (disabled)

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 4** acceptance (v1.2+ slice) |
| **Current slice** | v1.2 — LAN-first group playback |
| **Backlog** | v2 |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Acceptance (v1.2+)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R08-A01 | 2+ clients stay within ±2s on LAN | ⬜ |
| 2 | R08-A02 | Host pause pauses all guests | ⬜ |
| 3 | R08-A03 | Room closes when host leaves | ⬜ |
| 4 | R08-A04 | Internet party scoped to Phase B if shipped | ⬜ |

---


## Summary

Synchronized group viewing: shared stream URL, playback position, and play/pause state.

## MVP scope (v1.2)

**LAN-first:** host creates room; guests join via code on same Wi-Fi.

## Signaling options

| Phase | Transport | Pros |
|-------|-----------|------|
| A | LAN WebSocket (RFC-007 infra) | No cloud; low latency |
| B | Supabase Realtime | Internet parties |
| C | Dedicated signaling server | Scale |

Recommend Phase A first; reuse LAN companion WebSocket.

## Sync model

Host authoritative:

```json
{
  "roomId": "abc123",
  "streamUrl": "https://...",
  "positionMs": 120000,
  "playing": true,
  "updatedAt": "2026-07-05T..."
}
```

Guests apply host state; drift correction every 5s or on pause.

**Not synced in v1.2:** provider switching mid-party (host-only), subtitles preference.

## Player UX

- Overlay: Watch Party button (currently disabled / "Coming soon")
- Flow: Host → Create room → share code → guests Join → host picks title → all play


## Related

RFC-007 (LAN WebSocket), RFC-006 (optional auth for friend lists later)
