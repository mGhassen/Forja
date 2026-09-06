# Features

> Show, hide, and reorder tabs in the main shell.

## What it is

Customize which sections appear in the bottom nav (mobile) or side rail (desktop) and in what order. **Settings** always stays visible and cannot be removed. On desktop its pinned rail control is rendered as the active profile avatar (or Guest).

On a fresh install, only **Settings** is visible on the rail — no Addons (IPTV, Live Sports, torrent, …) are on. **Settings → Features** still lists **IPTV** and **Live Sports** (off) so you can enable them here or under Addons. Other hub tabs (Home, Anime, …) appear under Features when their packs install — **on** the first time the host sees each tab. Star a visible tab to choose startup (Home is common after the official packs bundle).

## How to open it

**Settings → Features**

## What you can do

- Show, hide, and reorder tabs. On **TV**: **OK** on the tab row toggles visibility; star sets default; ↑/↓ on the reorder arrows move the tab. **↓** from a tab goes to the next tab; **↓** from star / reorder stays on that action for the next row. On desktop/phone: drag to reorder. Settings stays visible.
- Toggle visibility for each available tab (Home, Asian Drama, Anime, IPTV, Live Sports, My List). **VOD hub tabs** appear only while their `kind: catalog` pack+plugin is **enabled** under Forja Packs. **Live Sports** stays available whenever Addons / Features keeps it on.
- **Plugin on/off** (Settings → Sources → Forja → Hubs) controls whether a hub exists at all. Turn it off and it disappears from Features and the nav rail. Among enabled hubs, Features show/hide still controls rail visibility.
- Select the **star** beside a visible tab (or Settings) to choose the menu that opens at launch (and after you switch to this profile). Works with mouse and with **OK** on TV.
- Hide unused hubs for a cleaner bar.
- Sync the same layout across devices via [cloud sync](cloud-sync.md) (visible tabs + default tab). Edits wait until they are saved locally before syncing, so a toggle does not snap back off when the window refocuses.

Home, Asian Drama, Anime, and Arabic install from ForjaHQ hub packs (Settings → Forja Packs → **Hubs**). A newly contributed hub tab is **on** in Features the first time the host sees it; hide it here if you do not want it on the rail.

**Archived tabs** (Search, Discover, Similar, Magnet, Media Downloader, Audiobooks, Books, Music, Comics, Manga, Jellyfin, Anime Arabic) are withheld from this list — see [archive](../archive/README.md).

## Tips

- Hidden tabs (among the available ones) are still reachable if another screen deep-links to them
- Order is saved per device — use [backup & restore](backup-restore.md) to copy layout

## Related

- [Navigation](../getting-started/navigation.md)
- [Backup & restore](backup-restore.md)
