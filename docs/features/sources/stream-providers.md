# Stream providers

> Domain-scoped source engines pick scrapers; the player only sees playable streams.

## What it is

Forja resolves streams through the **Rust Resolver Engine** (`crates/resolver-engine`). Movie/TV scrapers never compete with anime or Asian Drama scrapers. Each domain has provider **profiles** (configured domain scores). Your **settings order** is the baseline; domain scores plus a **live reliability Σ** (sum of per-title check scores for that provider, clamped ±20 when ranking) may adjust each provider by at most **±2** ranks before checking. The engine scores resolved URLs against your device (codec, resolution, latency) and returns a **playable URL + headers** — the player does not know which scraper produced it.

Movie/TV embed **URL templates**, WebStreamr **bases**, anime **hosts / APIs / mirrors**, and **CDN Referer rules** can be overlaid from cloud `provider_runtime_config` (RFC-039) so ops can retarget URLs without shipping a new build — edit in Admin → **Providers** (sectioned form, or JSON for advanced edits). Extract logic (decrypt, Cloudflare pipes, WebView sniff) still ships in the app.

Green **Play** calls `PlaybackService.resolve()` → Resolver Engine job. Host-only providers (WebView embed sniff, Videasy WASM, Nuvio) are fulfilled by a host adapter after the engine requests them.

Built-in **webstreaming** movie/series providers include Videasy, VSEmbed, VidSrc, VidSrc.sbs, VidLink, VixSrc, Vidnest, Vidzee, VidRock, VidFast, 2Embed, AutoEmbed, VidLove, 111Movies, MoviesAPI, 111477, and WebStreamr. [Nuvio](../scrapers/nuvio.md) scrapers are **not** in this list — they live in the **Sources** panel under **Direct torrent**.

**How providers resolve:**

| Type | Providers | Mechanism |
|------|-----------|-----------|
| Direct extractors | Videasy, VSEmbed, Vidnest | Videasy: `api.wingsdatabase.com` (+ sniff fallback); VSEmbed: embed → CDN chain; VidNest: `new.vidnest.fun` API (+ sniff fallback) |
| Embed + WebView sniff | VidSrc, VidLink, VixSrc, Vidzee, VidRock, VidFast, 2Embed, AutoEmbed, VidLove, VidSrc.sbs, 111Movies, MoviesAPI | Canonical embed URL → Resolver `HostRequired` → headless WebView captures stream (desktop/mobile) |
| Aggregator / index | WebStreamr, 111477 | Multi-scraper resolve or index match + local proxy |

## How to open it

**Settings → Playback → Server reliability** — Movies / Series / Anime / Asian Drama tabs with live **Score** and Auto **Tries** order.

**In player → Servers** — pick **Auto** (default) or pin a specific server. Stream rows show a language flag when the title encodes a region/language. WebView sniff loads embeds inside an iframe by default (some providers still force a direct load).

## What you can do

- **Auto** — Resolver Engine (details **Play**) and in-player Auto try providers in **effective score order**, one step at a time until one **works**: extract → HTTP reachability probe → mpv open/decode. Host providers (VidLink, Videasy, …) are not raced in parallel — Rust pauses for the next host, Flutter fulfills it, then the race resumes at the next provider. If a **cached** list goes dead after siblings fail, Forja drops the cache and runs that full score-order resolve again (same as first Play). Mid-play open/check fail with Auto On can still continue with the next server in the chain.
- **Manual** — on the loading screen, open the server list (layers icon next to **Cancel**) and tap a provider to check it now; or in the player pick a server / stream (or turn Auto server Off). Forja stays on that pick — **no** silent cross-provider/stream hop on fail. Switching providers mid-check starts the new one immediately (only one Source-panel spinner at a time); if the previous sniff had already found a playable URL, that hit is kept (not discarded). **Cancel**, leave the title, or switch shell tabs also aborts the Auto check — same stop as Cancel, not only the button.
- Source links are **HTTP-probed before open** on play (same check as menu tap-to-probe). Dead playlist/CDN links fail that probe without waiting for a full mpv timeout.
- The **score badge number** is the provider’s **running Σ** across titles you play (count **up or down**, never below **0** — fails at 0 stay 0; a later success counts up). The **+/− prefixes** are outcomes **for this film / TV episode / anime episode** only: server **±2**, stream **±2**. Asian drama is not scored. Σ nudges Auto order over time.
- Reorder providers in Settings (baseline per domain; effective order preview in table)
- On decoder failure, try software decode once — do not auto-switch providers

## Domains

| Domain | Typical engines |
|--------|-----------------|
| Movies / TV | Videasy, VidLink, VidFast, 2Embed, AutoEmbed, WebStreamr, … |
| Anime | Megaplay, Vidwish, VidNest, Miruro, AllAnime, … |
| Asian Drama | KissKH mirrors (`.co`, `.nl`, `.ovh`, `.la`, `.do`) |
| IPTV | Xtream / M3U / Stalker (portal) |
| Torrent | Local / debrid |

## Tips

