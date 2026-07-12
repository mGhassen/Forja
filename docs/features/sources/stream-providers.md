# Stream providers

> Direct link extractors for movies and TV — order, scoring, and automatic failover.

## What it is

When [Webstreaming](../movies-tv/direct-streaming-mode.md) is enabled, Forja resolves multiple **stream providers** and picks the best playable source for your device. Built-in providers include Videasy, VidLink, VixSrc, Vidnest, 111477, WebStreamr, and each enabled [Nuvio](../scrapers/nuvio.md) scraper.

The playback engine normalizes every provider into the same internal format, scores streams against your device capabilities (codec support, max resolution), and opens the highest-ranked candidate. You do not need to know which provider supplied the link.

## How to open it

**Settings → Playback → Provider order** — drag to reorder (used as a score bias, not a hard gate).

## What you can do

- Reorder providers (higher = preferred when scores are close)
- Combine built-in providers with Nuvio scrapers in one list
- Automatic failover when a link dies or your device cannot decode a stream
- On decoder failure, Forja tries the next compatible source, then software decode once, then the next provider

## Default providers (built-in)

Videasy · VidLink · VixSrc · Vidnest · 111477 · WebStreamr · (your Nuvio scrapers)

## Tips

- Put your fastest/most reliable provider at the top
- WebStreamr is powerful but slower — balance order vs speed
- Nuvio entries appear after you install addons
- External players (VLC, MX Player) bypass Forja’s automatic fallback chain

## Related

- [Webstreaming](../movies-tv/direct-streaming-mode.md)
- [WebStreamr settings](../scrapers/webstreamr-settings.md)
- [Nuvio scrapers](../scrapers/nuvio.md)
- [Playback settings](../settings/playback-settings.md)
