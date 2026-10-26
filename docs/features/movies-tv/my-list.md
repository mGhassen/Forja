# My List

> Bookmark movies and shows to watch later.

## What it is

My List is a **hub pack** you install (pack-product host — same class as Home or Live Sports). It shows kind filters and status tabs in the shell top bar plus a poster grid of your bookmarks. Local bookmarks and Simkl stay on the device; the pack composes what you see via the host store bridge.

## How to open it

Install and enable the **ForjaHQ My List** hub pack, then show **My List** under **Settings → Features** / the nav rail (pack first-seen defaults the tab on).

## What you can do

- Filter the grid with **Film / Series / Anime / Asian Drama** (labels from the pack; tap again to show everything) — hover and focus match Home **Films** / **TV Shows** (bright white label + short underline)
- Switch **Plan to Watch / Watching / On Hold / Completed / Dropped** — the grid opens from the list saved on this device. With Simkl connected, that library is loaded once and reused for every status tab. Status tab labels stay white on hover/focus; green is only the selected underline. Change status from the card bookmark on desktop/mobile (same menu as Home). On **Android TV**, Open with… includes the status pin leftmost (before Match / Open with) with the same dropdown — cards omit the overlay pin so D-pad stays on the poster. Home / hub poster pins show the same colored status as My List (one bookmark identity for TMDB titles). Opening the status menu highlights the current status in that status’s color.
- Open a title — uses the hub saved on that bookmark when known (**Home** / **Anime** / **Asian Drama**, etc.). If the title could open in more than one hub (or has no hub yet), Forja opens an **Open with…** sheet: pick the hub, then confirm the title match (edit the search if needed — same / closest title is listed first). **Right-click** (desktop) or **long-press ~2s** (touch / TV) on a poster → same sheet; with Simkl connected the pack adds **Match** (TMDB for Simkl) vs **Open with** (hub chips) — labels and pin come from pack `openBind`. Dialog title switches with the mode. Check a title to save; the sheet stays open. The next click on the poster opens that hub. Details overlay switches the nav to the chosen hub (Back leaves you there). On **TV**, entering the tab focuses the first kind tab. **↓** goes to status then the grid; arrow keys move between posters; **←** from the first column returns to the nav rail.
- With Simkl connected, each My List poster shows a white Simkl logo on the bottom-right of the year · type line when linked, or the logo with a red cross when not — tap to open Match.
- Set **default open hubs** on the **My List** pack (**Settings → Addons → My List**, or expand the pack under Forja Packs). Options are hubs you have installed that match each type. Used when the bookmark has no hub saved yet (Open with… / a prior bind). Auto still means the first matching hub
- Add or move a title from details **+** or a poster bookmark (same five statuses, with or without Simkl) — movies/TV, Anime, and Asian Drama. The card shows on **My List** right away (no pull-to-refresh). Click the active status again to remove it; the card leaves that tab right away (Completed / On Hold / Dropped included) without reloading the whole grid. Local status wins over a slow Simkl refresh or Simkl rewriting Completed on still-airing shows back to Watching.
- Playing a **movie** adds it as **Watching** (or upgrades Plan to Watch). Finishing ≥85% moves it to **Completed**. TV / Anime / Asian Drama still follow episode watched marks for those buckets
- Asian Drama titles have their own kind filter. Unmatched titles stay local and still show while Simkl is connected
- Disconnect Simkl and the local buckets are still there

## Tips

- The My List tab icon ships in the pack (`icons/nav.png`)
- My List statuses are stored locally on your device. With Simkl connected, the open tab prefers your local status for titles you’ve already bookmarked, and still lists Simkl-only rows. Opening a title remembers the hub without changing its status. Settings → Simkl has **How should lists sync?** (saved, including **Merge + delete**) and **Sync Now** runs that mode
- Titles missing a poster or a year fill from TMDB. Cards that already have both open with the saved list.
- Cards show **year • type** under the title when known (from the bookmark, Simkl, the title, or TMDB) — including on **Android TV** (same footer as desktop; titles stay a bit smaller so more of the name fits)
- Use [Backup & restore](../settings/backup-restore.md) to move lists to another install

## Related

- [Watch history](watch-history.md)
- [External lists](external-lists.md)
- [Simkl](../accounts/simkl.md)
- [Trakt](../accounts/trakt.md)
