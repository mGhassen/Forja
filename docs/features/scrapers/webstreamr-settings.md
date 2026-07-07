# WebStreamr settings

> Tune country sources, extractors, proxy helpers, and quality filters.

## What it is

WebStreamr runs locally inside Forja's Rust engine. This settings screen controls which [sources](webstreamr-sources.md) and [extractors](webstreamr-extractors.md) participate, plus optional helpers (MediaFlow Proxy, FlareSolverr, TMDB token).

## How to open it

**Settings → Providers & Addons → WebStreamr Settings**

## What you can do

- Toggle **enabled countries** for regional sources
- **Disable extractors** that cause problems
- **Exclude resolutions** from results
- Set **MediaFlow Proxy** URL and password (for MFP-backed extractors)
- Set **FlareSolverr** URL (Cloudflare bypass)
- Set **TMDB access token** (improves metadata matching for sources)

## Setup (optional)

| Field | When you need it |
|-------|------------------|
| TMDB token | Better title/year matching for obscure titles |
| MFP URL + password | FileMoon, DoodStream, Mixdrop, and similar hosts |
| FlareSolverr | Sites behind Cloudflare challenges |

## Tips

- Start with only your country codes enabled — fewer sources = faster searches
- After changing TMDB token or FlareSolverr URL, settings re-initialize WebStreamr automatically

## Related

- [WebStreamr sources](webstreamr-sources.md)
- [WebStreamr extractors](webstreamr-extractors.md)
- [Direct streaming mode](../movies-tv/direct-streaming-mode.md)
