# Stream providers

> Domain-scoped source engines pick scrapers; the player only sees playable streams.

## What it is

Forja resolves streams through a **Source Engine** middleware. Movie/TV scrapers never compete with anime or Asian Drama scrapers. Each domain has provider **profiles** (configured domain scores). Your **settings order** is the baseline; domain scores may adjust each provider by at most **±2** ranks before checking. The playback layer then scores resolved URLs against your device (codec, resolution, latency).

Built-in **webstreaming** movie/series providers include Videasy, VidLink, VixSrc, Vidnest, 111477, and WebStreamr. [Nuvio](../scrapers/nuvio.md) scrapers are **not** in this list — they live in the **Sources** panel under **Direct torrent**.

## How to open it

**Settings → Playback → Source scoring** — per-type tables with baseline rank, domain score, ±2 cap, and effective pre-check order.

**In player → Servers** — pick **Auto** (default) or pin a specific server.

## What you can do

- **Auto** — Source Engine races providers (up to six at once) and opens the first working hit. Other servers resolve when you pick them in the player menu.
- **Manual** — pick a server; Forja stays on it (strict — no silent cross-provider fallback)
- Source links are **not** pre-checked on open — tap a stream to probe it (status on the left). Use the hover **play** arrow to switch. The current stream keeps playing until a play succeeds
- The **score badge** starts at each provider’s domain tier (e.g. VixSrc **75**) and **updates live** while the panel is open — **down** when server/stream checks fail, **up** when they succeed (persisted across sessions). While that server is **Playing now**, the badge stays at least the base tier
- Reorder providers in Settings (baseline per domain; effective order preview in table)
- On decoder failure, try the next compatible source, then software decode once

## Domains

| Domain | Typical engines |
|--------|-----------------|
| Movies / TV | Videasy, VidLink, WebStreamr, … |
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
