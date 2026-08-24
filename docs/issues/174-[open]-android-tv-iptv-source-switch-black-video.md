# 174 — Android TV IPTV: source/channel switch leaves black video

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · IPTV player · source / channel switch

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I174-T01 | ATV source/channel change: hard reseat same engine (unmount → release → cool-down → boot) before open; loading scaffold + `Switching to …` banner | ✅ |
| 2 | I174-T02 | Open serialization: latest epoch wins so rapid Source taps do not drop the new URL after awaiting an in-flight open | ✅ |
| 3 | I174-T03 | Channel-zap reseat banner uses channel name (not portal `displayLabel`); Source/failover still use source label | ✅ |
| 4 | I174-T04 | Channel zap with guide/search open: keep overlay mounted — in-place switching surface instead of full `!_playerReady` scaffold (scaffold remount flashed the rail and reset TV second-OK close arm) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I174-A01 | Android TV IPTV: playing stream A → pick another Source — spinner + “Switching to …” then picture on the new URL (no need to change Player) | ⬜ |
| 2 | I174-A02 | Android TV IPTV: zap channel in the guide — same reseat; video returns without Player menu swap | ⬜ |
| 3 | I174-A03 | Android TV IPTV: zap in open channel guide — rail stays up (no hide/show flash); first OK tunes, second OK closes | ⬜ |

---

## Summary

On Android TV, changing IPTV **Source** (or channel) only did a soft `ExoPlayerBridge.open` / `Player.open` on the live engine. MediaCodec / TextureView / `mediacodec_embed` often stayed bound to the previous stream — audio or chrome OK, **black picture**. Switching **Player** (Exo ↔ MediaKit) worked because it already tore down and remounted.

**Root fix:** on ATV only, source/channel (and recovery source-rotate) call the same reseat path as engine switch, staying on the current backend. UI reuses the existing `!_playerReady` loading scaffold plus status banner — not a separate loading route. Desktop/phone keep soft reopen.

Also fixed `_openCurrent` serialization: waiting for an in-flight open used to `return` without applying the newly selected source.

Channel zap initially reused the Source-failover banner text (`sources[].label` = portal `displayLabel`). **I174-T03** passes the channel name into the reseat banner; Source menu / retry rotation keep the portal label.

**Guide flash (I174-T04):** T01’s full-scaffold swap on every channel zap unmounted `IptvChannelGuidePanel`. Users saw the rail hide and return, and TV’s “first OK tunes / second OK closes” arm reset — closing needed a third OK. When guide or search is open, reseat keeps the player Stack and only replaces the video slot with the switching spinner.

---

## Related

- [128](128-[open]-android-tv-iptv-mediakit-exit-anr.md) — soft reopen / ANR trade-offs that motivated avoiding recreate on every reload
- [133](133-[open]-android-tv-exo-physical-audio-only.md) — ATV Exo surface / TextureView
