# My List

> Bookmark movies and shows to watch later.

## What it is

My List is a **hub pack** you install — same class as Home or Live Sports. It shows kind filters and status tabs in the shell top bar plus a poster grid of your bookmarks. Local bookmarks and Simkl stay on the device; the pack composes what you see.

## How to open it

Install and enable the **ForjaHQ My List** hub pack, then show **My List** under **Settings → Features** / the nav rail (pack first-seen defaults the tab on).

## What you can do

- Filter the grid with **Film / Series / Anime / Asian Drama** (labels from the pack; tap again to show everything)
- Switch **Plan to Watch / Watching / On Hold / Completed / Dropped** — local uses the same buckets; with Simkl, the open tab loads from Simkl. Change status from the card bookmark on desktop/mobile (same menu as Home); on Android TV use details / hero. Home / hub poster pins show the same colored status as My List (one bookmark identity for TMDB titles). Opening the status menu highlights the current status in that status’s color.
- Open a title — uses the hub saved on that bookmark when known (**Home** / **Anime** / **Asian Drama**, etc.). If the title could open in more than one hub (or has no hub yet), Forja asks which hub to use, then remembers the choice. **Right-click** (desktop) or **long-press ~2s** (touch / TV) on a poster → **Open with…** to change the hub. Cross-hub picks that need a different id (e.g. Simkl show → Asian Drama) search that hub by title so you can confirm the match. Details overlay switches the nav to the chosen hub (Back leaves you there). On **TV**, entering the tab focuses the first kind tab. **↓** goes to status then the grid; arrow keys move between posters; **←** from the first column returns to the nav rail.
- Set **default hubs** under **Settings → Data & backup → My List open hubs** — one row per engine type that your **installed** details hubs declare (labels come from those hubs). Used only when a row has matching ids and no saved hub yet
- Add or move a title from details **+** or a poster bookmark (same five statuses, with or without Simkl) — movies/TV, Anime, and Asian Drama. The card shows on **My List** right away (no pull-to-refresh). Click the active status again to remove it; the card leaves that tab right away (Completed / On Hold / Dropped included) without reloading the whole grid. Local status wins over a slow Simkl refresh or Simkl rewriting Completed on still-airing shows back to Watching.
- Playing a **movie** adds it as **Watching** (or upgrades Plan to Watch). Finishing ≥85% moves it to **Completed**. TV / Anime / Asian Drama still follow episode watched marks for those buckets
- Asian Drama titles have their own kind filter. Unmatched titles stay local and still show while Simkl is connected
- Disconnect Simkl and the local buckets are still there

## Tips

- The My List tab icon ships in the pack (`icons/nav.png`)
- My List statuses are stored locally on your device. With Simkl connected, the open tab prefers your local status for titles you’ve already bookmarked, and still lists Simkl-only rows. Connecting or Sync Now asks Keep local / Use Simkl / Merge — or No sync / Back to do nothing
- Titles missing posters (especially Simkl anime) fill from TMDB in the background when a TMDB id is known — pull to refresh if art stays blank
- Use [Backup & restore](../settings/backup-restore.md) to move lists to another install

## Related

- [Watch history](watch-history.md)
- [External lists](external-lists.md)
- [Simkl](../accounts/simkl.md)
- [Trakt](../accounts/trakt.md)
