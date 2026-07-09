# Stream providers

> Direct link extractors for movies and TV — order and failover when webstreaming plays.

## What it is

When [Webstreaming](../movies-tv/direct-streaming-mode.md) is enabled, Forja tries multiple **stream providers** in sequence until one returns playable links. Built-in providers include Videasy, VidLink, VixSrc, Vidnest, 111477, WebStreamr, and each enabled [Nuvio](../scrapers/nuvio.md) scraper.

## How to open it

**Settings → Playback → Provider order** — drag to reorder.

## What you can do

- Reorder providers (first = tried first)
- Combine built-in providers with Nuvio scrapers in one list
- Benefit from automatic failover in the player when a link dies

## Default providers (built-in)

Videasy · VidLink · VixSrc · Vidnest · 111477 · WebStreamr · (your Nuvio scrapers)

## Tips

- Put your fastest/most reliable provider at the top
- WebStreamr is powerful but slower — balance order vs speed
- Nuvio entries appear after you install addons

## Related

- [Webstreaming](../movies-tv/direct-streaming-mode.md)
- [WebStreamr settings](../scrapers/webstreamr-settings.md)
- [Nuvio scrapers](../scrapers/nuvio.md)
- [Playback settings](../settings/playback-settings.md)
