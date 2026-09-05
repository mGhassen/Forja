# Forja Packs

> Install and manage Forja JS plugin manifests (providers, hubs, live, torrent indexers, …).

## What it is

**Forja Packs** is where you install `manifest.json` URLs, enable packs, and refresh updates. Forja provider play is always on when your platform supports it. This is separate from **Sources → Forja addons** (Direct torrent, Stremio, Nuvio).

## How to open it

**Settings → Forja Packs**

## What you can do

- Paste a pack **manifest.json** URL and **Install**
- **Reload** next to Install — re-downloads every installed pack’s manifest and scripts
- **Update** / **Update all** when a remote pack version is newer
- Enable or disable each installed pack; expand for per-plugin toggles (Providers, Live, Hubs, Torrent, …)
- **Refresh** or **Remove** a pack (Remove also drops it from your cloud profile on the next sync)
- See badges for **Pending download** / **Install later** / **Removed from profile** when cloud membership and this device disagree — **Install** or **Uninstall now** from the row

`forja://install?manifest=…` deep links open **Forja Packs** and ask before installing.

**Community Packs** (web): browse packs by name — install URLs are not shown. Filter by pack kind (Hubs, Providers, …) and topic tags (Anime, Arabic, Kids, …). The list shows **10 packs per page** with pagination. Click a pack for a fixed-height detail panel (closes / stays hidden while multi-selecting). **Add to Forja** opens the app on this device. When signed in, the cloud icon adds the pack to your profile; trash removes it. Other signed-in devices ask mid-session before download or uninstall. Boot / splash still hydrates and purges missing packs silently.

**Batch add** from the web catalog (`Shift+click` multiple packs → **Add N to Forja**) opens the running app with a checkable install dialog. Packs download only after you confirm. Play / Sources / catalog never start downloads; version bumps only via Settings update toast / **Update**.

## Related

- [Cloud sync](cloud-sync.md) — profile pack membership
- [Sources settings](torrent-settings.md) — Forja addons (torrent / Stremio / Nuvio)
- [Playback settings](playback-settings.md)
- [Navigation](navigation-bar.md) — hub tabs follow enabled hub packs
