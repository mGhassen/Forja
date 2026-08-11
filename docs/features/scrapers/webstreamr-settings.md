# WebStreamr settings

> Tune country sources, extractors, proxy helpers, and quality filters.

## What it is

WebStreamr runs locally inside Forja's Rust engine. This settings screen controls which [sources](webstreamr-sources.md) and [extractors](webstreamr-extractors.md) participate, plus optional helpers (MediaFlow Proxy, FlareSolverr, TMDB token).

## How to open it

**Settings → WebStreamr** (admin accounts only — category appears when **Webstreaming** is enabled under **Settings → Playback** and the signed-in account has `is_admin`)

## What you can do

- Toggle **enabled countries** for regional sources — these apply on **Play** via the Resolver Engine (not just this screen)
- **Disable extractors** that cause problems
- **Exclude resolutions** from results
- Set **MediaFlow Proxy** URL and password (for MFP-backed extractors)
- Set **FlareSolverr** URL (stored for future use — Rust extractors do not call FlareSolverr yet)
- Set **TMDB access token** (improves metadata matching for sources)

## Setup (optional)

| Field | When you need it |
|-------|------------------|
| TMDB token | Better title/year matching for obscure titles |
| MFP URL + password | FileMoon, DoodStream, Mixdrop, and similar hosts |
| FlareSolverr | Prefs only — not used by the Rust resolve path yet |

## Tips

- Enabled countries control which regional sources run on **Play** (via Resolver Engine) as well as in WebStreamr Settings previews — keep `de` / `hi` / etc. on if you want KinoGer, MegaKino, HDHub4u-style results
- Start with only your country codes enabled — fewer sources = faster searches
- After changing countries / extractors / MFP / TMDB token, the next Play resolve picks them up (no app restart needed for prefs)

## Related

- [WebStreamr sources](webstreamr-sources.md)
- [WebStreamr extractors](webstreamr-extractors.md)
- [Direct streaming mode](../movies-tv/direct-streaming-mode.md)
