# Settings

> Category hub for playback, sources, accounts, data, and app preferences.

## What it is

Settings is organized as a **category hub** (not a long accordion). On desktop,
wide screens, and **Android TV**, a left category rail stays open while the right
pane shows the selected category. On phone / narrow layouts, you pick a category
from a list, then open its detail page.

## How to open it

Select the profile avatar / Guest item pinned at the bottom of the desktop or
**Android TV** rail. On phone layouts, open the **Settings** tab (always available).

## Categories

Categories appear only when they match your profile. **VOD tabs** = Home, Search, Anime, Asian Drama, or My List.

| Category | What it covers | Shown when |
|----------|----------------|------------|
| [Profile & account](cloud-sync.md) | Active profile, Forja sign-in, cloud sync, sign out | Always |
| [Playback](playback-settings.md) | Play sources, server reliability, audio, auto next/skip, quality, IPTV EPG | Always (play sources / scoring / episode extras need a VOD tab; IPTV EPG needs the IPTV tab) |
| [Sources](torrent-settings.md) | Torrents, Stremio / Nuvio / Jackett / Prowlarr | VOD tab + Direct torrent / Stremio / Nuvio on — never on Android TV |
| [WebStreamr](../scrapers/webstreamr-settings.md) | Country sources, extractors, resolutions, MFP, FlareSolverr, TMDB | VOD tab + Webstreaming on |
| Debrid | Real-Debrid, TorBox, AllDebrid, Premiumize, Debrid-Link | VOD tab + Direct torrent / Stremio / Nuvio on — never on Android TV |
| Connected services | Trakt, Simkl, MDBlist | VOD tab |
| [Lists](../movies-tv/external-lists.md) | Trakt & MDBlist custom / top lists | VOD tab |
| [Data & backup](cache-data.md) / [Backup](backup-restore.md) | Clear caches & watch data; export/import JSON; IPTV portals CSV | Always (IPTV portals CSV / portal cache only if IPTV tab is on) |
| [Navigation](navigation-bar.md) | Tab visibility, order, default menu | Always |
| [About](app-updates.md) | Check for updates, crash reporting + product analytics opt-in, app version | Always |

## Tips

- Only the selected category loads — opening Settings is lighter than the old all-sections page
- IPTV / Live Matches alone → movie Settings stay hidden until you turn a VOD tab back on in **Navigation**, then play sources under **Playback**
- On **TV**, the bottom rail item is your **profile avatar** (same as desktop).
  **↑/↓** moves through the category sidebar (green left bar only — no gray
  focus ring; focusing a category selects it and updates the right pane, but
  focus stays on the left). **OK** or **→** opens that category’s right pane
  and moves focus to the first control there (each category’s detail is its own
  focus zone). **↑/↓/←/→** move to neighboring detail rows, toggles, chips,
  and buttons by on-screen position — D-pad stays in the right pane. **Back** returns to the selected
  category, then first category, then the nav rail. **←** on the first category
  also returns to the nav rail. **OK** in the detail pane flips a toggle /
  cycles a dropdown; nested switches do not steal focus. Text fields
  (API keys, URLs, etc.) take **focus** with the D-pad without opening the
  keyboard — press **OK** to type; **Back** leaves typing and keeps the field
  focused
- Theme / appearance picker is not shipped yet — see [Appearance](appearance.md)

## Related

- [Navigation](../getting-started/navigation.md)
- [Playback settings](playback-settings.md)
- [Platforms](../getting-started/platforms.md)
