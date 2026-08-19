# RFC-060: engineJS + Sources Forja tab

**Status:** open  
**Depends on:** [RFC-039](fixed/039-[fixed]-remote-provider-runtime-config.md) (Videasy HTTP hosts stay in-app)  
**Area:** `apps/forja/lib/shared/engine/`, `apps/forja/assets/providers/`, Sources portal, Settings Playback

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** components · **39 / 41** acceptance |
| **Current slice** | Castle AES-CBC app API, NetMirror NewTV OTT API, AniZone anime page/player, XPrime turnstile+decrypt backend, DVDPlay search+HubCloud direct extraction, 4KHDHub TMDB/domain+HubCloud flow, and batched Forja All fan-out (10 desktop / 5 TV) — remaining HTML catalogs still `catalog.js`; Flyx BingeBox/PrimeSrc/UFlix are upstream stubs; CineJoy still generic (`scrypt` PoW) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R60-C01 | `EngineJsRuntime` — own flutter_js heap, `fetch`, `streamcrypto`, `extract(ctx)` | ✅ |
| 2 | R60-C02 | `EngineJsService` — bundled Videasy pack, `engine.json` install, enabled flags | ✅ |
| 3 | R60-C03 | Sources kind `engine` labeled **Forja** (details + in-player) | ✅ |
| 4 | R60-C04 | Play source `play_source_engine_enabled` + Settings Forja plugins | ✅ |
| 5 | R60-C05 | Plugin `ctx` — opaque `config`, `imdbId`, cheerio/`crypto`, `ctx.host` | ✅ |
| 6 | R60-C06 | `kind: hop` + `ctx.hop(url)` host dispatch (not Sources chips) | ✅ |
| 7 | R60-C07 | Forja All batches selected plugins in isolated runtimes instead of a single sequential walk | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R60-A01 | Green Play / Tries / Server reliability unchanged — no `engine:*` ids | ✅ |
| 2 | R60-A02 | Sources portal shows **Forja** tab when the Forja play source is on | ✅ |
| 3 | R60-A03 | Kind id is `engine` (not `forja`); Torrents All still accepts legacy `forja` chip | ✅ |
| 4 | R60-A04 | Bundled Videasy `extract.js` uses `ctx.fetch` + `ctx.streamcrypto.decrypt` | ✅ |
| 5 | R60-A05 | Forja tab drops magnet / `.torrent` URLs | ✅ |
| 6 | R60-A06 | `nuvio_runtime.dart` and Dart `VideasyExtractor` not used by engineJS | ✅ |
| 7 | R60-A07 | Unit tests: pack parse, chip ids, kind filter Forja, Torrents `forja` All alias | ✅ |
| 8 | R60-A08 | Feature docs + changelog | ✅ |
| 9 | R60-A09 | Manual: open Sources → Forja, Videasy rows play HTTP | ⬜ |
| 10 | R60-A10 | Bundled Videasy `Promise.all`s every player.videasy.to Servers mirror (Yoru…Raze), not `cdn` only | ✅ |
| 11 | R60-A11 | Forja Videasy HTTP open stamps `player.videasy.to` Referer (`headers` + `engine:videasy` policy) | ✅ |
| 12 | R60-A12 | Bundled pack ships Vidlink, Vixsrc, DooFlix, YFlix HTTP plugins (`extract(ctx)`) | ✅ |
| 13 | R60-A13 | Forja `kind: host` plugins delegate to built-in sniff/API extractors (VSEmbed…WebStreamr) | ✅ |
| 14 | R60-A14 | Engine mapper keeps quality/language/size; card title is media `Title SxE - (year)` | ✅ |
| 15 | R60-A15 | Videasy expands HLS masters into per-rendition rows when API quality is not a resolution | ✅ |
| 16 | R60-A16 | HTTP plugins read opaque `ctx.config` from `engine.json`; remote `engine[id]` overlay deep-merges at run (arrays replace) | ✅ |
| 17 | R60-A17 | Host injects `imdbId` from `Movie` into `extract(ctx)` | ✅ |
| 18 | R60-A18 | Bundled Videasy / Vidlink / Vixsrc / DooFlix / YFlix hosts live in plugin `config`, not JS literals | ✅ |
| 19 | R60-A19 | `ctx.html` (cheerio) + `ctx.crypto` (CryptoJS façade + `streamDecrypt`) on EngineRuntime — not NuvioRuntime | ✅ |
| 20 | R60-A20 | `ctx.host(id)` resolves a built-in sniff/API extractor and returns stream rows to JS | ✅ |
| 21 | R60-A21 | Sources → Forja and Settings → Forja plugins list HTTP/JS plugins only — no `kind: host` sniff chips | ✅ |
| 22 | R60-A22 | `kind: hop` is not a Sources chip (`isExtractable` = HTTP only) | ✅ |
| 23 | R60-A23 | `ctx.hop(url)` dispatches by hostname to hop JS (`extract(ctx)` with `ctx.url`) | ✅ |
| 24 | R60-A24 | AniWorld-sized hops: doodstream, voe, filemoon, streamtape, vidmoly, vidoza, luluvdo, loadx, megakino | ✅ |
| 25 | R60-A25 | Remaining Forja 18 movie/TV plugins are `kind: http` `extract(ctx)`; `ctx.host` only on miss | ✅ |
| 26 | R60-A26 | EncDec samples, Yoruix remainder, Flyx VOD, Anivexa-API bundled as HTTP plugins (`mycima` `enabled: false`) | ✅ |
| 27 | R60-A27 | Cloudstream hops for MixDrop / StreamWish / Uqload / Mp4Upload / StreamSB | ✅ |
| 28 | R60-A28 | KissKh EncDec-compatible `kkey` in Dart + `kisskh.js` engine plugin | ✅ |
| 29 | R60-A29 | Manual: Forja tab HTTP pack + hop-resolved dood/voe rows play | ⬜ |
| 30 | R60-A30 | VidRock `extract(ctx)` encrypts item id with local passphrase AES — no `aesdec.nuvioapp.space` | ✅ |
| 31 | R60-A31 | EncDec hexa / vidcore / flixcloud / animekai are dedicated plugins (not generic `encdec.js`) | ✅ |
| 32 | R60-A32 | HiAnime MegaPlay, KickAssAnime `kaa.lt`, 2DHive, Flyx MultiEmbed, MoviesAPI vidora are dedicated `extract(ctx)` files | ✅ |
| 33 | R60-A33 | Cineby reuses Videasy STREAMCRYPTO (`videasy.js` + `cineby.at` origin); Goated is `reallyfast` SHA-256 PoW + `/api/resolve` | ✅ |
| 34 | R60-A34 | EncDec meowtv / peachify / vidsync / vidup are dedicated HTTP plugins; abyss / megaup / rapidshare / onetouchtv are hops | ✅ |
| 35 | R60-A35 | MovieBox h5 `aoneroom` search/download, MovieBlast HMAC play URLs, StreamFlix `data.json` catalog, AnimeX GraphQL+REST are dedicated `extract(ctx)` | ✅ |
| 36 | R60-A36 | VidRock GET `/api/movie/{tmdb}` and `/api/tv/{tmdb}/s/e` + AES-GCM URL decrypt (`vidrock.ru`) — not passphrase `/api/{encrypted}` | ✅ |
| 37 | R60-A37 | Castle app AES-CBC, NetMirror NewTV OTT, and AniZone anime player are dedicated `extract(ctx)` files | ✅ |
| 38 | R60-A38 | XPrime uses `enc-xprime` turnstile, `dec-xprime` decrypt, and `backend.xprime.tv` (`primebox` / `rage`) as a dedicated `extract(ctx)` plugin | ✅ |
| 39 | R60-A39 | DVDPlay searches `search.php`, matches title pages, and resolves HubCloud / PixelDrain / direct download links in dedicated `extract(ctx)` JS | ✅ |
| 40 | R60-A40 | Sources → Forja **All** runs selected plugins in batches of 10 on desktop and 5 on Android TV, and loading chips reflect the active batch only | ✅ |
| 41 | R60-A41 | 4KHDHub uses TMDB title/year, live domain discovery, `.movie-card` matching, and HubCloud page extraction in dedicated `extract(ctx)` JS | ✅ |

