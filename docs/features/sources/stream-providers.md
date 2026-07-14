# Stream providers

> Domain-scoped source engines pick scrapers; the player only sees playable streams.

## What it is

Forja resolves streams through the **Rust Resolver Engine** (`crates/resolver-engine`). Movie/TV scrapers never compete with anime or Asian Drama scrapers. Each domain has provider **profiles** (configured domain scores). Your **settings order** is the baseline; domain scores may adjust each provider by at most **±2** ranks before checking. The engine scores resolved URLs against your device (codec, resolution, latency) and returns a **playable URL + headers** — the player does not know which scraper produced it.

Green **Play** calls `PlaybackService.resolve()` → Resolver Engine job. Host-only providers (WebView embed sniff, Videasy WASM, Nuvio) are fulfilled by a host adapter after the engine requests them.

Built-in **webstreaming** movie/series providers include Videasy, Vidsrc, VidLink, VixSrc, Vidnest, Vidzee, VidRock, VidFast, 2Embed, SuperEmbed, AutoEmbed, 111Movies, MoviesAPI, SmashyStream, PrimeWire, 111477, and WebStreamr. [Nuvio](../scrapers/nuvio.md) scrapers are **not** in this list — they live in the **Sources** panel under **Direct torrent**.

**How providers resolve:**

| Type | Providers | Mechanism |
|------|-----------|-----------|
| Direct extractors | Videasy, Vidsrc | Rust HTTP chain (Videasy: `api.wingsdatabase.com`; Vidsrc: embed → CDN rcp/prorcp → m3u8) |
| Embed + WebView sniff | VidLink, VixSrc, Vidnest, Vidzee, VidRock, VidFast, 2Embed, SuperEmbed, AutoEmbed, 111Movies, MoviesAPI, SmashyStream, PrimeWire | Canonical embed URL → Resolver `HostRequired` → headless WebView captures stream (desktop/mobile) |
| Aggregator / index | WebStreamr, 111477 | Multi-scraper resolve or index match + local proxy |

## How to open it

**Settings → Playback → Source scoring** — per-type tables with baseline rank, domain score, ±2 cap, and effective pre-check order.

**In player → Servers** — pick **Auto** (default) or pin a specific server. Stream rows show a language flag when the title encodes a region/language. Header **Embed** (next to reload) controls WebView sniff mode: checked loads the embed inside an iframe; unchecked loads the embed URL directly.

## What you can do

- **Auto** — Resolver Engine (details **Play**) and in-player Auto try providers in effective order until one **works**: extract → HTTP reachability probe → mpv open/decode. If that open/check fails while Auto server is On, Forja walks the next servers in order.
- **Manual** — pick a server or stream (or turn Auto server Off); Forja stays on it — **no** silent cross-provider/stream hop on fail
- Source links are **HTTP-probed before open** on play (same check as menu tap-to-probe). Dead playlist/CDN links fail that probe without waiting for a full mpv timeout.
- The **score badge** uses a **settings base of 0** per server **for this film, TV episode, or anime episode**. Server and stream outcomes **add**: server **±2**, stream **±2** (both ok → **+4**), all streams down **−2**. Asian drama is not scored. A **+/− prefix** shows the last change.
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
- **Vidsrc** uses `vsembed.ru` embeds; the inner CDN host (e.g. `cloudorchestranova.com`) is detected automatically — do not hardcode legacy `cloudnestra.com`
- Template embed hosts are kept on documented canonical domains: VidFast (`vidfast.vc`), VidRock (`vidrock.ru`), Vidzee (`player.vidzee.wtf/embed/…`), 111Movies (`player.vidlove.cc/embed/…`), SmashyStream (`anyembed.xyz/embed/…`). SuperEmbed still uses `multiembed.mov` per provider docs (may redirect internally)
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
