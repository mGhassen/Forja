# Forja Packs

> Install and manage Forja JS plugin manifests (providers, hubs, live, torrent indexers, …).

## What it is

**Forja Packs** is where you install `manifest.json` URLs, enable packs, and refresh updates. Forja provider play is always on when your platform supports it. This is separate from **Sources → Forja addons** (Direct torrent, Stremio, Nuvio).

## How to open it

**Settings → Forja Packs**

When every feature tab is off, the get-started screen **Install plugins** button opens this category (and the batch download picker if profile packs still need installing).

## What you can do

- Paste a pack **manifest.json** URL and **Install** (downloads the files listed in the pack’s `bundle`, or each plugin entry if `bundle` is omitted)
- **Official packs** — opens a checkable list of missing ForjaHQ packs in the Settings detail pane (right side on desktop/TV); download only after you confirm (same picker as batch profile / Community Packs). Onboarding’s **Install official** still installs the full bundle in one go.
- **Download** (icon on the right) on pending pack rows — or **Download all** when several packs still need scripts
- **Reload** only when at least one pack is fully installed — re-downloads every installed pack’s manifest and scripts
- **Update** / **Update all** when a remote pack version is newer
- Enable or disable each installed pack from the **right-side** switch; expand for per-plugin toggles (Providers, Live, Hubs, Torrent, …)
- **Refresh** or **Remove** from the same right-side actions (Remove also drops it from your cloud profile on the next sync)
- See badges for **Pending download** / **Install later** / **Removed from profile** when cloud membership and this device disagree — **Download** or **Uninstall now** from the row’s right-side action

`forja://install?manifest=…` deep links open **Forja Packs** and ask before installing.

**Community Packs** (web): browse packs by name — install URLs are not shown. Filter by pack kind (Hubs, Providers, …) and topic tags (Anime, Arabic, Kids, …). The list shows **10 packs per page** with pagination. Click a pack for a fixed-height detail panel (closes / stays hidden while multi-selecting). **Add to Forja** opens the app on this device. When signed in, the cloud icon adds the pack to your profile; trash removes it. Other signed-in devices show one batch confirm mid-session (after splash and a profile is active) in **Settings → Forja Packs** before download or uninstall — never pack-by-pack, and never over Who's watching or boot splash. Closing the picker (**Not now** / Back) leaves those packs in **Settings → Forja Packs** as **Install later** or **Removed from profile** until you Install / Uninstall now. Boot / splash still hydrates and purges missing packs silently.

**Batch add** from the web catalog (`Shift+click` multiple packs → **Add N to Forja**) opens **Settings → Forja Packs** with a checkable install list in the detail pane. Packs download only after you confirm. Play / Sources / catalog never start downloads; version bumps only via Settings update toast / **Update**.

**Onboarding (desktop / Android TV):** after sign-in and profile select (or on upgrade when the profile is not yet onboarded), Forja offers **Install official ForjaHQ packs**, a Community Packs link, or **Skip for now**. Completing or skipping sets `onboarded` on the profile so the step does not repeat. **Continue as guest** gets the same step once per device (local flag only). The same Official / Community quick-action cards also appear (smaller) under **Settings → Forja Packs** — Official there uses the checkbox list in the detail pane, not a silent full-bundle install.

**Android TV:** Each installed pack keeps enable / refresh / remove on the **right** of the row (always visible). D-pad walks Official/Community cards, the URL field (OK to type), Install / Download all / Reload, pack rows (↓) and those actions (→), expanded category chips and per-plugin toggles, and the official install checklist (Select all / Clear / rows / Install / Not now).

## Related

- [Cloud sync](cloud-sync.md) — profile pack membership + onboarded
- [Link Android TV](../accounts/tv-connect.md) — cold-start packs step
- [Sources settings](torrent-settings.md) — Forja addons (torrent / Stremio / Nuvio)
- [Playback settings](playback-settings.md)
- [Navigation](navigation-bar.md) — hub tabs follow enabled hub packs
