# Stream providers

> Domain-scoped source engines pick scrapers; the player only sees playable streams.

## What it is

Forja resolves streams through a **Source Engine** middleware. Movie/TV scrapers never compete with anime or Asian Drama scrapers. Each domain has provider **profiles** (priority per domain). The playback layer then scores URLs against your device.

Built-in movie/series providers include Videasy, VidLink, VixSrc, Vidnest, 111477, WebStreamr, and each enabled [Nuvio](../scrapers/nuvio.md) scraper.

## How to open it

**Settings → Playback → Provider order** — drag to reorder (tiebreak when profile scores are close).

**In player → Servers** — pick **Auto** (default) or pin a specific server.

## What you can do

- **Auto** — Source Engine tries providers **one at a time** (stops after the first working hit). Other servers resolve when you pick them.
- **Manual** — pick a server; Forja stays on it (strict — no silent cross-provider fallback)
- Source links are **not** pre-checked on open — Forja validates a source when you tap it, while the current stream keeps playing, then swaps if it works
- Reorder providers in Settings (bias only within the same domain)
- On decoder failure, try the next compatible source, then software decode once

## Domains

| Domain | Typical engines |
|--------|-----------------|
| Movies / TV | Videasy, VidLink, WebStreamr, Nuvio, … |
| Anime | Miruro, AllAnime, AnimeRealms, … |
| Asian Drama | KissKH |
| IPTV | Xtream / M3U / Stalker (portal) |
| Torrent | Local / debrid |

## Tips

- New users: leave **Auto** on
- Power users: pin a server from the player menu
- WebStreamr is powerful but slower — profile priority keeps it lower by default
- External players (VLC, MX Player) bypass Forja’s automatic fallback chain

## Related

- [Webstreaming](../movies-tv/direct-streaming-mode.md)
- [WebStreamr settings](../scrapers/webstreamr-settings.md)
- [Nuvio scrapers](../scrapers/nuvio.md)
- [Playback settings](../settings/playback-settings.md)
