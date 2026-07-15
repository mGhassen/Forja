# 028 — Desktop as LAN client not implemented (RFC-022 §3)

**Status:** draft  
**Priority:** P2  
**Severity:** Medium  
**Area:** `apps/forja/lib/shared/lan`, `apps/forja/lib/features/settings`, `packages/rust/lib/src/playback/platform/playback_profile.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I28-T01 | Settings: show LAN **client** UI on desktop (discover / manual IP / pair), not server-only | ⬜ |
| 2 | I28-T02 | Routing: `LanPlaybackRouter.shouldPreferDesktop` must not blanket-false all `canRunServer` platforms; distinguish local server vs paired remote | ⬜ |
| 3 | I28-T03 | Optional `PlaybackProfile` or setting: desktop-as-client to remote Mac/PC | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I28-A01 | Laptop/desktop pairs to another desktop LAN server and plays torrent via `/open` | ⬜ |
| 2 | I28-A02 | Same machine can run server **or** client to remote server (not both required simultaneously) | ⬜ |

---

## Summary

[RFC-022](../rfc/022-[draft]-lan-server-client.md) §3 and routing table row **“Desktop (client to another server)”** require a desktop to pair to a remote desktop and consume relayed streams.

Current design intent in code:

- `LanPlaybackRouter.shouldPreferDesktop` returns `false` when `LanServerService.canRunServer` (any win/mac/linux) — remote LAN never used for playback routing
- `LanSettingsSection` shows client controls only when `!canRunServer` (mobile); desktop gets server toggle only
- `PlaybackProfile.desktop` has `preferDesktopServer: false`

**Not in scope:** phone-as-server (RFC non-goal).

## Related

- [RFC-022](../rfc/022-[draft]-lan-server-client.md) §3, §4.2
- [026](026-[open]-lan-stream-playback-bearer-token.md)
