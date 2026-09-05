# Stream providers

> Domain-scoped source engines pick scrapers; the player only sees playable streams.

## What it is

Forja resolves movie/TV/anime/drama streams through **Forja EngineJS** (`plugins/providers/*.js`) and the player **Sources** panel. Scrapers are **domain-scoped**. Your **settings order** is the baseline; domain scores plus a **live reliability Σ** (per-provider check history) may nudge order by at most **±2** ranks. The player sees **playable URLs + headers**.

Movie/TV **URL templates**, scraper **source host bases**, anime **hosts / APIs / mirrors**, **CDN Referer rules**, and **playback profiles** can be overlaid from cloud `provider_runtime_config` (RFC-039) — Admin → **Providers** or profile sync.

**Hub green Play** and **Sources → Forja** run installed engine plugins. Built-in embed WebView sniff and the old Rust resolver race are **removed**.

[Nuvio](../scrapers/nuvio.md) scrapers live in **Sources** under **Direct torrent**, not a built-in webstreaming list.

**Sources → Forja** runs `extract(ctx)` plugins in parallel (EngineJS job pool). Install via **Settings → Forja Packs** or web **Profile → Plugins**. Plugins are tagged **movie** / **tv** / **anime** / **drama**. Settings groups **Movie & TV** / **Anime** / **Drama** / **Live** / **Catalog**. **All** runs up to **10** plugins in flight (**5** on TV); rows appear as each finishes.

Cold start (and profile switch) downloads any cloud-synced packs that are missing onto the device — progress shows in the splash’s normal bottom status line (pack name / step) with a thin progress bar while packs install. If download is slow, stuck, or fails, **Continue in background** opens the app while install keeps going (autofocused on Android TV). Mid-session, when another device adds or removes a pack on your profile, Forja asks before downloading or uninstalling here. Mid-session installs also use a bottom progress card. **Settings → Reload** on a pack always re-fetches that pack; **Remove** deletes its cached scripts and pushes membership off the profile.

## How to open it

**Settings → Sources → Forja** — enable or disable engine plugins per category.

**In player → Servers** — pick **Auto** (default) or pin a specific server. Stream rows show a language flag when the title encodes a region/language.

## What you can do

- **Auto** — Engine plugins try in **effective score order** until one works: extract → HTTP probe → open. Mid-watch failure tries sibling mirrors, then reloads via `onReloadStreams` / re-extract when pinned off.
- **Manual** — pick a server / stream; Forja stays on that pick on fail. Switching providers mid-check starts the new one immediately.
- Source links are **HTTP-probed before open** on play (same check as menu tap-to-probe). Dead playlist/CDN links fail that probe without waiting for a full mpv timeout.
- The **score badge number** (when shown) is the provider’s **running Σ** across titles you play. The **+/− prefixes** are outcomes **for this film / TV episode / anime episode** only.
- Enable or disable providers under **Settings → Sources → Forja** (per-plugin toggles and pack switches)
- On decoder failure, try software decode once — do not auto-switch providers

## Domains

| Domain | Typical engines |
|--------|-----------------|
| Movies / TV | Videasy, VidLink, VidFast, 2Embed, AutoEmbed, Forja engine plugins, … |
| Anime | Megaplay, VidNest, VidLink, Miruro, AllAnime, … |
| Asian Drama | KissKH mirrors (`.co`, `.nl`, `.ovh`, `.la`, `.do`, `.is`, `.id`) |
| IPTV | Xtream / M3U / Stalker (portal) |
| Torrent | Local / debrid |

## Tips

