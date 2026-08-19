# Stream providers

> Domain-scoped source engines pick scrapers; the player only sees playable streams.

## What it is

Forja resolves streams through the **Rust Resolver Engine** (`crates/resolver-engine`). Movie/TV scrapers never compete with anime or Asian Drama scrapers. Each domain has provider **profiles** (configured domain scores). Your **settings order** is the baseline; domain scores plus a **live reliability Σ** (sum of per-title check scores for that provider, clamped ±20 when ranking) may adjust each provider by at most **±2** ranks before checking. The engine scores resolved URLs against your device (codec, resolution, latency) and returns a **playable URL + headers** — the player does not know which scraper produced it.

Movie/TV embed **URL templates**, WebStreamr **bases**, anime **hosts / APIs / mirrors**, **CDN Referer rules**, and **per-anime-sourceKey playback profiles** (probe mode + PNG-strip hosts) can be overlaid from cloud `provider_runtime_config` (RFC-039) so ops can retarget URLs and anime probe behavior without shipping a new build — edit in Admin → **Providers** (flat tables, or JSON for advanced edits). Extract logic (decrypt, Cloudflare pipes, WebView sniff) still ships in the app.

Green **Play** calls `PlaybackService.resolve()` → Resolver Engine job. Host-only providers (WebView embed sniff, Videasy WASM, Nuvio) are fulfilled by a host adapter after the engine requests them.

Built-in **webstreaming** movie/series providers include Videasy, VSEmbed, VidSrc, VidSrc.sbs, VidLink, VixSrc, Vidnest, Vidzee, VidRock, VidFast, 2Embed, AutoEmbed, VidLove, 111Movies, MoviesAPI, VidAPI, 111477, and WebStreamr. [Nuvio](../scrapers/nuvio.md) scrapers are **not** in this list — they live in the **Sources** panel under **Direct torrent**.

**How providers resolve:**

| Type | Providers | Mechanism |
|------|-----------|-----------|
| Direct extractors | Videasy, VSEmbed, Vidnest | Videasy: `api.speedracelight.com` + STREAMCRYPTO decrypt (WebView or native Dart) (+ Servers-tab sniff fallback); VSEmbed: legacy HTML chain then `vsembed.su` WebView sniff; VidNest: `new.vidnest.fun` API (+ sniff fallback) |
| Embed + WebView sniff | VidSrc, VidLink, VixSrc, Vidzee, VidRock, VidFast, 2Embed, AutoEmbed, VidLove, VidSrc.sbs, 111Movies, MoviesAPI, VidAPI | Canonical embed URL → Resolver `HostRequired` → headless WebView captures stream (desktop/mobile) |
| Aggregator / index | WebStreamr, 111477 | Multi-scraper resolve or index match + local proxy |

**Sources → Forja tab** (separate from green Play) runs bundled `extract(ctx)` HTTP plugins in QuickJS: Videasy, Cineby (same STREAMCRYPTO network, `cineby.at` Referer), Goated (`goated.cx` / reallyfast PoW), VidLink, VixSrc, DooFlix, YFlix, VidNest cipher, VidRock (`vidrock.ru` AES-GCM, not the remote decrypt host), VidFast EncDec, VidSrc.sbs, Cinesrc, Hexa, VidCore, MeowTV, Peachify, VidSync, VidUp, MovieBox (`h5-api.aoneroom.com`), MovieBlast, StreamFlix, AnimeX, MoviesAPI vidora, HiAnime MegaPlay, KickAssAnime, 2DHive, MultiEmbed/2embed, template embeds, remaining EncDec/Yoruix/Anivexa HTML catalogs, and KissKh. File-host pages (Doodstream, VOE, Filemoon, MixDrop, FlixCloud, Abyss/Hydrax, MegaUp, Rapidshare, …) are internal **hops** — not chips; a plugin that lands on those URLs calls `ctx.hop(url)` before listing a row. HTTP miss still falls back to the built-in sniff extractor via `ctx.host`. Green Play / Tries sniff is unchanged. MyCima ships in the pack but stays off (Arabic is out of the product tabs). CineJoy stays on the generic EncDec scrape until local `scrypt` PoW exists.

