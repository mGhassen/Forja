# Stremio addons

> Install Stremio-compatible addons for catalogs, streams, search, subtitles, and Live Matches sports.

## What it is

Stremio addons are manifest-based extensions. Forja supports installing the same manifest URLs as Stremio — for searching in the Search tab, streaming on details screens, fetching subtitles in the player, and (for sport addons) feeding the Live Matches **Stremio** server.

Each installed addon is assigned to one or both features:

| Chip | Where it runs |
|------|----------------|
| **Sources** | Search · media-details Sources · VOD stream chips |
| **Live Matches** | Live Matches → Servers → **Stremio** (sport catalogs + HLS) |

Sport-only manifests (e.g. [Highfly Sports Streams](https://sportsfree-us2.highfly.dev/configure)) default to **Live Matches**. Movie/series addons default to **Sources**. You can change the chips anytime.

## How to open it

**Settings → Sources → Stremio addons** (also on the web account Stremio page)

## What you can do

- Paste a manifest URL and install
- Enable or disable an installed addon with the switch next to trash (keeps the install; skips resolve / catalogs / Live Matches when off)
- Toggle **Sources** / **Live Matches** per addon (at least one stays on)
- View installed addons and remove them (trash → Yes / No confirm, same as IPTV portal delete)
- Browse catalogs ([Stremio catalog](../movies-tv/stremio-catalog.md)) when targeting Sources
- Search addon content ([Search](../movies-tv/search.md))
- Play addon streams from [Media details](../movies-tv/media-details.md) — Sources → **Stremio** shows one chip per Sources-targeted addon that declares a `stream` resource
- Play sport HLS from [Live Matches](../live/live-matches.md) when targeting Live Matches
- Use subtitle-capable addons in the [player](../playback/subtitles.md)

## Setup

1. Find a Stremio addon manifest URL (ends with `/manifest.json`, or copy the install URL from a configure page)
2. Paste in **Install Stremio Addon** and tap Install
3. Confirm the **Sources** / **Live Matches** chips — sport addons should have **Live Matches** on
4. Use the switch next to trash to turn an addon off without uninstalling
5. For Live Matches: open **Live Matches → Servers → Stremio**

## Tips

- Not every addon implements catalog, stream, and search — check the addon's manifest resources
- Sport-only / live-named catalogs (e.g. flixnest `*-live*`) default to **Live Matches** and are skipped by global Search
- Cloud sync stores addon URLs + feature targets + disabled state; the app re-fetches missing manifests in parallel (a few at a time) on sync / Sources so stream chips stay correct. Addons that time out or return 403 are skipped for a short cooldown instead of stalling the whole list
- Community addon lists change frequently — verify manifests are trustworthy
- **Hash-based streams** (`infoHash`, e.g. Torrentio): on desktop and Android phone, Forja plays these via the local torrent engine or debrid. On **web**, only direct `url` streams and debrid-resolved hashes work — hash-only addons need debrid configured or streams are hidden. **Android TV** plays direct `url` streams on the TV; hash / magnet rows need a paired desktop (LAN) — a dialog prompts to pair if you pick one while unpaired. Sport addons for Live Matches still work when that tab is enabled
- If **Torrentio** fails (Cloudflare / HTTP 403) while another stream addon works, Sources switches the provider chip to the addon that returned streams — pick Torrentio again only if you want to retry that addon alone
- Premium / “upgrade” bait URLs from sport addons are skipped; only direct HTTP(S) stream URLs play

## Platform playback

| Platform | `url` streams (VOD) | `infoHash` (no debrid) | `infoHash` + debrid | Live sport HLS |
|----------|---------------------|------------------------|---------------------|----------------|
| Desktop, Android, iOS | Play direct | Local torrent engine | Debrid URL | Native IPTV player |
| Web | Play direct | Requires debrid | Debrid URL | — |
| Android TV | Play direct | Pair desktop (dialog if unpaired) | Debrid URL | Native IPTV player via Live Matches |

Capability profile: `PlatformPlayback.capabilities` in `packages/rust/lib/src/playback/platform/playback_profile.dart`. Stream resolution: `resolveStremioStream()` in `stremio_stream_resolver.dart`.

## Related

- [Live Matches](../live/live-matches.md)
- [Stremio catalog](../movies-tv/stremio-catalog.md)
- [Search](../movies-tv/search.md)
- [Media details](../movies-tv/media-details.md)
