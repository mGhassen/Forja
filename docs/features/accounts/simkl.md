# Simkl

> Sync your watchlist and watch history with Simkl.

## What it is

Simkl is the tracker everyone can connect. Log in via PIN and sync what you watch between Forja and your Simkl account.

## How to open it

**Settings → Connected services → Simkl**

## What you can do

- Connect with a Simkl PIN (opens simkl.com/pin)
- View logged-in username
- Sync watchlist and watched episodes (import + export)
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
