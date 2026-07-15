# Stream providers

> Domain-scoped source engines pick scrapers; the player only sees playable streams.

## What it is

Forja resolves streams through the **Rust Resolver Engine** (`crates/resolver-engine`). Movie/TV scrapers never compete with anime or Asian Drama scrapers. Each domain has provider **profiles** (configured domain scores). Your **settings order** is the baseline; domain scores plus a **live reliability Σ** (sum of per-title check scores for that provider, clamped ±20 when ranking) may adjust each provider by at most **±2** ranks before checking. The engine scores resolved URLs against your device (codec, resolution, latency) and returns a **playable URL + headers** — the player does not know which scraper produced it.

Green **Play** calls `PlaybackService.resolve()` → Resolver Engine job. Host-only providers (WebView embed sniff, Videasy WASM, Nuvio) are fulfilled by a host adapter after the engine requests them.

Built-in **webstreaming** movie/series providers include Videasy, Vidsrc, VidSrc.sbs, VidLink, VixSrc, Vidnest, Vidzee, VidRock, VidFast, 2Embed, SuperEmbed, AutoEmbed, VidLove, 111Movies, MoviesAPI, SmashyStream, PrimeWire, 111477, and WebStreamr. [Nuvio](../scrapers/nuvio.md) scrapers are **not** in this list — they live in the **Sources** panel under **Direct torrent**.

**How providers resolve:**

| Type | Providers | Mechanism |
|------|-----------|-----------|
| Direct extractors | Videasy, Vidsrc, Vidnest | Videasy: `api.wingsdatabase.com` (+ sniff fallback); Vidsrc: embed → CDN chain; VidNest: `new.vidnest.fun` API (+ sniff fallback) |
| Embed + WebView sniff | VidLink, VixSrc, Vidzee, VidRock, VidFast, 2Embed, SuperEmbed, AutoEmbed, VidLove, VidSrc.sbs, 111Movies, MoviesAPI, SmashyStream, PrimeWire | Canonical embed URL → Resolver `HostRequired` → headless WebView captures stream (desktop/mobile) |
| Aggregator / index | WebStreamr, 111477 | Multi-scraper resolve or index match + local proxy |

## How to open it

**Settings → Playback → Server reliability** — Movies / Series / Anime tabs with live **Score** and Auto **Tries** order.

**In player → Servers** — pick **Auto** (default) or pin a specific server. Stream rows show a language flag when the title encodes a region/language. Header **Embed** (next to reload) controls WebView sniff mode: checked loads the embed inside an iframe; unchecked loads the embed URL directly.

## What you can do

- **Auto** — Resolver Engine (details **Play**) and in-player Auto try providers in **effective score order**, one step at a time until one **works**: extract → HTTP reachability probe → mpv open/decode. Host providers (VidLink, Videasy, …) are not raced in parallel — Rust pauses for the next host, Flutter fulfills it, then the race resumes at the next provider. If a **cached** list goes dead after siblings fail, Forja drops the cache and runs that full score-order resolve again (same as first Play). Mid-play open/check fail with Auto On can still continue with the next server in the chain.
- **Manual** — on the loading screen, open the server list (layers icon next to **Cancel**) and tap a provider to check it now; or in the player pick a server / stream (or turn Auto server Off). Forja stays on that pick — **no** silent cross-provider/stream hop on fail
- Source links are **HTTP-probed before open** on play (same check as menu tap-to-probe). Dead playlist/CDN links fail that probe without waiting for a full mpv timeout.
- The **score badge number** is the provider’s **global Σ** (sum of title totals for that server). The **+/− prefixes** are outcomes **for this film / TV episode / anime episode** only: server **±2**, stream **±2** (both ok → **+4** on this title), all streams down **−2**. Asian drama is not scored. Those per-title totals feed Σ and nudge Auto order over time.
- Reorder providers in Settings (baseline per domain; effective order preview in table)
- On decoder failure, try software decode once — do not auto-switch providers

## Domains

| Domain | Typical engines |
|--------|-----------------|
| Movies / TV | Videasy, VidLink, VidFast, 2Embed, SuperEmbed, AutoEmbed, WebStreamr, … |
| Anime | Miruro, AllAnime, AnimeRealms, … |
| Asian Drama | KissKH |
| IPTV | Xtream / M3U / Stalker (portal) |
| Torrent | Local / debrid |

## Tips

