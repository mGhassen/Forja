# 160 — Android TV: Playback torrent/Stremio/Nuvio after LAN pair

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Settings → Playback · media details Sources · LAN

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 8** fix · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I160-T01 | `PlaySourceEffective` — ATV unpaired hard-off; paired honors stored toggles | ✅ |
| 2 | I160-T02 | Settings → Playback show Direct torrent / Stremio / Nuvio when LAN paired | ✅ |
| 3 | I160-T03 | Details `loadPlaySources` + panel gates use effective flags (white Play + Sources) | ✅ |
| 4 | I160-T04 | Invalidate Settings visibility / playback snapshot after pair / unpair | ✅ |
| 5 | I160-T05 | Paired + desktop offline → effective off + toggles disabled; restore stored when online | ✅ |
| 6 | I160-T06 | Unpaired ATV shows Direct torrent / Stremio / Nuvio; HTTP plays on device | ✅ |
| 7 | I160-T07 | P2P / magnet play on ATV: pair dialog if unpaired or desktop offline; paired P2P stays on desktop | ✅ |
| 8 | I160-T08 | In-player Sources torrent / Stremio magnet switch: pair dialog before dismiss/resolve (same gate as details Play) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I160-A01 | Physical ATV unpaired: Settings → Playback shows torrent/Stremio/Nuvio; enable → details white Play + Sources; HTTP Stremio/Nuvio row plays on TV | ⬜ |
| 2 | I160-A02 | Unpaired ATV: pick a torrent / magnet → pair dialog (Open LAN); cancel does not start P2P on the TV | ⬜ |
| 3 | I160-A03 | Paired ATV + desktop online: magnet plays via desktop; HTTP Stremio/Nuvio still plays on the TV (not relayed) | ⬜ |
| 4 | I160-A04 | Paired ATV + desktop offline: HTTP still plays; magnet shows desktop-offline dialog | ⬜ |

---

## Summary

1.3.24 hard-hid Direct torrent / Stremio / Nuvio on Android TV (`PlaybackProfile.androidTv` + `isPlaySource*Enabled` always false). LAN pairing (RFC-022) was meant to expose desktop-relay Sources, but Settings toggles keyed off caps only and details `loadPlaySources` never OR’d pairing — so after pair the white Play / torrent panel stayed dead.

**T01–T05 (historical):** host `PlaySourceEffective` — unpaired ATV stayed off; paired ATV showed Playback toggles and honored stored prefs.

**T06–T07:** unpaired ATV now shows the same play sources. Direct HTTP plays on the TV. Magnets / infoHash still need a paired desktop (`ensureLanP2pPlayback` + pair dialog). Paired P2P stays on the desktop; HTTP is never sent through LAN.

**T08:** in-player Sources dismissed the panel then started magnet resolve. Unpaired ATV hit “Starting Local Torrent Engine” instead of the pair dialog. Gate is now in `_selectTorrent` / Stremio magnet `_selectStremio` before dismiss.

## Related

- [RFC-022](../rfc/022-[open]-lan-server-client.md)
- [026](026-[open]-lan-stream-playback-bearer-token.md)
- [LAN](../features/settings/lan.md)
- [Playback settings](../features/settings/playback-settings.md)
