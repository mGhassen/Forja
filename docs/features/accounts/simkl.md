# Simkl

> Sync your watchlist and watch history with Simkl.

## What it is

Simkl is the tracker everyone can connect. Log in via PIN and sync what you watch between Forja and your Simkl account.

## How to open it

**Settings → Connected services → Simkl**

## What you can do

- Connect with a Simkl PIN (opens simkl.com/pin)
- View logged-in username
- Sync Simkl list buckets → local My List (backup if you disconnect)
- Browse Plan to Watch / Watching / On Hold / Completed / Dropped on the **My List** tab (Films / TV Shows / Anime filter like Home; Simkl lists while connected)
- Set Plan to Watch / Watching / On Hold / Completed / Dropped from details **+** (always writes local; Simkl when connected) — movies/TV, Anime (AniList id), and Asian Drama (TMDB id when the KissKH title matches)
- Playing Anime or Asian Drama that is new or Plan to Watch moves it to Watching
- Clearing progress (trash next to Resume) removes Simkl watched history so the title leaves Completed
- Import completed movies into local watch history
- Import completed TV + anime episodes as watched marks (anime uses AniList ids)
- Import in-progress watching into continue watching
- Export local My List / watched episodes back to Simkl
- Log out

## Setup

1. Tap **Login with Simkl**
2. Enter the displayed code at the verification URL (copied + opened automatically)
3. Wait for the app to confirm login, then optional **Sync Now**

The app must be built with `SIMKL_CLIENT_ID` (repo-root `.env` for local `flutter run --dart-define-from-file`, GitHub secret for release). Register at [simkl.com/settings/developer](https://simkl.com/settings/developer). Full-restart after adding the key — hot reload will not pick it up.

## Tips

- [Trakt](trakt.md) is admin-only and needs its own API app
- Not all Trakt features (calendars, lists UI) are duplicated for Simkl

## Related

- [Trakt](trakt.md)
- [Watch history](../movies-tv/watch-history.md)
