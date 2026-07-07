# RFC-007: LAN companion API

**Version:** v1.2  
**Status:** draft  
**Target version:** v2 (Diwan & mer)  
**Area:** `packages/streaming/lib/src/local_server_service.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 4** acceptance (v1.2 slice) |
| **Current slice** | v1.2 — LAN remote control API |
| **Backlog** | v2 |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Acceptance (v1.2)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R07-A01 | Pair from second device on same network | ⬜ |
| 2 | R07-A02 | Play/pause/seek remote control works | ⬜ |
| 3 | R07-A03 | Server stops when disabled in settings | ⬜ |
| 4 | R07-A04 | No exposure when feature off | ⬜ |

---

## Summary

Extend the local HTTP server so a paired phone/browser can remote-control playback on a TV/desktop Forja instance.

## Base

`packages/streaming/lib/src/local_server_service.dart` — already serves HLS proxy for playback.

## Extensions

- Bind `0.0.0.0:<port>` on LAN (configurable; default off)
- Pairing: 6-digit code or QR containing `{ host, port, token }`
- Token stored in secure prefs; rotate on unpair

## REST endpoints (draft)

| Method | Path | Body | Response |
|--------|------|------|----------|
| GET | `/api/status` | — | `{ playing, title, position, duration, provider }` |
| POST | `/api/playback/play` | `{ url?, position? }` | 200 |
| POST | `/api/playback/pause` | — | 200 |
| POST | `/api/playback/seek` | `{ positionMs }` | 200 |
| GET | `/api/settings/{domain}` | — | JSON payload |
| PATCH | `/api/settings/{domain}` | JSON | 200 |

## WebSocket

Channel: `/ws/playback`

Events: `state`, `position`, `provider_changed` (host → clients).

## Security

- HTTPS optional (self-signed cert for LAN)
- Token required on all endpoints except `/api/pair` (exchange code for token)
- Auto-disable when app backgrounded (configurable)

## UI

Settings → Remote → Enable LAN companion → show QR + code.
