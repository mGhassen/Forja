# Simkl

> Sync your watchlist and watch history with Simkl.

## What it is

Simkl is the tracker everyone can connect. Log in via PIN and sync what you watch between Forja and your Simkl account. Each Forja account and profile on this device keeps its own Simkl connection.

## How to open it

**Settings → Connected services → Simkl**

## What you can do

- Connect with a Simkl PIN (opens simkl.com/pin)
- View logged-in username
- **How should lists sync?** dropdown (saved):
  - **Keep local** — push this device’s statuses to Simkl
  - **Use Simkl** — overwrite this device from Simkl
  - **Merge** — combine both; same title with different status keeps the device
  - **Merge + delete** — same as Merge, plus titles you removed in Forja are removed from Simkl and not re-imported (new Simkl-only titles still import)
- Status changes go to Simkl immediately when connected. If Simkl won’t accept Completed for a still-airing series, Forja keeps Watching and tells you
  - **No sync** — Sync Now / Auto sync do nothing for list buckets
- **Sync Now** runs the saved mode (list + history) — no chooser dialog
- Toggle **Auto sync lists on My List** — when on, opening My List runs that saved mode and refreshes the cached Simkl library (throttled a couple of minutes so flipping status tabs does not re-sync)
- Browse Plan to Watch / Watching / On Hold / Completed / Dropped on the **My List** tab (Films / TV Shows / Anime filter like Home; Simkl lists while connected)
- Set Plan to Watch / Watching / On Hold / Completed / Dropped from details glass **+**, Home / Anime / Asian Drama poster **+**, or Home poster bookmark (same floating menu; always writes local; Simkl when connected) — movies/TV, Anime (AniList id), and Asian Drama (TMDB id when the KissKH title matches). Click the active status again to remove it from My List
- Playing Anime or Asian Drama that is new or Plan to Watch moves it to Watching
- Finishing an episode marks that episode watched on Simkl history and moves the show to Watching when it was new / Plan to Watch — **Completed** only when every episode of the series is marked (not after the first episode)
- Player scrobble is start / pause / stop with mid-episode **progress %** (Simkl can resume that pause) — pause does not keep pinging Simkl while idle
- Clearing progress (trash next to Resume) removes Simkl watched history so the title leaves Completed
- Import completed movies into local watch history
- Import completed TV + anime episodes as watched marks (anime uses AniList ids)
- Import in-progress watching into continue watching (background sync seeds at most ~20 newest missing resumes; Sync Now still does a full history pass)
- Export local watched episodes back to Simkl
- Log out

## Setup

1. Tap **Login with Simkl**
2. Enter the displayed code at the verification URL (copied + opened automatically)
3. Set **How should lists sync?** (Keep local / Use Simkl / Merge / Merge + delete / No sync)
4. Optionally turn on **Auto sync lists on My List**
5. Tap **Sync Now** to run the saved mode (list + history)

The app must be built with `SIMKL_CLIENT_ID` (repo-root `.env` for local `flutter run --dart-define-from-file`, GitHub secret for release). Register at [simkl.com/settings/developer](https://simkl.com/settings/developer). Full-restart after adding the key — hot reload will not pick it up.

## Tips

- While connected, My List shows Simkl for movies/TV/anime; Asian Drama / unmatched hub titles can still appear from local
- My List Open with… can attach a TMDB id for Simkl without changing the open hub (Open with vs Simkl **S** in the same sheet). Cards show linked **S**, or **S** with a red cross when not linked yet
- Cold-start sync updates watch history and continue watching. List buckets sync on Sync Now, connect, or **Auto sync lists on My List** when that toggle is on
- After the first sync, background history sync only pulls what changed since the last Simkl activity stamp (`date_from`), and skips entirely for ~15 minutes after a successful sync
- [Trakt](trakt.md) is admin-only and needs its own API app
- Not all Trakt features (calendars, lists UI) are duplicated for Simkl

## Related

- [Trakt](trakt.md)
- [My List](../movies-tv/my-list.md)
- [Watch history](../movies-tv/watch-history.md)
