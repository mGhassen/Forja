# Watch history

> Pick up where you left off — automatic progress for movies and series.

## What it is

Forja saves playback position locally when you watch movies or TV episodes. **Continue watching** on Home shows in-progress titles with resume points. You can dismiss items you no longer want to see there.

## How to open it

- **Continue watching** row on [Home](home.md)
- Resume automatically when you reopen a title you partially watched

## What you can do

- Resume from Continue Watching by opening that title’s **details** first, then the **same path as details green Play / Resume** for current Settings → Playback: Webstreaming on → web extract (cache then resolve); Webstreaming off + Forja Auto → Forja plugin race (no sniff); otherwise Sources. Torrent / Stremio Direct resumes still use the saved magnet or addon when that was the last method. **Back** from the player returns to that details page
- See progress on the details hero (Resume + bar) and on continue watching cards — updates when you leave the player without leaving details
- Hover a continue watching card (desktop) to scale it and show a play button; hover the play button to turn it brand-green, float it upward, and pulse the icon — click opens details then resumes
- Dismiss entries from continue watching
- Episodes auto-mark **watched** when you reach **85%** (right-click or double-click still toggles); TV / anime / Asian Drama details show series progress (`N of T · %` or **Completed**). Those marks also bump My List / Simkl to **Watching**, or **Completed** when every episode is marked
- Movies show **Watched** with a check on details when finished (≥85%). Starting a movie also moves My List / Simkl to **Watching**; finishing ≥85% moves it to **Completed**
- Clear all continue watching (and watched marks) from **Settings → [Data & backup](../settings/cache-data.md)**

## Tips

- Watch history is per-device local data (not included in [Backup & restore](../settings/backup-restore.md) export today)
- Progress is saved while you watch (about every 15 seconds), when you pause, and when you leave. Pause does not keep rewriting Continue Watching
- [Trakt](../accounts/trakt.md) sync can complement local history when logged in
- [Simkl](../accounts/simkl.md) can seed a few missing continue-watching rows from in-progress titles (newest first; not your whole watching list every launch)
- Clearing continue watching from Settings only affects this device — Trakt / Simkl cloud history stays
- Progress at **85%+** counts as finished: Continue Watching / Play starts from the beginning (not the credits). On details, use the trash control next to Play to clear a false “Watched” bar

## Related

- [Home](home.md)
- [TMDB details](tmdb-details.md)
- [Player](../playback/player.md)
- [Cache & data](../settings/cache-data.md)
