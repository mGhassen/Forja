# Arabic cinema

> **Archived:** Out of scope or not in the default navigation surface. See [Archive](../README.md).

> Browse and watch Arabic movies and series by category.

## What it is

The Arabic tab is a catalog hub from the ForjaHQ **Arabic** pack plugin `arabic-hub` (`kind: catalog`). Layout matches the Home hub shell: cinematic spotlight hero with a bleed row, Continue Watching slot, ranked Brstej, then category rails. The pack owns browse, search, and details for **Larozaa**, **DimaToon**, and **Brstej**. Playback uses the **Larozaa**, **DimaToon**, and **Brstej** Forja provider plugins — they extract direct HLS/MP4 in JS (same path as Videasy). The host only renders Catalog Shell + a thin details/player UI (`surface: arabic`). The tab only appears in **Settings → Features** while the Arabic pack/plugin is enabled under **Sources → Forja → Hubs** (Features visibility defaults off).

## How to open it

Enable the ForjaHQ Arabic pack under **Settings → Sources → Forja → Hubs**, turn **Arabic** on in **Settings → Features**, then tap **Arabic** in the navigation bar.

## What you can do

- Browse trending + category rails (Arabic series/movies, Turkish, Ramadan, TV programs, foreign / Indian / dubbed movies, anime movies, Brstej latest)
- Search across Larozaa, DimaToon, and Brstej
- Like titles for quick access
- Open pack-backed details and play episodes/servers in the player
- After a pack update, use **Settings → Sources → Forja → Refresh** so details/stream scripts reload

## Tips

- Playback uses **Settings → Sources → Forja** provider plugins (Larozaa / DimaToon / Brstej) with **Forja Auto Play** or the hub **Sources** panel — direct streams, not embed pages
- Pair with [Anime Arabic](anime-arabic.md) for dubbed anime (separate host feature)

## Related

- [Anime Arabic](anime-arabic.md)
- [Content hub scrapers](../../scrapers/content-hub-scrapers.md)
