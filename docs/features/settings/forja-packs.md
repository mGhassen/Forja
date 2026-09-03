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

When **two or more** profile packs still need downloading on this device (for example after **Batch add to Forja** on the web portal), Forja shows a **batch install** dialog — pick which packs to pull now. **Install plugins** on the get-started screen opens the same picker.

## Related

- [Sources settings](torrent-settings.md) — Forja addons (torrent / Stremio / Nuvio)
- [Playback settings](playback-settings.md)
- [Navigation](navigation-bar.md) — hub tabs follow enabled hub packs
