# 433 — FCTV33 standalone Live Sports catalog + resolve

**Priority:** P1  
**Severity:** Medium  
**Status:** open  
**Area:** `forja-packs/livesports/` — new plugin (TCPWE / MadPlay family)  
**Reported:** 2026-10-14  
**Related:** [432](fixed/432-[fixed]-bzhsport-xstream-streamurls-missed.md) (BZH Lecteur 1 / jack embed)

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** research · **4 / 4** implement · **0 / 2** acceptance (device) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Research tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I433-T01 | Confirm FCTV33 = same Nuxt/TCPWE stack as MadPlay/jack (`apis-data*`, `statics1.tcpwe*`) | ✅ |
| 2 | I433-T02 | Reverse `/api/common/bs` body signatures + `sfver` = `sfver` + MD5(JSON params)[:6] + sig | ✅ |
| 3 | I433-T03 | ROT47 decrypt `/api/common/params` + stream URL `Decipher` (slice 8) | ✅ |
| 4 | I433-T04 | `/api/match/detail?stream=true` returns match meta (signed); browser while live also fills `cStreamList` | ✅ |
| 5 | I433-T05 | Catalog: `/api/match/live?sportType=&language=0&stream=true` — works from scripted fetch (no site CF banner; wrong params were the failure) | ✅ |
| 6 | I433-T06 | Resolve: `/api/stream/detail` (unsigned) → ROT47 slice8 → AES-CBC `token-` + player-domain Referer → live m3u8 | ✅ |
| 7 | I433-T07 | Ship `fctv33.js` catalog+resolve + manifest (clone streamfree) | ✅ |

---

## Fix / implement tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I433-T08 | Catalog path that works from pack `ctx.fetch` (CF bypass or alternate feed) | ✅ |
| 2 | I433-T09 | Parse protobuf `PBMatchLiveResp` / stream list fields without browser | ✅ |
| 3 | I433-T10 | Unlock each `streamId` → live `mil` m3u8 | ✅ |
| 4 | I433-T11 | Pack version + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I433-A01 | Live Sports schedule shows FCTV33 matches in the window | ⬜ |
| 2 | I433-A02 | Providers lists named channels (Movistar / BE / …) that play natively | ⬜ |

---

## Summary

User asked for **FCTV33 as a full catalog+resolve** instead of unlocking jack Lecteur 1 inside BZH. Same product family; better shape.

## Blockers (verified)

1. ~~CF on `/api/match/live`~~ — **cleared**. Site has no CF interstitial. Scripted fetch works with `language=0&stream=true` (+ optional `/api-cf/common/timesync` + `/api-cf/user/info`). Wrong language / missing `stream=true` was what looked like CF.
2. ~~Stream unlock~~ — **cleared** end-to-end (scripted `stream/detail` → ROT47 → AES `token-` → `#EXTM3U` with player-domain Referer).
3. **No embed fallback** — native m3u8 only ([no-embed law](../../.cursor/rules/no-embed-playback.mdc)).

## Shipped

- `forja-packs/livesports/fctv33.js` + manifest plugin `fctv33` (pack `2.0.31`)
- Local install: `/Users/mghassen/Workspace/forja-packs/livesports/manifest.json`

## Protocol notes (for implementer)

| Piece | Detail |
|-------|--------|
| API base | `https://apis-data-defra10.tcpwe138stya.ru` (also `apis-data10…`) |
| Brand digit | jack/MadPlay page used `seth`; FCTV33 brands use `foth` in `g_player_domains` / `common:web:sw2` |
| Handshake | `GET /api-cf/common/timesync` + `/api-cf/user/info` (204) before live |
| `bs` | `GET /api/common/bs?code=100&sportType=&stream=true` → protobuf map code→32-hex sig (`100`=live, `101`=schedule, `102`=detail). Multi-code: `code=102&code=103&…` |
| `sfver` | `sfver` + `md5(JSON.stringify(orderedParams)).slice(0,6)` + sig; param key order: matchId, leagueId, seasonId, sportType, language, stream |
| Catalog | `/{sfver}/api/match/live?sportType=1&language=0&stream=true` — protobuf list + `streamList` (playable matchIds) |
| Match streams | `/{sfver}/api/match/detail?matchId=&sportType=&language=0&stream=true` — channel names + `streamId`s |
| Stream unlock | **`/api/stream/detail` has no `sfver`** (path not in V map). Params: `streamId,matchId,sportType,language,continent,country,digit,siteType,usls=rbp` (omit any → 499). Response header `rb-session`; body `stream.url` ROT47 then `.slice(8)` → plain m3u8 path; backup domains same cipher |
| Play URL | `origin + '/token-' + encodeURIComponent(AES-CBC(rb-session)) + 'a' + pathname` |
| AES token | key `atob(YTc5…ODk=)` → Utf8 `a7981cc9eb2f4d19dcfea57b101ecd89`; iv `atob(ODAx…)` → `8017d3a8f1400d2f` (CryptoJS Utf8.parse) |
| CDN Referer | Must be a `g_player_domains` host (e.g. `nadia*.…cfd`), not the jack site origin — else 403 |

## Non-goals

- WebView / embed playback of FCTV33 pages  
- Bolting jack unlock into `bzhsport.js` as the long-term fix (BZH keeps zonalive/xstream)
