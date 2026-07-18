# Settings

> Category hub for playback, sources, accounts, data, and app preferences.

## What it is

Settings is organized as a **category hub** (not a long accordion). On desktop/wide screens, a left category rail stays open while the right pane shows the selected category. On phone and TV, you pick a category from a list, then open its detail page.

## How to open it

Select the profile avatar / Guest item pinned at the bottom of the desktop rail.
On other layouts, open the **Settings** tab (always available).

## Categories

Categories appear only when they match your profile. **VOD tabs** = Home, Search, Anime, Asian Drama, or My List.

| Category | What it covers | Shown when |
|----------|----------------|------------|
| [Profile & account](cloud-sync.md) | Active profile, Forja sign-in, cloud sync, sign out | Always |
| [Playback](playback-settings.md) | Play sources, server reliability, audio, auto next/skip, quality, IPTV EPG | Always (play sources / scoring / episode extras need a VOD tab; IPTV EPG needs the IPTV tab) |
| [Sources](torrent-settings.md) | Torrents, Stremio / Nuvio / Jackett / Prowlarr | VOD tab + Direct torrent and/or Stremio on |
| [WebStreamr](../scrapers/webstreamr-settings.md) | Country sources, extractors, resolutions, MFP, FlareSolverr, TMDB | VOD tab + Webstreaming on |
| Debrid | Real-Debrid, TorBox, AllDebrid, Premiumize, Debrid-Link | VOD tab + Direct torrent and/or Stremio on |
| Connected services | Trakt, Simkl, MDBlist | VOD tab |
| [Lists](../movies-tv/external-lists.md) | Trakt & MDBlist custom / top lists | VOD tab |
| [Data & backup](cache-data.md) / [Backup](backup-restore.md) | Clear caches & watch data; export/import JSON; IPTV portals CSV | Always (IPTV portals CSV / portal cache only if IPTV tab is on) |
| [Navigation](navigation-bar.md) | Tab visibility, order, default menu | Always |
| [About](app-updates.md) | Check for updates, app version | Always |

## Tips

- Only the selected category loads — opening Settings is lighter than the old all-sections page
- IPTV / Live Matches alone → movie Settings stay hidden until you turn a VOD tab back on in **Navigation**, then play sources under **Playback**
- On TV, use D-pad to move through categories, then into toggles and actions
- Theme / appearance picker is not shipped yet — see [Appearance](appearance.md)

## Related

- [Navigation](../getting-started/navigation.md)
- [Playback settings](playback-settings.md)
- [Platforms](../getting-started/platforms.md)