- New users: leave **Auto** on
- Power users: pin a server from the player menu
- WebStreamr is powerful but slower — profile priority keeps it lower by default
- **Videasy** resolves via `db.wingsdatabase.com` + `api.wingsdatabase.com` mirrors (same as [player.videasy.to](https://player.videasy.to) Servers: Yoru→`cdn`, Neon→`neon2`, Sage→`ym`, … — not the public embed docs on [videasy.to](https://www.videasy.to/docs)). Forja probes every listed mirror in bounded parallel (up to four at once) and lists every stream that responds. If all mirrors fail/CF-block, Forja sniffs `player.videasy.to`
- **VSEmbed** uses `vsembed.su` embeds (`/embed/movie?tmdb=` · `/embed/tv?tmdb=&season=&episode=`); the inner CDN host (e.g. `cloudorchestranova.com`) is detected automatically — do not hardcode legacy `cloudnestra.com`. CloudStream playlists use tokenized `/pl/…/master.m3u8` URLs whose `page-N.html` segments reject `Referer`/`Origin` (browser no-referrer) — Forja opens them with User-Agent only
- **VidSrc** uses the public `vidsrc.win/watch/…` service but opens its underlying `video.moviepire.co/embed/movie|tv/…` player directly because the outer watch page is CAPTCHA-gated. The player exposes Alpha (HLS) and Blaze (MP4); Forja rotates those server entries while collecting playable streams
- **VidNest** ([vidnest.fun](https://vidnest.fun/)) resolves via `new.vidnest.fun` (Gama/MovieBox and siblings) in bounded parallel and lists every server that returns streams. MovieBox CDN links (`*.hakunaymatata.com`) must open **without** Referer/Origin — that CDN returns HTTP 429 when Referer is set. If the API path fails, Forja falls back to sniffing the public embed
- **VidSrc.sbs** (`vidsrc.sbs/embed/…`) is separate from **VSEmbed** (`vsembed.su`) and **VidSrc** (`vidsrc.win`). Its aggregator rejects iframe-wrapped playback, so Forja opens it as the headless WebView's top-level document before sniffing on desktop/mobile. On resolve, Forja reads the embed’s `CFG.servers` list (site order) and sniffs every nested mirror in bounded parallel (two at a time) — every responsive mirror appears in Sources. Nested proxy responses are still scanned for `.m3u8` in the response body. Policy lives under `shared/extractors/providers/vidsrcsbs/`
- **AutoEmbed** uses `player.autoembed.co/embed/…` directly (the public `autoembed.co/…` page only iframes that player, which then shows “Playback blocked” when nested under Forja’s WebView)
- **2Embed** uses `2embed.stream/embed/…` (same as [2embed.online](https://www.2embed.online/) docs after redirect). Legacy `2embed.cc` is not used — top-level loads there bounce to `.skin` and break sniff. Multi-server chips are rotated when the default source stalls
- **VidLove** (`player.vidlove.cc`) and similar multi-server embeds: that provider’s profile under `shared/extractors/providers/vidlove/` rotates internal server chips (e.g. Neta / Gogo / Mafia / Fabric) for the full sniff window and keeps every playlist detected — no first-hit early complete. WebView cookies + the embed Referer attach when opening the CDN playlist. Audio-only CDN paths (`tran-audio`) are ignored until an HLS/DASH playlist appears
- Host sniff: Rust plugins stay in `crates/resolver-engine/src/plugins/`; Flutter owns `shared/extractors/core/` (WebView engine) + `shared/extractors/providers/<id>/` (per-provider profile/extractor). `packages/rust/lib/src/playback/` is typed clients/models/ordering only — not host extractors
- Host sniff blocks popup windows and cancels main-frame ad redirects away from the original embed/player site during automated play clicks. Subframe/player resources still load so generic template embeds can reach their real stream requests. Mid-check cancel keeps an already-detected playable URL instead of returning empty.
- Template embed hosts are kept on working player domains: VidSrc (`video.moviepire.co/embed/…` behind the CAPTCHA-gated `vidsrc.win/watch/…` page), VidFast (`vidfast.vc`), VidRock (`vidrock.ru`), Vidzee (`player.vidzee.wtf/embed/…`), VidLove / 111Movies (`player.vidlove.cc/embed/…`), VidSrc.sbs (`vidsrc.sbs/embed/…`), AutoEmbed (`player.autoembed.co/embed/…` — not the outer `autoembed.co` shell), 2Embed (`2embed.stream/embed/…` per [2embed.online](https://www.2embed.online/))
- When Rust cannot resolve a VidSrc-style embed (common on older films), Forja falls back to a headless browser sniff on desktop/mobile — same idea as PlayTorrio. Configure **MediaFlow Proxy** / **FlareSolverr** in WebStreamr settings if regional hosts return 403
- **Template embeds** (VidSrc, VidFast, 2Embed, …): Resolver Engine builds the canonical embed URL and the host sniffs it with a headless WebView. Pin a server in **Sources** to force that path; **Auto** may finish earlier on WebStreamr/VSEmbed without sniffing every embed
- **Android TV:** WebView-based extractors (VidSrc, VidLink, VixSrc, Vidnest, Videasy, …) are skipped — the loading screen marks them **SKIPPED ON TV** and only **WebStreamr**, **VSEmbed**, and **111477** are checked (Chromium GPU crash workaround)
- External players (VLC, MX Player) bypass Forja’s automatic fallback chain

## Related

- [Webstreaming](../movies-tv/direct-streaming-mode.md)
- [WebStreamr settings](../scrapers/webstreamr-settings.md)
- [Nuvio scrapers](../scrapers/nuvio.md)
- [Playback settings](../settings/playback-settings.md)
