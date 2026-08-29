# Prowlarr

> Connect Prowlarr for indexer search with optional tag filtering.

## What it is

[Prowlarr](https://github.com/Prowlarr/Prowlarr) is the modern *arr-family indexer manager. Like Jackett, it feeds extra torrent results into Forja. You can optionally limit search to indexers tagged in Prowlarr.

## How to open it

**Settings → Sources → Prowlarr** (admin accounts — green sparkles on the group) — URL, API key, and optional tags.

## What you can do

- Configure Prowlarr base URL and API key
- Test connection
- Select Prowlarr tags to filter which indexers are queried
- Merge results on [Media details](../movies-tv/media-details.md)

## Setup

1. Run Prowlarr and add indexers
2. Create tags in Prowlarr if you want filtered search
3. In Forja: enter URL, API key, load tags, select which tags to use
4. Test connection

## Tips

- Use tags to separate "movies only" vs "TV only" indexers
- Prowlarr and Jackett are alternatives — you don't need both unless you want maximum coverage

## Related

- [Jackett](jackett.md)
- [Torrent scrapers](torrent.md)
