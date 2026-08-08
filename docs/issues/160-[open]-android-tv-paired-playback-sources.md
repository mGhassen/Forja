# 160 — Android TV: Playback torrent/Stremio/Nuvio after LAN pair

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Settings → Playback · media details Sources · LAN

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 3** acceptance |

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

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I160-A01 | Physical ATV: pair desktop → Settings → Playback shows torrent/Stremio/Nuvio; enable Direct torrent → details white Play + Sources panel | ⬜ |
| 2 | I160-A02 | Unpaired ATV: Playback still Webstreaming-only; synced phone prefs do not reopen torrent/Stremio/Nuvio | ⬜ |
| 3 | I160-A03 | Paired ATV: desktop offline → torrent/Stremio/Nuvio off + disabled; desktop online again restores prior checks | ⬜ |

---

## Summary

1.3.24 hard-hid Direct torrent / Stremio / Nuvio on Android TV (`PlaybackProfile.androidTv` + `isPlaySource*Enabled` always false). LAN pairing (RFC-022) was meant to expose desktop-relay Sources, but Settings toggles keyed off caps only and details `loadPlaySources` never OR’d pairing — so after pair the white Play / torrent panel stayed dead.

**Root fix:** host `PlaySourceEffective` — unpaired ATV stays off; paired ATV shows Playback toggles and honors stored prefs for boot, Settings, details, and in-player Sources. Lean hub tiles (Sources / Debrid / WebStreamr) stay hidden.

## Related

- [RFC-022](../rfc/022-[open]-lan-server-client.md)
- [026](026-[open]-lan-stream-playback-bearer-token.md)
- [LAN](../features/settings/lan.md)
- [Playback settings](../features/settings/playback-settings.md)
