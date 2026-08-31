# Home

> Your main dashboard — trending picks, continue watching, and personalized rails.

## What it is

Home is the default tab when you first install Forja. **Browse rails** come from the ForjaHQ **Hubs** pack plugin `tmdb` (`kind: catalog`) — layout and rows are pack-defined. The shell renders the shared **cinematic hero** and host **Continue Watching**. Metadata is TMDB for your device's country (falling back to the United States when no country is available). Toggle the tab under **Settings → Features**.

## How to open it

Tap **Home** in the navigation bar (first tab by default).

## What you can do

- Browse the Hubs pack layout (same order as before Catalog Shell): cinematic **Spotlight** hero with **Featured This Month** bleed, **Popular** (numbered), **Continue Watching**, **What's your mood?** circles + results, **Because you watched**, Trakt rows when signed in, **New Releases**, and rotating genre rows. **Featured** and **New Releases** reshuffle from random TMDB pages each hour (Popular stays ranked).
- **Films / TV Shows / Categories** (desktop / TV / phone hero menu) refetch every Home rail — **hero included** — via Catalog Shell filters into the pack (`type` / `genre`). With no tab selected, rows mix films and series; pick **Films** or **TV Shows** to limit type; **Categories** narrows by TMDB genre (or **All** to clear). The menu overlays the hero and slides away as you scroll past it.
- **Watch services** — on **desktop**, hover **Home** in the nav for ~1s to open a floating streaming-service panel beside the rail; leave the panel / Home for ~1s to hide it. On **Android TV**, hold **OK** on Home for ~500ms (or long-press on phone). The selected service appears as a mark before **Films**. *(Provider filtering of Catalog Shell rails is not wired yet — logo chrome only.)*
- Open a poster or hero **View details** for the normal movie/TV details page (Sources / play). Glass **+** on the hero opens Plan to Watch / Watching / … (Simkl when connected).
- Search from the Home top-bar **Search** tab — on **desktop**, **Cmd+F** / **Ctrl+F** opens the same search overlay.
- Resume from **Continue watching** (host watch history).

## Setup (if needed)

- **Simkl** (optional): Settings → Connected services → Simkl — watchlist / history sync
- **Stremio addons** (optional): Settings → Sources — stream addons appear under Sources → Stremio on details

## Tips

- Hub rails come from the ForjaHQ **Hubs** pack — layout can change without an app update when the pack bumps. Cold start warms layout + first-paint rails into the shared catalog cache so Home opens without a cold network round-trip.
- Continue Watching is host-owned (your watch history), not pack data.
- On **desktop**, drag-select the hero title text to copy it (logo titles are images).
- On **Android TV**, first open focuses the **Home** nav rail item; **RIGHT** or **Enter** moves into the page. From the top **Search** tab, **↓** lands on the hero gallery; **←/→** swaps slides; **OK** opens details; **↓** continues into **View details** then catalog rails.

## Related

- [Watch history](watch-history.md)
- [Hub details](../hubs/hub-details.md)
