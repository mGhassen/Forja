# RFC-008: Watch party

**Version:** v1.2+  
**Status:** Placeholder (disabled button in player)

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

## Acceptance (v1.2+)

- [ ] 2+ clients stay within ±2s on LAN
- [ ] Host pause pauses all guests
- [ ] Room closes when host leaves
- [ ] Internet party scoped to Phase B if shipped

## Related

RFC-007 (LAN WebSocket), RFC-006 (optional auth for friend lists later)
