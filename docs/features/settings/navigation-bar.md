# Features

> Show, hide, and reorder tabs in the main shell.

## What it is

Customize which sections appear in the bottom nav (mobile) or side rail (desktop) and in what order. **Settings** always stays visible and cannot be removed. On desktop its pinned rail control is rendered as the active profile avatar (or Guest).

On a fresh install, only **IPTV** (and always-visible **Settings**) are host-default. **Live Sports** is a host core tab that appears when you enable **Addons → Live Sports** (or Features). Other hub tabs appear under Features when their packs install — **on** the first time the host sees each tab. Star a visible tab to choose startup (Home is common after the official packs bundle).

## How to open it

**Settings → Features**

## What you can do

- Toggle visibility for each available tab (Home, Asian Drama, Anime, IPTV, Live Sports, My List) — on **TV**, **OK** on the tab name toggles visibility (same as the switch on desktop). **VOD hub tabs** appear only while their `kind: catalog` pack+plugin is **enabled** under Forja Packs. **Live Sports** stays available as a host feature whenever Addons / Features keeps it on.
- **Plugin on/off** (Settings → Sources → Forja → Hubs) controls whether a hub exists at all: turn it off and it **disappears** from Features and the nav rail. Among enabled hubs, Features show/hide still controls rail visibility.
- Reorder tabs — **drag** on desktop / phone; **↑/↓** on **TV** (same idea as server reliability order). On the web portal use up/down under **Profile settings → Features**
- Select the **star** beside a visible tab (or Settings) to make it the menu that opens when you launch the app (and after you switch to this profile mid-session) — works with mouse and with **OK** on TV
- Restore a cleaner bar by hiding unused hubs
- Sync the same layout across devices via [cloud sync](cloud-sync.md) (visible tabs + default tab)

Home, Asian Drama, Anime, and Arabic install from ForjaHQ hub packs (Settings → Forja Packs → **Hubs**). A newly contributed hub tab is **on** in Features the first time the host sees it; hide it here if you do not want it on the rail.

**Archived tabs** (Search, Discover, Similar, Magnet, Media Downloader, Audiobooks, Books, Music, Comics, Manga, Jellyfin, Anime Arabic) are withheld from this list — see [archive](../archive/README.md).

## Tips

- Hidden tabs (among the available ones) are still reachable if another screen deep-links to them
- Order is saved per device — use [backup & restore](backup-restore.md) to copy layout

## Related

- [Navigation](../getting-started/navigation.md)
- [Backup & restore](backup-restore.md)
