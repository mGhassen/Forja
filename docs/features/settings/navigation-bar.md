# Features

> Show, hide, and reorder tabs in the main shell.

## What it is

Customize which sections appear in the bottom nav (mobile) or side rail (desktop) and in what order. **Settings** always stays visible and cannot be removed. On desktop its pinned rail control is rendered as the active profile avatar (or Guest).

On a fresh install, all available tabs are enabled in this order: Home, Asian Drama, Anime, IPTV, Live Sports, My List, then Settings. Home is the default startup tab.

## How to open it

**Settings → Features**

## What you can do

- Toggle visibility for each available tab (Home, Asian Drama, Anime, Arabic, IPTV, Live Sports, My List) — on **TV**, **OK** on the tab name toggles visibility (same as the switch on desktop). **Hub tabs** come from installed `kind: catalog` plugins that declare `nav` — every new hub pack registers a Features row automatically.
- **Plugin on/off** (Settings → Sources → Forja → Hubs) is separate from **Features show/hide**. Turning a hub plugin off stops its content (tab shows a prompt to re-enable); hiding it under Features removes it from the nav. Turning Features on does not require the plugin to already be enabled.
- Reorder tabs — **drag** on desktop / phone; **↑/↓** on **TV** (same idea as server reliability order). On the web portal use up/down under **Profile settings → Features**
- Select the **star** beside a visible tab (or Settings) to make it the menu that opens when you launch the app (and after you switch to this profile mid-session) — works with mouse and with **OK** on TV
- Restore a cleaner bar by hiding unused hubs
- Sync the same layout across devices via [cloud sync](cloud-sync.md) (visible tabs + default tab)

Some hubs (Search, Discover, Similar, Media Downloader, Magnet, Audiobooks, Books, Music, Comics, Manga, Jellyfin, Anime Arabic) are temporarily withheld from this list and the shell — code remains; they are not deletable from Settings either.

Home, Asian Drama, Anime, and Arabic install from ForjaHQ hub packs (Settings → Sources → Forja → **Hubs**).

## Tips

- Hidden tabs (among the available ones) are still reachable if another screen deep-links to them
- Order is saved per device — use [backup & restore](backup-restore.md) to copy layout

## Related

- [Navigation](../getting-started/navigation.md)
- [Backup & restore](backup-restore.md)
