# Features

> Show, hide, and reorder tabs in the main shell.

## What it is

Customize which sections appear in the bottom nav (mobile) or side rail (desktop) and in what order. **Settings** always stays visible and cannot be removed. On desktop its pinned rail control is rendered as the active profile avatar (or Guest).

**Two layers:**

1. **Addons** / **Forja Packs** — turn a feature **on** (the system or hub exists). That only adds a row under Features; it does **not** put the tab on the rail.
2. **Features** — only place that shows or hides a tab on the navbar, reorders tabs, and stars the startup tab.

Turn IPTV / Live Sports off in Addons and they leave Features and the rail. Disable a hub pack and that hub leaves Features and the rail.

On a fresh install, only **Settings** is on the rail. Enable IPTV / Live Sports under **Addons**, then turn those tabs on here. Enable hub packs under **Forja Packs**, then turn hub tabs on here.

## How to open it

**Settings → Features**

## What you can do

- Show, hide, and reorder tabs that Addons / packs have made available. On **TV**: **OK** on the tab row toggles rail visibility; star sets default; ↑/↓ on the reorder arrows move the tab. **↓** from a tab goes to the next tab; **↓** from star / reorder stays on that action for the next row. On desktop/phone: drag to reorder. Settings stays visible.
- **Plugin on/off** (Settings → Forja Packs) controls whether a hub feature exists. Turn it off and it disappears from Features and the nav rail.
- Select the **star** beside a visible tab (or Settings) to choose the menu that opens at launch (and after you switch to this profile). Works with mouse and with **OK** on TV.
- Sync the same layout across devices via [cloud sync](cloud-sync.md) (visible tabs + default tab + Addons feature flags). Edits wait until they are saved locally before syncing, so a toggle does not snap back off when the window refocuses.

Home, Asian Drama, Anime, and Arabic install from ForjaHQ hub packs (Settings → Forja Packs → **Hubs**). After a pack is enabled, turn its tab on here to show it on the rail.

**Archived tabs** (Search, Discover, Similar, Magnet, Media Downloader, Audiobooks, Books, Music, Comics, Manga, Jellyfin, Anime Arabic) are withheld from this list — see [archive](../archive/README.md).

## Tips

- Hidden tabs (among the available ones) are still reachable if another screen deep-links to them
- Order is saved per device — use [backup & restore](backup-restore.md) to copy layout

## Related

- [Navigation](../getting-started/navigation.md)
- [Backup & restore](backup-restore.md)
