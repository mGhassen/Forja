# Simkl

> Sync your watchlist and watch history with Simkl.

## What it is

Simkl is the tracker everyone can connect. Log in via PIN and sync what you watch between Forja and your Simkl account.

## How to open it

**Settings → Connected services → Simkl**

## What you can do

- Connect with a Simkl PIN (opens simkl.com/pin)
- View logged-in username
- On connect or **Sync Now**, choose how My List buckets sync:
  - **Keep local** — push this device’s statuses to Simkl
  - **Use Simkl** — overwrite this device from Simkl
  - **Merge** — combine both; same title with different status keeps the device
  - **No sync** — do nothing (Back / dismiss also does nothing)
- Browse Plan to Watch / Watching / On Hold / Completed / Dropped on the **My List** tab (Films / TV Shows / Anime filter like Home; Simkl lists while connected)
- Set Plan to Watch / Watching / On Hold / Completed / Dropped from details glass **+**, Home / Anime / Asian Drama poster **+**, or Home poster bookmark (same floating menu; always writes local; Simkl when connected) — movies/TV, Anime (AniList id), and Asian Drama (TMDB id when the KissKH title matches). Click the active status again to remove it from My List
- Playing Anime or Asian Drama that is new or Plan to Watch moves it to Watching
- Clearing progress (trash next to Resume) removes Simkl watched history so the title leaves Completed
- Import completed movies into local watch history
- Import completed TV + anime episodes as watched marks (anime uses AniList ids)
- Import in-progress watching into continue watching
- Export local watched episodes back to Simkl
- Log out

## Setup

1. Tap **Login with Simkl**
2. Enter the displayed code at the verification URL (copied + opened automatically)
3. When login succeeds, pick Keep local / Use Simkl / Merge — or **No sync** / Back to skip entirely
4. Use **Sync Now** anytime to choose again

The app must be built with `SIMKL_CLIENT_ID` (repo-root `.env` for local `flutter run --dart-define-from-file`, GitHub secret for release). Register at [simkl.com/settings/developer](https://simkl.com/settings/developer). Full-restart after adding the key — hot reload will not pick it up.

## Tips

- While connected, My List shows Simkl for movies/TV/anime; Asian Drama / unmatched hub titles can still appear from local
- Background sync no longer silently overwrites local list buckets — only your chooser does
- [Trakt](trakt.md) is admin-only and needs its own API app
- Not all Trakt features (calendars, lists UI) are duplicated for Simkl

## Related

- [Trakt](trakt.md)
- [My List](../movies-tv/my-list.md)
- [Watch history](../movies-tv/watch-history.md)
