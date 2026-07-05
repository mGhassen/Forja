# RFC-007: LAN companion API

Extend `LocalServerService` to bind LAN interface with pairing token.

Endpoints (draft):

- `GET /api/status`
- `POST /api/playback/{play,pause,seek}`
- `GET/PATCH /api/settings/{domain}`

WebSocket for realtime state.
