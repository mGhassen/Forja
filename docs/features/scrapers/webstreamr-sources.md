# WebStreamr sources

> Built-in streaming sites (WebStreamrMBG-aligned), filtered by country and content type.

## What it is

WebStreamr searches regional streaming sites for embed pages matching your movie or series (via TMDB / IMDb ids). Each **source** is a specific site. Bases follow [WebStreamrMBG](https://github.com/newman2x/WebStreamrMBG) `src/source`. Sources are enabled or disabled by **country** in WebStreamr Settings.

## Built-in sources

| Source | Regions | Movies | TV |
|--------|---------|--------|-----|
| 4KHDHub | multi, IN langs | ✓ | ✓ |
| HDHub4u | multi, IN langs | ✓ | ✓ |
| VixSrc | multi | ✓ | ✓ |
| VidSrc | multi | ✓ | ✓ |
| VidZee | multi | ✓ | ✓ |
| MovieBox | multi | ✓ | ✓ |
| RGShows | multi | ✓ | ✓ |
| Kokoshka | AL | ✓ | ✓ |
| CineHDPlus | ES, MX | | ✓ |
| Cuevana | ES, MX | ✓ | ✓ |
| HomeCine | ES, MX | ✓ | ✓ |
| VerHdLink | ES, MX | ✓ | |
| Einschalten | DE | ✓ | |
| KinoGer | DE | ✓ | ✓ |
| MegaKino | DE | ✓ | |
| MeineCloud | DE | ✓ | |
| Filmpalast | DE | ✓ | ✓ |
| StreamKiste | DE | | ✓ |
| Frembed | FR | ✓ | ✓ |
| FrenchCloud | FR | ✓ | |
| Movix | FR | ✓ | ✓ |
| Eurostreaming | IT | | ✓ |
| MostraGuarda | IT | ✓ | |
| VegaMovies | multi, EN, HI | ✓ | ✓ |

`RGShows`, `StreamKiste`, and `VegaMovies` are Forja extras not in current MBG `createSources`.

**Note:** WebStreamr **VidSrc** uses `vidsrcme.ru`. The separate **VSEmbed** server uses `vsembed.su` and is not this source.

## How to open it

Used when [Webstreaming](../movies-tv/direct-streaming-mode.md) plays on TMDB details. Configure countries in **Settings → WebStreamr**.

## What you can do

- Enable country codes relevant to you (e.g. `de`, `fr`, `multi`)
- Disable regions you don't need for faster searches

## Tips

- `multi` sources work worldwide for many titles
- Pair with [extractors](webstreamr-extractors.md) — sources find embed pages, extractors resolve playable URLs

## Related

- [WebStreamr settings](webstreamr-settings.md)
- [WebStreamr extractors](webstreamr-extractors.md)
- [Stream providers](../sources/stream-providers.md)
