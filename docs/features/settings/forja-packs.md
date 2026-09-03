# Forja Packs

> Install and manage Forja JS plugin manifests (providers, hubs, live, torrent indexers, …).

## What it is

**Forja Packs** is where you install `manifest.json` URLs, enable packs, and refresh updates. Forja provider play is always on when your platform supports it. This is separate from **Sources → Forja addons** (Direct torrent, Stremio, Nuvio).

## How to open it

**Settings → Forja Packs**

## What you can do

- Paste a pack **manifest.json** URL and **Install**
- **Update** / **Update all** when a remote pack version is newer
- Enable or disable each installed pack; expand for per-plugin toggles (Providers, Live, Hubs, Torrent, …)
- **Refresh** or **Remove** a pack

`forja://install?manifest=…` deep links open **Forja Packs** and ask before installing.

**Batch add** from the web catalog (`Shift+click` multiple packs → **Add N to Forja**) opens the running app with a checkable install dialog. Packs download only after you confirm. If the app is closed, packs sync to your profile and the same picker appears on next sign-in — never a silent mass install. Play / Sources / boot never silent-repair or auto-update packs either — missing scripts open the same confirm prompt; version bumps only via Settings update toast / **Update**.

## Related

- [Sources settings](torrent-settings.md) — Forja addons (torrent / Stremio / Nuvio)
- [Playback settings](playback-settings.md)
- [Navigation](navigation-bar.md) — hub tabs follow enabled hub packs