## How to open it

**Settings → Sources → Server reliability** — Movies / Series / Anime / Asian Drama tabs with live **Score** and Auto **Tries** order.

**In player → Servers** — pick **Auto** (default) or pin a specific server. Stream rows show a language flag when the title encodes a region/language. WebView sniff loads embeds inside an iframe by default (some providers still force a direct load).

## What you can do

- **Auto** — Resolver Engine (details **Play**) and in-player Auto try providers in **effective score order**, one step at a time until one **works**: extract → HTTP reachability probe → mpv open/decode. Host providers (VidLink, Videasy, …) are not raced in parallel — Rust pauses for the next host, Flutter fulfills it, then the race resumes at the next provider. If a **cached** list goes dead after siblings fail, Forja drops the cache and runs that full score-order resolve again (same as first Play). If the stream **dies mid-watch** (CDN drop, fatal open error after play started), Auto tries remaining mirrors for that server, then re-resolves like first Play, and seeks back to where you were.
- **Manual** — on the loading screen, open the server list (layers icon next to **Cancel**) and tap a provider to check it now; or in the player pick a server / stream (or turn Auto server Off). Forja stays on that pick — **no** silent cross-provider/stream hop on fail. Switching providers mid-check starts the new one immediately (only one Source-panel spinner at a time); if the previous sniff had already found a playable URL, that hit is kept (not discarded). **Cancel**, leave the title, or switch shell tabs also aborts the Auto check — same stop as Cancel, not only the button.
- Source links are **HTTP-probed before open** on play (same check as menu tap-to-probe). Dead playlist/CDN links fail that probe without waiting for a full mpv timeout.
- The **score badge number** is the provider’s **running Σ** across titles you play (count **up or down**, never below **0** — fails at 0 stay 0; a later success counts up). The **+/− prefixes** are outcomes **for this film / TV episode / anime episode** only: server **±2**, stream **±2**. Server and stream are **linked**: extract OK + stream OK → **+2 +2**; extract OK + all streams dead → **+2 −2** (net 0); extract empty → **−2**. Score commits only when that check finishes — **Cancel**, mid-check, extract-only, or anime extract before the CDN reachability probe does **not** add **+2 +2**. Anime CDN-dead after extract commits **+2 −2**. Asian drama is not scored. Σ nudges Auto order over time.
- Reorder providers in Settings (baseline per domain; effective order preview in table)
- On decoder failure, try software decode once — do not auto-switch providers

## Domains

| Domain | Typical engines |
|--------|-----------------|
| Movies / TV | Videasy, VidLink, VidFast, 2Embed, AutoEmbed, WebStreamr, … |
| Anime | Megaplay, VidNest, VidLink, Miruro, AllAnime, … |
| Asian Drama | KissKH mirrors (`.co`, `.nl`, `.ovh`, `.la`, `.do`) |
| IPTV | Xtream / M3U / Stalker (portal) |
| Torrent | Local / debrid |

## Tips