---

## Summary

Parallel plugin stack next to Nuvio and green Play. The engine host is `lib/shared/engine/` (`extract(ctx)` + `engine.json`; `EngineRuntime` / `EngineService`). The Sources portal gets a fourth kind tab labeled **Forja**. Builtin Dart extractors and green Play stay as they are.

## Contract

`engine.json` is a pack (one or more plugins) or a single plugin at the root. JS entry exports `extract(ctx)` (or `globalThis.extract`). Host injects `tmdbId`, `imdbId`, `type`, `season`, `episode`, `title`, `year`, `url` (hops), opaque `config` (`engine.json` ∪ remote `provider_runtime_config.engine[id]`), `fetch`, `crypto` / `html` / `host` / `hop`. `streamcrypto.decrypt` remains an alias of `crypto.streamDecrypt`.

Kind `http` runs `extract(ctx)` in QuickJS. Kind `host` still exists for `ctx.host(id)` (JS calling a built-in sniff/API extractor). Kind `hop` is internal file-host JS (`doodstream`, `voe`, …): not a Sources chip; HTTP plugins call `ctx.hop(url)` when they land on an embed host. **Sources → Forja** and **Settings → Forja plugins** list HTTP plugins only. Sniff servers stay on green Play. Play ids: `engine:<pluginId>`.

Stream rows (HTTP + host) map through `mapEngineStream`: card `title` is `Show S1E1 - (2026)`, `quality` / `language` / `audio` (only when the plugin actually has them) become `description` for Sources badges. Videasy expands HLS masters into per-rendition rows when the API label is not a resolution.

## Related

- Green Play: [RFC-004](004-[partial]-provider-registry.md) — untouched
- Nuvio Sources tab: stays — this RFC does not share that VM
