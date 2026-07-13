# Stream providers

> Domain-scoped source engines pick scrapers; the player only sees playable streams.

## What it is

Forja resolves streams through a **Source Engine** middleware. Movie/TV scrapers never compete with anime or Asian Drama scrapers. Each domain has provider **profiles** (configured domain scores). Your **settings order** is the baseline; domain scores may adjust each provider by at most **±2** ranks before checking. The playback layer then scores resolved URLs against your device (codec, resolution, latency).

Built-in **webstreaming** movie/series providers include Videasy, Vidsrc, VidLink, VixSrc, Vidnest, Vidzee, VidRock, VidFast, 2Embed, SuperEmbed, AutoEmbed, 111Movies, MoviesAPI, SmashyStream, PrimeWire, 111477, and WebStreamr. [Nuvio](../scrapers/nuvio.md) scrapers are **not** in this list — they live in the **Sources** panel under **Direct torrent**.

**How providers resolve:**

| Type | Providers | Mechanism |
|------|-----------|-----------|
| Direct extractors | Videasy, Vidsrc | Rust HTTP chain (Videasy: `api.wingsdatabase.com`; Vidsrc: embed → CDN rcp/prorcp → m3u8) |
| Embed + WebView sniff | VidLink, VixSrc, Vidnest, Vidzee, VidRock, VidFast, 2Embed, SuperEmbed, AutoEmbed, 111Movies, MoviesAPI, SmashyStream, PrimeWire | Canonical embed URL → headless browser captures stream |
| Aggregator / index | WebStreamr, 111477 | Multi-scraper resolve or index match + local proxy |

## How to open it

**Settings → Playback → Source scoring** — per-type tables with baseline rank, domain score, ±2 cap, and effective pre-check order.

**In player → Servers** — pick **Auto** (default) or pin a specific server.

## What you can do

- **Auto** — Source Engine races providers (up to six at once) and opens the first working hit. Other servers resolve when you pick them in the player menu.
- **Manual** — pick a server; Forja stays on it (strict — no silent cross-provider fallback)
- Source links are **not** pre-checked on open — tap a stream to probe it (status on the left). Use the hover **play** arrow to switch. The current stream keeps playing until a play succeeds
- The **score badge** uses a **settings base of 0** per server **for this film, TV episode, or anime episode**. Server and stream outcomes **add**: server **±2**, stream **±2** (both ok → **+4**), all streams down **−2**. Asian drama is not scored. A **+/− prefix** shows the last change.
- Reorder providers in Settings (baseline per domain; effective order preview in table)
- On decoder failure, try the next compatible source, then software decode once

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
- **Videasy** resolves via the live player API (`db.wingsdatabase.com` metadata + `api.wingsdatabase.com` mirrors), not the public embed docs on [videasy.to](https://www.videasy.to/docs)
- **Vidsrc** uses `vsembed.ru` embeds; the inner CDN host (e.g. `cloudorchestranova.com`) is detected automatically — do not hardcode legacy `cloudnestra.com`
- Template embed hosts are kept on documented canonical domains: VidFast (`vidfast.vc`), VidRock (`vidrock.ru`), Vidzee (`player.vidzee.wtf/embed/…`), 111Movies (`player.vidlove.cc/embed/…`), SmashyStream (`anyembed.xyz/embed/…`). SuperEmbed still uses `multiembed.mov` per provider docs (may redirect internally)
- **PrimeWire** (`primewire.tf`) has been unreliable in live checks — expect misses; pick another server if it fails
- When Rust cannot resolve a VidSrc-style embed (common on older films), Forja falls back to a headless browser sniff on desktop/mobile — same idea as PlayTorrio. Configure **MediaFlow Proxy** / **FlareSolverr** in WebStreamr settings if regional hosts return 403
- **Android TV:** WebView-based extractors (VidLink, VixSrc, Vidnest, Videasy, …) are skipped — the loading screen marks them **SKIPPED ON TV** and only **WebStreamr**, **Vidsrc**, and **111477** are checked (Chromium GPU crash workaround)
- External players (VLC, MX Player) bypass Forja’s automatic fallback chain

## Related

- [Webstreaming](../movies-tv/direct-streaming-mode.md)
- [WebStreamr settings](../scrapers/webstreamr-settings.md)
- [Nuvio scrapers](../scrapers/nuvio.md)
- [Playback settings](../settings/playback-settings.md)
