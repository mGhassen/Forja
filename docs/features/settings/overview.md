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

Categories appear only when they match your profile. **VOD tabs** = Home, Search, Anime, Asian Drama, or My List. Admin-only entries (Debrid and some About rows) show green sparkles next to the title when you can see them.

| Category | What it covers | Shown when |
|----------|----------------|------------|
| [Profile & account](cloud-sync.md) | Active profile, Forja sign-in, cloud sync, sign out | Always |
| [Forja Packs](forja-packs.md) | Install and manage Forja JS plugin manifests (providers, hubs, live, …) | Always |
| [Features](navigation-bar.md) | Tab visibility, order, default menu | Always |
| [Sources](torrent-settings.md) | **Forja addons** — Direct torrent, Stremio, Nuvio toggles + install | Always |
| Debrid | Real-Debrid, TorBox, AllDebrid, Premiumize, Debrid-Link | Admin only · VOD tab + Direct torrent / Stremio / Nuvio on — never on Android TV |
| [Forja Sports](forja-sports.md) | Live plugins, catalog feeds, leagues, Enable Forja Sports | Live Matches + IPTV tabs on |
| Connected services | Simkl; MDBlist (admin) | VOD tab (MDBlist rows are admin-only) |
| [LAN](lan.md) | Desktop server, pairing, torrent relay to phone/TV | Always |
| [Data & backup](cache-data.md) / [Backup](backup-restore.md) | Clear caches & watch data; export/import JSON; IPTV portals CSV | Phone / desktop (IPTV portals CSV / portal cache only if IPTV tab is on) — never on Android TV |
| [About](app-updates.md) | Check for updates, app version; Privacy / Developer rows for admins | Always |

## Tips

- Only the selected category loads — opening Settings is lighter than the old all-sections page
- IPTV / Live Matches alone → **Sources → Forja addons** and **Forja Packs** are always in the category list (no VOD tab required). Play-source toggles for Direct torrent / Stremio / Nuvio live under **Sources**; pack install UI lives under **Forja Packs** (Forja providers always on). Movie-only rows (Debrid, Simkl) stay hidden until a VOD tab is on in **Features**
- On **TV**, the bottom rail item is your **profile avatar** (same as desktop).
  **↑/↓** moves through the category sidebar (flat green left bar + ink fill —
  no rounded hover card; focusing a category selects it and updates the right pane, but
  focus stays on the left). **OK** or **→** opens that category’s right pane
  and moves focus to the first control there (each category’s detail is its own
  focus zone). Detail rows use the **same green left bar + tint** on hover /
  D-pad focus (not a bordered box). **↑/↓** (and **←/→** as the same prev/next) walk the detail
  controls in a **vertical list** — not sideways between neighbors; long lists
  (e.g. Playback) scroll so the focused row stays visible; focusing the **first**
  control (or any control near the top of the page) snaps the detail scroll
  back to the top so the category title and section labels stay on screen;
  holding **↑/↓** speeds up the further you hold; D-pad stays in the
  right pane. **Back** returns to the selected
  category, then first category, then the nav rail. **←** on the first category
  also returns to the nav rail. **OK** in the detail pane flips a toggle or
  opens a select’s option list (current choice highlighted; **Back** dismisses).
  Nested switches do not steal focus. Text fields
  (API keys, URLs, etc.) take **focus** with the D-pad without opening the
  keyboard — press **OK** to type; **Back** leaves typing and keeps the field
  focused
- Theme / appearance picker is not shipped yet — see [Appearance](appearance.md)

## Related

- [Navigation](../getting-started/navigation.md)
- [Playback settings](playback-settings.md)
- [Platforms](../getting-started/platforms.md)
