# Trakt

> Sync watch state, ratings, lists, and calendars with Trakt.tv.

## What it is

Trakt connects your Forja activity to Trakt.tv — OAuth login, sync watched items, recommendations on Home, TV/movie calendars, user lists, and rating from details screens.

**Admin only.** Regular accounts do not see Trakt in Settings. Use [Simkl](simkl.md) instead.

## How to open it

**Settings → Connected services → Trakt** (admin accounts — green sparkles on the group)

## What you can do

- Log in with device code (visit trakt.tv/activate)
- Sync watch history and scrobbles (start / pause / stop with playback — pause does not keep pinging Trakt)
- See username and stats in Settings
- Browse Trakt lists via [External lists](../movies-tv/external-lists.md)
- Get recommendation and calendar rails on [Home](../movies-tv/home.md)
- Rate titles from TMDB details

## Setup

Needs `TRAKT_CLIENT_ID` / `TRAKT_CLIENT_SECRET` at build time (`.env` or dart-define). Register an app at [trakt.tv/oauth/applications](https://trakt.tv/oauth/applications) with redirect URI `urn:ietf:wg:oauth:2.0:oob`, then full-restart `flutter run`.

1. Tap **Login with Trakt** in Settings
2. Enter the code shown at trakt.tv/activate
3. Wait for authorization — app polls automatically

## Tips

- Sync may take a moment after login — use manual sync if offered
- Trakt complements local [watch history](../movies-tv/watch-history.md)

## Related

- [External lists](../movies-tv/external-lists.md)
- [Home](../movies-tv/home.md)
- [Simkl](simkl.md)