- New users: leave **Auto** on
- Power users: pin a server from the player menu
- WebStreamr is powerful but slower — profile priority keeps it lower by default
- **Videasy** resolves via `db.wingsdatabase.com` + `api.wingsdatabase.com` mirrors (same as [player.videasy.to](https://player.videasy.to) Servers: Yoru→`cdn`, Neon→`neon2`, Sage→`ym`, … — not the public embed docs on [videasy.to](https://www.videasy.to/docs)). Forja probes **Yoru/`cdn` first** (website default); hung mirrors fail fast. Successful mirrors show as named sources (Yoru, Neon, …). If all mirrors fail/CF-block, Forja sniffs `player.videasy.to`
- **Vidsrc** uses `vsembed.su` embeds (`/embed/movie?tmdb=` · `/embed/tv?tmdb=&season=&episode=`); the inner CDN host (e.g. `cloudorchestranova.com`) is detected automatically — do not hardcode legacy `cloudnestra.com`. CloudStream playlists use tokenized `/pl/…/master.m3u8` URLs whose `page-N.html` segments reject `Referer`/`Origin` (browser no-referrer) — Forja opens them with User-Agent only
- **VidNest** ([vidnest.fun](https://vidnest.fun/)) resolves via `new.vidnest.fun` (Gama/MovieBox first). MovieBox CDN links (`*.hakunaymatata.com`) must open **without** Referer/Origin — that CDN returns HTTP 429 when Referer is set. If the API path fails, Forja falls back to sniffing the public embed
- **VidSrc.sbs** (`vidsrc.sbs/embed/…`) is a separate template embed from **Vidsrc** (`vsembed.su`). Its aggregator rejects iframe-wrapped playback, so Forja opens it as the headless WebView's top-level document before sniffing on desktop/mobile. Nested `1embed` proxy responses are scanned for `.m3u8` URLs in the response body (not only in the request URL). Policy lives on that provider’s `EmbedExtractProfile` under `shared/extractors/providers/vidsrcsbs/`
- **VidLove** (`player.vidlove.cc`) and similar multi-server embeds: that provider’s profile under `shared/extractors/providers/vidlove/` rotates internal server chips (e.g. Neta / Gogo / Mafia / Fabric) when the default server is stuck loading, and attaches WebView cookies + the embed Referer when opening the CDN playlist
- Host sniff: Rust plugins stay in `crates/resolver-engine/src/plugins/`; Flutter owns `shared/extractors/core/` (WebView engine) + `shared/extractors/providers/<id>/` (per-provider profile/extractor). `packages/rust/lib/src/playback/` is typed clients/models/ordering only — not host extractors
- Template embed hosts are kept on documented canonical domains: VidFast (`vidfast.vc`), VidRock (`vidrock.ru`), Vidzee (`player.vidzee.wtf/embed/…`), VidLove / 111Movies (`player.vidlove.cc/embed/…`), VidSrc.sbs (`vidsrc.sbs/embed/…`), SmashyStream (`anyembed.xyz/embed/…`). SuperEmbed still uses `multiembed.mov` per provider docs (may redirect internally)
- **PrimeWire** (`primewire.tf`) has been unreliable in live checks — expect misses; pick another server if it fails
- When Rust cannot resolve a VidSrc-style embed (common on older films), Forja falls back to a headless browser sniff on desktop/mobile — same idea as PlayTorrio. Configure **MediaFlow Proxy** / **FlareSolverr** in WebStreamr settings if regional hosts return 403
- **Template embeds** (VidFast, 2Embed, SuperEmbed, …): Resolver Engine builds the canonical embed URL and the host sniffs it with a headless WebView. Pin a server in **Sources** to force that path; **Auto** may finish earlier on WebStreamr/Vidsrc without sniffing every embed
- **Android TV:** WebView-based extractors (VidLink, VixSrc, Vidnest, Videasy, …) are skipped — the loading screen marks them **SKIPPED ON TV** and only **WebStreamr**, **Vidsrc**, and **111477** are checked (Chromium GPU crash workaround)
- External players (VLC, MX Player) bypass Forja’s automatic fallback chain

## Related

- [Webstreaming](../movies-tv/direct-streaming-mode.md)
- [WebStreamr settings](../scrapers/webstreamr-settings.md)
- [Nuvio scrapers](../scrapers/nuvio.md)
- [Playback settings](../settings/playback-settings.md)
