# RFC-060: engineJS + Sources Forja tab

**Status:** fixed  
**Depends on:** [RFC-039](fixed/039-[fixed]-remote-provider-runtime-config.md) (Videasy HTTP hosts stay in-app)  
**Area:** `apps/forja/lib/shared/engine/`, `apps/forja/assets/providers/`, Sources portal, Settings Playback

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 76 / 78** acceptance · **2 ⏭️** manual play QA |
| **Current slice** | Soft Movie/TV/Anime/Drama chip categories; manual play rows deferred to [Issue 188](../issues/188-[draft]-forja-engine-play-manual-qa.md) |

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
| 9 | R60-A09 | Manual: open Sources → Forja, Videasy rows play HTTP | ⏭️ |
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
| 29 | R60-A29 | Manual: Forja tab HTTP pack + hop-resolved dood/voe rows play | ⏭️ |
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
| 40 | R60-A40 | Sources → Forja **All** walks plugins sequentially on the warm singleton runtime; rows appear as each plugin finishes; the in-flight chip shows **…** for only the current plugin | ✅ |
| 41 | R60-A41 | 4KHDHub uses TMDB title/year, live domain discovery, `.movie-card` matching, and HubCloud page extraction in dedicated `extract(ctx)` JS | ✅ |
| 42 | R60-A42 | HDHub4u uses Typesense search API, live domain discovery via TVVVV domains.json, HubCloud/Pixeldrain extraction, episode filtering in dedicated `extract(ctx)` JS | ✅ |
| 43 | R60-A43 | MoviesMod uses dynamic domain from TVVVV, TMDB+IMDB title search, Driveseed extraction through hrefli bypass in dedicated `extract(ctx)` JS | ✅ |
| 44 | R60-A44 | UHDMovies uses dynamic domain from TVVVV, WordPress search, Driveseed/VideoSeed extraction in dedicated `extract(ctx)` JS | ✅ |
| 45 | R60-A45 | AllMovieLand uses TMDB title search, `AwsIndStreamDomain` player, CSRF-token playlist POST for HLS streams in dedicated `extract(ctx)` JS | ✅ |
| 46 | R60-A46 | MoviesDrive uses IMDB ID search via Typesense, live domain discovery, HubCloud extraction for movies and per-episode TV in dedicated `extract(ctx)` JS | ✅ |
| 47 | R60-A47 | CinemaCity uses DLE search, atob player script decode, season/episode folder pick, subtitle parse in dedicated `extract(ctx)` JS | ✅ |
| 48 | R60-A48 | DahmerMovies uses `a.111477.xyz` directory listing, quality filter, redirect resolve in dedicated `extract(ctx)` JS | ✅ |
| 49 | R60-A49 | Kurage resolves AniList ID via Cinemeta+TMDB sync, TRPC batch source fetch in dedicated `extract(ctx)` JS | ✅ |
| 50 | R60-A50 | ShowBox uses HF proxy + FebBox share/quality list; optional encrypted uiToken decrypt via `ctx.crypto.TripleDES` in dedicated `extract(ctx)` JS | ✅ |
| 51 | R60-A51 | CineVibe uses FNV token + `/api/stream/fetch` movie streams (movies only) in dedicated `extract(ctx)` JS | ✅ |
| 52 | R60-A52 | MalluMV uses `search.php`, confirm/internal HubCloud extraction chain in dedicated `extract(ctx)` JS | ✅ |
| 53 | R60-A53 | AnimePahe uses proxy API, MAL ID mapping, Kwik unpack + Pahe decrypt in dedicated `extract(ctx)` JS | ✅ |
| 54 | R60-A54 | ReAnime resolves AniList via Cinemeta sync, fetches FlixCloud embeds, resolves via `ctx.hop` in dedicated `extract(ctx)` JS | ✅ |
| 55 | R60-A55 | AniBD uses `epeng.animeapps.top` api2/apilink player chain with ARM AniList lookup in dedicated `extract(ctx)` JS | ✅ |
| 56 | R60-A56 | Senshi uses `senshi.live` MAL episode-embeds API with sub/dub pick in dedicated `extract(ctx)` JS | ✅ |
| 57 | R60-A57 | AnimeDunya uses `anime-dunya.com` play-page stream JSON extraction in dedicated `extract(ctx)` JS | ✅ |
| 58 | R60-A58 | AniNeko browser search + nv-server-grid HLS/embed resolve in dedicated `extract(ctx)` JS | ✅ |
| 59 | R60-A59 | AnimeGG series search + videoSources embed scrape in dedicated `extract(ctx)` JS | ✅ |
| 60 | R60-A60 | AniDbApp uses `anidb.app` frontend API + embed HLS in dedicated `extract(ctx)` JS | ✅ |
| 61 | R60-A61 | Anikoto uses `anikototv.to` ajax episode/server list + mapper.nekostream in dedicated `extract(ctx)` JS | ✅ |
| 62 | R60-A62 | AnimeNoSub uses WP ajax search, Vidmoly/Nova decrypt + hop for Byse in dedicated `extract(ctx)` JS | ✅ |
| 63 | R60-A63 | MKissa `api.mkissa.net` GraphQL with SvelteKit client-crypto bootstrap + `aaReq` AES-GCM in dedicated `extract(ctx)` JS (`mkissa.to`; captcha retries without in-app Turnstile UI) | ✅ |
| 64 | R60-A64 | BingeBox, PrimeSrc, UFlix use TMDB embed scrape via shared `embed.js` (not generic catalog search) | ✅ |
| 65 | R60-A65 | VidNest Anime reuses VidNest cipher API with anime server paths (`hianime`, `animepahe`, …) | ✅ |
| 66 | R60-A66 | MyFlixer uses TMDB title search + watch-page iframe/m3u8 scrape in dedicated `extract(ctx)` JS | ✅ |
| 67 | R60-A67 | CineJoy uses `api.shegu.st` scrypt PoW (`x-at`), enc-dec token path, and `dec-cinejoy` in dedicated `extract(ctx)` JS (`cinejoy.to`) | ✅ |
| 68 | R60-A68 | Sources → Forja **All** runs selected plugins in isolated runtimes, 10 in parallel (5 on TV); rows appear as each finishes; free slots start the next plugins until the selected set is exhausted; a plugin chip tap stays one-shot | ✅ |
| 69 | R60-A69 | Selecting more Forja plugin chips mid-search joins the 10/5 pool — it does not cancel in-flight plugins | ✅ |
| 70 | R60-A70 | Vidzee Forja plugin uses `core.vidzee.wtf/streams` plaintext `e=0` (not dead `/api/server`) | ✅ |
| 71 | R60-A71 | Forja chips **2Embed** / **111477** use `multiembed.js` / `dahmermovies.js` HTTP extract (not empty `embed.js` / `host_wrap`) | ✅ |
| 72 | R60-A72 | VidSrc.sbs Forja plugin uses balanced-bracket `CFG.servers` parse + nxsha AES `/api/servers`+`/api/sources` (Decryptor) with Videasy nest STREAMCRYPTO | ✅ |
| 73 | R60-A73 | AutoEmbed uses `autoembed.js` + `hop-cloudfabric` for `nextgencloudfabric.com`; 111477 returns `a.111477.xyz` file URLs (no redirect filter that emptied results) | ✅ |
| 74 | R60-A74 | Bundled pack drops dead Forja HTTP chips (VidFast, Cinesrc, VSEmbed, VidSrc, AutoEmbed, VidLove, 111Movies, MoviesAPI, VidAPI, WebStreamr) | ✅ |
| 75 | R60-A75 | Bundled HTTP plugins tag `types` as movie/tv, anime, or drama (`engine.json` 1.5.8+) | ✅ |
| 76 | R60-A76 | Sources → Forja soft-hides off-category chips; Filters → Category can add Movie / TV / Anime / Drama without hard-blocking extract | ✅ |
| 77 | R60-A77 | Settings → Forja plugins groups toggles by Movie & TV / Anime / Drama | ✅ |
| 78 | R60-A78 | Bundled PlayIMDb HTTP plugin (`playimdb.js`, vaplayer API, `engine.json` 1.5.9+) | ✅ |

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
- Manual play QA (R60-A09, R60-A29): [Issue 188](../issues/188-[draft]-forja-engine-play-manual-qa.md)
