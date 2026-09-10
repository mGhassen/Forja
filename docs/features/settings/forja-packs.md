# Forja Packs

> Install and manage Forja JS plugin manifests (providers, hubs, live, torrent indexers, …).

## What it is

**Forja Packs** is where you install `manifest.json` URLs, enable packs, and refresh updates. Forja provider play is always on when your platform supports it. This is separate from **Sources → Forja addons** (Direct torrent, Stremio, Nuvio).

## How to open it

**Settings → Forja Packs**

When every feature tab is off, the get-started screen **Install plugins** button opens this category (and the batch download picker if profile packs still need installing).

## What you can do

- Paste a pack **manifest.json** URL and **Install** (downloads the files listed in the pack’s `bundle`, or each plugin entry if `bundle` is omitted). Live packs may include unlock modules (`.wasm` + crack scripts) alongside JS entries.
- **Official packs** — opens a checkable list from the **published catalog** only (admin Plugins → published packs). If nothing is published, the list is empty. Missing packs appear in the Settings detail pane (right side on desktop/TV). The **recommended product bundle** (e.g. Best experience, published in admin) drives which packs are pre-selected on onboarding and when you tap Official in Settings. Core packs show a flame **Recommended** badge; those rows sort first. Rows start unchecked in Settings — pick packs or use **Select all**. Each row also shows tags and a short description (not the manifest URL). The list scrolls in place with **Install** / **Not now** pinned at the bottom (same layout as Update Forja). Download only after you confirm (same picker as batch profile / Community Packs). Installing a **hub** pack turns its tab on in **Features** / the navbar right away (same as enabling the pack).
- **Download** (icon on the right) on pending pack rows — or **Download all** when several packs still need scripts. Pending rows also have **Remove** (trash → Yes / No) so a bad or unreachable stub can be deleted without installing
- **Reload** only when at least one pack is fully installed — re-downloads every installed pack’s manifest and scripts
- **Update** / **Update all** when a remote pack version is newer
- Enable or disable each installed pack with **OK / click on the row** (switch chrome on the row); the **chevron** expands for per-plugin toggles (Providers, Live, Hubs, Torrent, …). Desktop ExpansionTile still expands on header tap with the switch in the trailing actions.
- When a pack’s manifest URL is gone (HTTP 404/410), the pack name turns red with a **deprecated** tag — scripts on disk still work until you remove the pack
- **Refresh** or **Remove** from the same right-side actions (Remove also drops hub tabs from **Features** / the navbar, and drops the pack from your cloud profile on the next sync)
- When signed in, cloud sync remaps official pack install URLs if the published catalog moved them (same pack slot, new host) — Settings shows the new URL and re-downloads scripts. A local packs checkout on this machine is kept as-is.
- See badges for **Pending download** when a pack is still hydrating, or **Removed from profile** when cloud dropped it — **Download** / **Uninstall now** from the row when needed. If a pending row still shows a local file path from another device, **Download** fetches the official pack instead; use trash to drop it

`forja://install?manifest=…` deep links open **Forja Packs** and ask before installing.

**Community Packs** (web): **product bundles** appear first as a marketing section (admin-published `plugin_bundles`) — recommended set featured, other sets as cards, **Get this set** opens the same batch add flow. Below that, browse **individual packs** by name — install URLs are not shown. The pack list is **only packs published in admin** (`plugin_packs`). Filter by pack kind (Hubs, Providers, …) and topic tags (Anime, Arabic, Kids, …). Recommended ForjaHQ packs float to the top with a flame **Recommended** badge. The list shows **10 packs per page** with pagination. On desktop, click a pack for a fixed-height detail panel (closes / stays hidden while multi-selecting). On Android TV / leanback browsers there is **no** detail panel — rows show the description inline and OK / click toggles selection; use **Add N to Forja** from the selection bar. **Add to Forja** opens the app on this device. When signed in, the cloud or trash icon opens a **profile picker** — check which profiles get the pack (membership only) or uncheck to remove it. Signed-in apps **download membership packs automatically** after sync (toast with **View** opens this screen — on **Android TV**, focus lands on **View**; D-pad or Back dismisses the toast and returns focus to where you were). Pack **updates** still ask before downloading. Manual Install / `forja://install` still confirm first.

**Batch add** from the web catalog (`Shift+click` multiple packs → **Add N to Forja**) opens **Settings → Forja Packs** with a checkable install list in the detail pane. Packs download only after you confirm. Play / Sources / catalog never start downloads; version bumps only via Settings update toast / **Update**. When an update is available after splash, a toast stays until you tap **Update** or close it (once per session). On **Android TV**, focus lands on **Update**; D-pad away or Back dismisses the toast and returns focus to where you were. Cancel / Update on the confirm dialog returns focus to the control you were on, or the first navbar tab.

**Onboarding (desktop / Android TV):** after sign-in and profile select (or on upgrade when the profile is not yet onboarded), Forja offers **Official packs**, **Community Packs**, or **Skip for now**. Official opens a checkbox list of packs from the **recommended product bundle** with **Recommended** already checked and focus on **Install** (you can still Select all / Clear / tweak). The list scrolls with **Install** / **Back** pinned at the bottom. Completing or skipping sets `onboarded` on the profile so the step does not repeat. **Continue as guest** gets the same step once per device (local flag only). The same Official / Community quick-action cards also appear (smaller) under **Settings → Forja Packs** — Official there uses the checkbox list in the detail pane (rows start unchecked).

**Android TV:** Community Packs shows `https://www.forjahq.xyz/plugins` on the card so you can open the catalog on your phone; **OK** copies the URL. **OK** on an installed pack row toggles enable; the chevron expands plugins. Refresh / remove stay on the right (pending download rows: full-width row focus, then → for Download + trash). D-pad is spatial on this page: **→** from Official reaches Community; **←** anywhere in the page returns to the Settings category list (same as Back); **↓** through Add pack → Reload / Install → Update all → pack rows (including the last pack — focused rows stay above the bottom overscan band), then expanded category chips and per-plugin toggles, and the official install checklist (Select all / Clear / rows / Install / Not now). On the **Install packs** checklist, **↑** / **↓** walk pack rows; only the first pack’s **↑** reaches Select all / Clear.

## Related

- [Cloud sync](cloud-sync.md) — profile pack membership + onboarded (web/cloud adds packs; app downloads/installs)
- [Link Android TV](../accounts/tv-connect.md) — cold-start packs step
- [Sources settings](torrent-settings.md) — Forja addons (torrent / Stremio / Nuvio)
- [Playback settings](playback-settings.md)
- [Navigation](navigation-bar.md) — hub tabs follow enabled hub packs
