# Home

> Your main dashboard — trending picks, continue watching, and personalized rails.

## What it is

Home is the default tab when you first install Forja. It pulls metadata from TMDB for your device's country (falling back to the United States when no country is available) and shows a hero carousel, mood circles (icon + label), and scrollable rows: trending, popular, top rated, now playing, and more. On **desktop and TV**, the hero backdrop fills most of the viewport so **Featured This Month** can sit on the image with its title above the posters; the hero still shows title, metadata, synopsis, and Play/Info actions above that row. While a featured title stays on screen, its backdrop **rotates through random TMDB stills** for that title — with a slow **Ken Burns** pan/zoom on desktop/mobile. On **Android TV**, the stills stay static (hard-cut between images) so weak sets do not stutter. If you're logged into Trakt, you also get recommendations and TV/movie calendars. You can change the startup tab by selecting its star in **Settings → Features**.

## How to open it

Tap **Home** in the navigation bar (first tab by default).

## What you can do

- Browse featured and trending movies and series
- **Films / TV Shows / Categories** (desktop / TV / phone hero menu) filter every Home rail — hero, featured, popular, mood row, new releases, and the three genre rows at the bottom. With no tab selected, rows mix films and series; pick **Films** or **TV Shows** to limit all rails to that type. **Categories** narrows by TMDB genre (or **All** to clear). The menu overlays the hero and slides away as you scroll past it.
- **Watch services** — on **desktop**, hover **Home** in the nav for ~500ms to open a floating streaming-service panel beside the rail (rectangle tiles); leave the panel / Home for ~1s to hide it. On **Android TV**, hold **OK** on Home for ~500ms (or long-press on phone). The selected service appears as a **rectangle** mark before **Films**; tap it to open the panel, tap again to clear the filter. Tap a service in the panel to filter Home; tap the same service again to clear. Click/tap outside the panel (or leave Home) hides it. On TV, ←/→ dismiss the panel; ↑/↓ stay inside it.
- See **Featured This Month** — popular titles released in the current month
- Pick a mood circle under **What's your mood?** to filter the mood results row
- See **Tonight's Pick** and **Because you watched…** (BestSimilar) suggestions — the seed title re-rolls on every Home pull-to-refresh (and when you use the shuffle control), picking a different in-progress Continue Watching title when more than one is available
- Resume from **Continue watching** (local watch history)
- Tap **Play** on the hero to auto-start **webstreaming** (best extractor) on the details screen — not torrent search
- **Info | +** pill opens details or toggles My List
- Swipe or drag on the hero (or tap the step indicators on the right) to cycle featured titles — the full hero slide moves together: backdrop, title, metadata, overview, and actions
- On **desktop**, **Cmd+F** (macOS) or **Ctrl+F** (Windows/Linux) opens the films search overlay (same as the search icon in the hero menu). On macOS this also enables **Edit → Find…**.
- On **Android TV**, first open focuses the **Home** nav rail item; **RIGHT** or **Enter** moves into the page (hero Play). D-pad **←/→** on the hero gallery swaps the entire hero slide; **OK** on the gallery opens details for the current title. From a catalog row under the hero, **↑** focuses hero **Play** (not the gallery). **←** to the nav rail and **→** restores the same row/card you left.
- Open any poster to view details and play
- View Trakt recommendation and calendar sections when connected

## Setup (if needed)

- **Trakt** (optional): Settings → Accounts → Trakt — unlocks recommendations and calendars on Home
- **Stremio addons** (optional): Settings → Sources — stream addons like Torrentio appear under Sources → Stremio on details; Search can still surface catalog sections when configured

## Tips

- On **desktop**, drag-select the hero title text to copy it (logo titles are images)
- Continue watching updates automatically when you watch movies or series
- Hover a continue watching card (desktop) to scale it and show a play button; hover the play button to turn it brand-green, float it upward, and pulse the icon — click to resume from the last torrent or web source
- Dismiss an item from continue watching from the details screen or Home

## Related

- [Discover](discover.md)
- [Watch history](watch-history.md)
- [Trakt](../accounts/trakt.md)
- [Stremio addons](../sources/stremio-addons.md)
