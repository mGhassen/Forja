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
| **Progress** | **8 / 8** research · **11 / 11** implement · **0 / 2** acceptance (device) |

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
| 8 | I433-T18 | Native play: playlist `#EXTM3U` OK; segments `.json` → 302 `streambk*` → `487 Not Acceptable (Wtl108)` for curl/Node/Python/wreq Chrome137; real Chromium on player origin returns `200 video/mp2t` | ✅ |

---

## Fix / implement tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I433-T08 | Catalog path that works from pack `ctx.fetch` (CF bypass or alternate feed) | ✅ |
| 2 | I433-T09 | Parse protobuf `PBMatchLiveResp` / stream list fields without browser | ✅ |
| 3 | I433-T10 | Unlock each `streamId` → live `mil` m3u8 | ✅ |
| 4 | I433-T11 | Pack version + changelog | ✅ |
| 5 | I433-T12 | Engine `pack_http_envelope`: keep raw bytes for invalid UTF-8 / protobuf (mislabelled `application/json`) | ✅ |
| 6 | I433-T13 | Pack `readVarint` 53-bit safe so `dateMs` is not 2003-era after stamp | ✅ |
| 7 | I433-T14 | CryptoJS `AES.encrypt(WordArray key)` must return `.ciphertext` (resolve token) | ✅ |
| 8 | I433-T15 | Catalog: one `bs` sig + 429 retry (per-sport bs double-scrape → raw=0) | ✅ |
| 9 | I433-T16 | Hub/host: Catalog chip after All must not poison `raw:<chip>` / skip scrape when scoped empty | ✅ |
| 10 | I433-T17 | Catalog airing: status>0 or kickoff passed (not only 101); sportTypes 9–12 (curling/NHL/…) | ✅ |
| 11 | I433-T19 | Native MediaKit play — pack `playbackHop: 'browserFetch'` → host `BrowserFetchHlsProxy` tool (no host CDN matching) | ✅ |

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
4. ~~Catalog `raw=0` (protobuf UTF-8)~~ — **cleared**. Envelope bodyB64 + pack varint. Device: `raw=191`.
5. ~~Resolve `raw=0`~~ — **cleared in code**. CryptoJS WordArray AES missing `.ciphertext`. Needs device A02 after rust rebuild.
6. ~~Catalog flaky `191 → 131 → 0`~~ — **cleared in code** (verified scripted). `/api/common/bs` returns **429** under per-sport bs × concurrent chip scrape. Fix: one code-100 sig for all sports + retry on 429. Pack `2.0.34`.
7. ~~Chip empty after HubReload/All~~ — **cleared in code**. Pack stashed All rows under `raw:fctv33` then reduce → 0; host trusted non-empty warm. Hub `1.0.66` + host progressive scoped warm / scrape-by-id fallback. Device A01 still open.
8. ~~Airing only Barranquilla~~ — **cleared in code** (API verified). Site Live uses status `101/103/600` + kickoff-passed `0`; pack only set `airing` for `101`. Also missing sportTypes 9–12 (curling). Pack `2.0.35`.
9. ~~**Native segment fetch (Wtl108)**~~ — **cleared in code**. Pack opts in with `playbackHop: 'browserFetch'`; host tool `BrowserFetchHlsProxy` fetches on player origin → loopback HLS. MediaKit plays local only (not sniff / not WebView playback). Pack `2.0.37`. Device A02 still open.

## Shipped

- `forja-packs/livesports/fctv33.js` + manifest plugin `fctv33` (pack `2.0.37`, `playbackHop: browserFetch`)
- Host tool `LivePlaybackHop.browserFetch` → `BrowserFetchHlsProxy` (pack-declared; no CDN host list)
- Engine envelope binary body keep (invalid UTF-8 / protobuf CT)
- Engine/Dart CryptoJS AES WordArray → CipherParams `.ciphertext`
- Hub feed chip-after-All scoped only (`hubs/live_sports` `1.0.66`) + host progressive warm guard
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
| Segment CDN | Playlist relative `*.json?_ctump=…` under `/hedy/sx_<streamId>/`. Primary `fhlsport*` serves TS to Chromium; non-browser clients get 302 → `streambk*` → `rb-message: Not Acceptable (Wtl108)`. Web player on 4xx+`rb-session` reloads CSI (`isShouldFixRbSession`) — re-sign alone does not clear Wtl108 from scripted clients. |

## Non-goals

- WebView / embed playback of FCTV33 pages  
- Bolting jack unlock into `bzhsport.js` as the long-term fix (BZH keeps zonalive/xstream)