- New users: leave **Auto** on
- Power users: pin a server from the player menu
- **111477** / **DahmerMovies** index paths are slower than template embeds — profile priority keeps them lower by default
- **Videasy** resolves via `db.speedracelight.com` + `api.speedracelight.com` mirrors (same as [player.videasy.to](https://player.videasy.to) Servers: Yoru→`cdn`, Cypher→`downloader2`, Breach→`m4uhd`, Neon→`vsrc`, Vyse / Killjoy / Fade / Omen / Raze — not the public embed docs on [videasy.to](https://www.videasy.to/docs)). Encrypted `enc=2` bodies use shared engine **STREAMCRYPTO** JS (seed + TMDB id). Forja probes **every** mirror in bounded parallel and lists each responsive server under Sources (e.g. `Yoru · 1080p`). Playback opens the first reachable stream and keeps the `player.videasy.to` Referer by provider identity.
- **VSEmbed** uses `vsembed.su` embeds (`/embed/movie?tmdb=` · `/embed/tv?tmdb=&season=&episode=`). Forja first tries the legacy Rust HTML chain (rcp → prorcp → m3u8); when that fails (live player is now a JS/WASM page on `cloudorchestranova.com`), it sniffs the embed and force-starts the Play landing (`autoStart` is off — real streams load only after `#bigPlay` / `CFG.playerUrl`). CloudStream playlists use tokenized `/pl/…/master.m3u8` URLs whose `page-N.html` segments reject `Referer`/`Origin` (browser no-referrer) — Forja opens them with User-Agent only. Cached or Continue Watching CloudStream links are dropped when the JWT expires or leaf segments 403, then re-resolved. **Android TV** skips WebView sniff (GLES workaround) — VSEmbed only works there if the legacy Rust chain still answers
- **VidSrc** uses the public `vidsrc.win/watch/…` service but opens its underlying `video.moviepire.co/embed/movie|tv/…` player directly because the outer watch page is CAPTCHA-gated. The player exposes Alpha (HLS) and Blaze (MP4); Forja rotates those server entries while collecting playable streams
- **VidNest** ([vidnest.fun](https://vidnest.fun/)) resolves via `new.vidnest.fun` (Gama/MovieBox and siblings) in bounded parallel and lists every server that returns streams. Movie/TV opens use **User-Agent only** unless the API sent Referer/Origin — Forja does **not** force `vidnest.fun` onto CDN playlists (lamda / delta / alfa / … reject that). MovieBox CDN links (`*.hakunaymatata.com`) still strip any Referer/Origin (HTTP 429 when set). **Sources → Forja currently does JS/API only for debugging**: if the API path misses, it does not fall back to sniff in that panel.
- **VidRock** (`vidrock.ru` AES-GCM locally): Forja tab GETs `/api/movie/{tmdb}` or `/api/tv/{tmdb}/{s}/{e}` and decrypts each server URL — Astra playlists expand to quality rows. **Sources → Forja currently does JS/API only for debugging**: green Play can still sniff `vidrock.ru/movie|tv/…`, but the Forja panel will show only the JS/API result.
- **VidFast** (`vidfast.vc/movie|tv/…`): loads as the headless WebView top-level page (no iframe wrapper). The site’s player is HLS.js / MSE — `video.src` is often a `blob:` while the real playlist is passed to `Hls.loadSource` (often bundled, not on `window.Hls`). **Sources → Forja currently does JS/API only for debugging**, so this panel will not use that sniff path while you verify which JS plugins work.
- **Vidzee** (`player.vidzee.wtf`): Sources → Forja hits `core.vidzee.wtf/streams/…?e=0` (plaintext HLS + player Referer). Green Play can still sniff the embed when that panel uses WebView. Dead `player.vidzee.wtf/api/server` SPA responses are ignored.
- **VidSrc.sbs** (`vidsrc.sbs/embed/…`) is separate from **VSEmbed** (`vsembed.su`) and **VidSrc** (`vidsrc.win`). Its aggregator rejects iframe-wrapped playback, so Forja opens it as the headless WebView's top-level document before sniffing on desktop/mobile. On resolve, Forja reads the embed’s `CFG.servers` list (site order) and sniffs **every** nested mirror in bounded parallel (two at a time). Nested **4K** / `player.videasy.to` / `player.videasy.net` URLs skip sniff and use the same STREAMCRYPTO HTTP path as Videasy. Other nested players rotate their own Servers chips (e.g. Pro Multi internals) and keep every playlist that emits — Sources lists them (e.g. `PRO Multi · …`, `Cinesrc`, `4K`). Playback opens the first reachable stream. Nested proxy responses are scanned for `.m3u8` in the body; Cinesrc-style `ice…/?m3u8=<token>` URLs are treated as playable HLS even without a `.m3u8` path. **Sources → Forja** uses the `vidsrcsbs.js` plugin: balanced-bracket `CFG.servers` parse, nxsha AES `/api/servers`+`/api/sources`, Videasy nests via STREAMCRYPTO.
- **AutoEmbed** (`player.autoembed.co` → `nextgencloudfabric.com`) is **not** a Forja HTTP chip (Turnstile blocks pure extract — [issue 167](../../issues/167-[open]-autoembed-cloudflare-turnstile.md)). Green Play / Tries may still sniff it.
- **2Embed** / **MultiEmbed** Sources → Forja use `multiembed.js` (`www.2embed.cc` → xpass playlists). Dead mirrors (`pinecrest*`, `goldenmeadow*`) are dropped; `*.1x2.space` (tik/vip) is preferred. Playback opens with `play.xpass.top` Referer. Green Play template still lists `2embed.stream/embed/…` for sniff; that host is currently unreliable. Legacy top-level `2embed.cc` bounces to `.skin` and breaks sniff.
- **VidLove** (`player.vidlove.cc`) and **111Movies** (same player): rotate server chips (MovieBox / VidAPI, plus legacy Neta / Gogo / Mafia / Fabric) for the sniff window and keep every stream detected. Live media is often a signed `/api?d=…&internal_token=…` URL (no `.m3u8` suffix) — Forja treats that as playable. WebView cookies + the embed Referer attach on open. Audio-only CDN paths (`tran-audio`) are ignored until a real media URL appears
- Host sniff: Rust template plugins in `crates/resolver-engine/src/plugins/`; green Play / Tries WebView path on desktop/mobile when HTTP extract misses. **Sources → Forja** is JS/API-only (`plugins/providers/*.js` + engine runtime).
- Host sniff blocks popup windows and cancels main-frame ad redirects away from the original embed/player site during automated play clicks. Subframe/player resources still load so generic template embeds can reach their real stream requests. Mid-check cancel keeps an already-detected playable URL instead of returning empty. Headless sniff keeps embed `<video>`/`<audio>` muted so a background Check cannot play over the stream you’re watching.
- Template embed hosts are kept on working player domains: VidSrc (`video.moviepire.co/embed/…` behind the CAPTCHA-gated `vidsrc.win/watch/…` page), VidFast (`vidfast.vc`), VidRock (`vidrock.ru`), Vidzee (`player.vidzee.wtf/embed/…`), VidLove / 111Movies (`player.vidlove.cc/embed/…`), VidSrc.sbs (`vidsrc.sbs/embed/…`), AutoEmbed (`player.autoembed.co/embed/…` — not the outer `autoembed.co` shell), 2Embed (`2embed.stream/embed/…` per [2embed.online](https://www.2embed.online/)), VidAPI (`vidapi.xyz/embed/…`). Playback stamps each stream with that provider id and opens with that embed host as Referer — CDN hostname churn does not need a code patch; retarget the template/base in Admin → Providers when the **player** domain moves
- When Rust cannot resolve a VidSrc-style embed (common on older films), Forja falls back to a headless browser sniff on desktop/mobile
- **Template embeds** (VidSrc, VidFast, 2Embed, …): Resolver Engine builds the canonical embed URL and the host sniffs it with a headless WebView. Pin a server in **Sources** to force that path; **Auto** may finish earlier on VSEmbed without sniffing every embed
- **Android TV:** WebView-based extractors (VidSrc, VidLink, VixSrc, Vidnest, …) are skipped — the loading screen marks them **SKIPPED ON TV** and **VSEmbed** and **111477** stay on (Chromium GPU crash workaround). **Videasy** and **VidSrc.sbs** HTTP/STREAMCRYPTO paths still run via engine JS (no WebView).
- External players (VLC, MX Player) bypass Forja’s automatic fallback chain

## Related

- [Webstreaming](../movies-tv/direct-streaming-mode.md)
- [Nuvio scrapers](../scrapers/nuvio.md)
- [Playback settings](../settings/playback-settings.md)