- New users: leave **Auto** on
- Power users: pin a server from the player menu
- WebStreamr is powerful but slower — profile priority keeps it lower by default; under Simple resolve it still gets up to ~90s when you pin it (not cut off at 25s). Source hosts track WebStreamrMBG (plus VidZee / MovieBox / Filmpalast)
- **Videasy** resolves via `db.speedracelight.com` + `api.speedracelight.com` mirrors (same as [player.videasy.to](https://player.videasy.to) Servers: Yoru→`cdn`, Cypher→`downloader2`, Breach→`m4uhd`, Neon→`vsrc`, Vyse / Killjoy / Fade / Omen / Raze — not the public embed docs on [videasy.to](https://www.videasy.to/docs)). Encrypted `enc=2` bodies use **STREAMCRYPTO** (seed + TMDB id). Decrypt is **WebView (current)** or **Native (Dart)** — admin **Settings → Playback → STREAMCRYPTO decrypt**. Forja probes **every** mirror in bounded parallel and lists each responsive server under Sources (e.g. `Yoru · 1080p`). Playback opens the first reachable stream and keeps the `player.videasy.to` Referer by provider identity. If all mirrors fail/CF-block, Forja sniffs `player.videasy.to` and rotates the Servers dropdown one by one, keeping every playlist that emits
- **VSEmbed** uses `vsembed.su` embeds (`/embed/movie?tmdb=` · `/embed/tv?tmdb=&season=&episode=`). Forja first tries the legacy Rust HTML chain (rcp → prorcp → m3u8); when that fails (live player is now a JS/WASM page on `cloudorchestranova.com`), it sniffs the embed and force-starts the Play landing (`autoStart` is off — real streams load only after `#bigPlay` / `CFG.playerUrl`). CloudStream playlists use tokenized `/pl/…/master.m3u8` URLs whose `page-N.html` segments reject `Referer`/`Origin` (browser no-referrer) — Forja opens them with User-Agent only. Cached or Continue Watching CloudStream links are dropped when the JWT expires or leaf segments 403, then re-resolved. **Android TV** skips WebView sniff (GLES workaround) — VSEmbed only works there if the legacy Rust chain still answers
- **VidSrc** uses the public `vidsrc.win/watch/…` service but opens its underlying `video.moviepire.co/embed/movie|tv/…` player directly because the outer watch page is CAPTCHA-gated. The player exposes Alpha (HLS) and Blaze (MP4); Forja rotates those server entries while collecting playable streams
- **VidNest** ([vidnest.fun](https://vidnest.fun/)) resolves via `new.vidnest.fun` (Gama/MovieBox and siblings) in bounded parallel and lists every server that returns streams. Movie/TV opens use **User-Agent only** unless the API sent Referer/Origin — Forja does **not** force `vidnest.fun` onto CDN playlists (lamda / delta / alfa / … reject that). MovieBox CDN links (`*.hakunaymatata.com`) still strip any Referer/Origin (HTTP 429 when set). If the API path fails, Forja falls back to sniffing the public embed
- **VidRock** (`vidrock.ru` AES-GCM locally): Forja tab GETs `/api/movie/{tmdb}` or `/api/tv/{tmdb}/{s}/{e}` and decrypts each server URL — Astra playlists expand to quality rows. Green Play still sniffs `vidrock.ru/movie|tv/…` (Server List click) when the HTTP path misses.
- **VidFast** (`vidfast.vc/movie|tv/…`): loads as the headless WebView top-level page (no iframe wrapper). The site’s player is HLS.js / MSE — `video.src` is often a `blob:` while the real playlist is passed to `Hls.loadSource` (often bundled, not on `window.Hls`). Forja hooks that call, scans opaque `/w/{uuid}/…` playlist bodies, and rotates Server chips so Sources can list multiple servers. If chips never appear, the default playlist is kept after a short settle (not held until the 90s sniff wall). Playback uses the embed Referer.
- **Vidzee** (`player.vidzee.wtf/embed/…`): top-level sniff with Cloudflare wait (Miruro-style clearance poll). When CF clears, Forja defers for HLS and rotates servers; CDN hosts like 1shows keep the embed Referer. Hard CF gates (origin 522 / uncleared Turnstile) still fail — same class as AutoEmbed
- **VidSrc.sbs** (`vidsrc.sbs/embed/…`) is separate from **VSEmbed** (`vsembed.su`) and **VidSrc** (`vidsrc.win`). Its aggregator rejects iframe-wrapped playback, so Forja opens it as the headless WebView's top-level document before sniffing on desktop/mobile. On resolve, Forja reads the embed’s `CFG.servers` list (site order) and sniffs **every** nested mirror in bounded parallel (two at a time). Nested **4K** / `player.videasy.to` / `player.videasy.net` URLs skip sniff and use the same STREAMCRYPTO HTTP path as Videasy (same Playback decrypt setting). Other nested players rotate their own Servers chips (e.g. Pro Multi internals) and keep every playlist that emits — Sources lists them (e.g. `PRO Multi · …`, `Cinesrc`, `4K`). Playback opens the first reachable stream. Nested proxy responses are scanned for `.m3u8` in the body; Cinesrc-style `ice…/?m3u8=<token>` URLs are treated as playable HLS even without a `.m3u8` path. Policy lives under `shared/extractors/providers/vidsrcsbs/`
- **AutoEmbed** uses `player.autoembed.co/embed/…` directly (the public `autoembed.co/…` page only iframes that player, which then shows “Playback blocked” when nested under Forja’s WebView). The nested CloudFabric player is often gated by Cloudflare Turnstile in headless sniff — browser works; Forja may return no streams until a non-WebView path lands
- **2Embed** uses `2embed.stream/embed/…` (same as [2embed.online](https://www.2embed.online/) docs after redirect). Legacy `2embed.cc` is not used — top-level loads there bounce to `.skin` and break sniff. Multi-server chips are rotated when the default source stalls
- **VidLove** (`player.vidlove.cc`) and **111Movies** (same player): rotate server chips (MovieBox / VidAPI, plus legacy Neta / Gogo / Mafia / Fabric) for the sniff window and keep every stream detected. Live media is often a signed `/api?d=…&internal_token=…` URL (no `.m3u8` suffix) — Forja treats that as playable. WebView cookies + the embed Referer attach on open. Audio-only CDN paths (`tran-audio`) are ignored until a real media URL appears
- Host sniff: Rust plugins stay in `crates/resolver-engine/src/plugins/`; Flutter owns `shared/extractors/core/` (WebView engine) + `shared/extractors/providers/<id>/` (per-provider profile/extractor). `packages/rust/lib/src/playback/` is typed clients/models/ordering only — not host extractors
- Host sniff blocks popup windows and cancels main-frame ad redirects away from the original embed/player site during automated play clicks. Subframe/player resources still load so generic template embeds can reach their real stream requests. Mid-check cancel keeps an already-detected playable URL instead of returning empty. Headless sniff keeps embed `<video>`/`<audio>` muted so a background Check cannot play over the stream you’re watching.
- Template embed hosts are kept on working player domains: VidSrc (`video.moviepire.co/embed/…` behind the CAPTCHA-gated `vidsrc.win/watch/…` page), VidFast (`vidfast.vc`), VidRock (`vidrock.ru`), Vidzee (`player.vidzee.wtf/embed/…`), VidLove / 111Movies (`player.vidlove.cc/embed/…`), VidSrc.sbs (`vidsrc.sbs/embed/…`), AutoEmbed (`player.autoembed.co/embed/…` — not the outer `autoembed.co` shell), 2Embed (`2embed.stream/embed/…` per [2embed.online](https://www.2embed.online/)), VidAPI (`vidapi.xyz/embed/…`). Playback stamps each stream with that provider id and opens with that embed host as Referer — CDN hostname churn does not need a code patch; retarget the template/base in Admin → Providers when the **player** domain moves
- When Rust cannot resolve a VidSrc-style embed (common on older films), Forja falls back to a headless browser sniff on desktop/mobile. Configure **MediaFlow Proxy** / **FlareSolverr** in WebStreamr settings if regional hosts return 403
- **Template embeds** (VidSrc, VidFast, 2Embed, …): Resolver Engine builds the canonical embed URL and the host sniffs it with a headless WebView. Pin a server in **Sources** to force that path; **Auto** may finish earlier on WebStreamr/VSEmbed without sniffing every embed
- **Android TV:** WebView-based extractors (VidSrc, VidLink, VixSrc, Vidnest, …) are skipped — the loading screen marks them **SKIPPED ON TV** and **WebStreamr**, **VSEmbed**, and **111477** stay on (Chromium GPU crash workaround). **Videasy** and **VidSrc.sbs** are not skipped: Native STREAMCRYPTO decrypt needs no WebView; WebView decrypt still fails on TV unless headless extractors are allowed
- External players (VLC, MX Player) bypass Forja’s automatic fallback chain

## Related

- [Webstreaming](../movies-tv/direct-streaming-mode.md)
- [WebStreamr settings](../scrapers/webstreamr-settings.md)
- [Nuvio scrapers](../scrapers/nuvio.md)
- [Playback settings](../settings/playback-settings.md)
