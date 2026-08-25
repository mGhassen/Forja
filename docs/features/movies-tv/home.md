# Home

> Your main dashboard — trending picks, continue watching, and personalized rails.

## What it is

Home is the default tab when you first install Forja. It pulls metadata from TMDB for your device's country (falling back to the United States when no country is available) and shows a hero carousel, mood circles (icon + label), and scrollable rows: trending, popular, top rated, now playing, and more. On **desktop and TV**, the hero backdrop fills most of the viewport so **Featured This Month** can sit on the image with its title above the posters; the hero still shows title, metadata, synopsis, and View details / My List actions above that row. While a featured title stays on screen, its backdrop **rotates through random TMDB stills** for that title — with a slow **Ken Burns** pan/zoom on desktop/mobile. On **Android TV**, the stills stay static (hard-cut between images) so weak sets do not stutter. If you're logged into Trakt, you also get recommendations and TV/movie calendars. You can change the startup tab by selecting its star in **Settings → Features**.

## How to open it

Tap **Home** in the navigation bar (first tab by default).

## What you can do

- Browse featured and trending movies and series. Each discovery rail starts with one TMDB page (~20 posters); scrolling toward the end of a row loads a second page into that row only. The **hero** stays today’s trending order and **Popular** stays today’s ranked Popular list (TMDB order — not shuffled or stripped by dedupe); other discovery rails still avoid repeating those titles. With no **Categories** genre selected, each title appears in **at most one** other discovery rail (hero → Featured → mood → Because → Trakt recs → New Releases → genre rows). When a title is already shown higher up, the lower row **refills** from its TMDB pool so the row stays full. With a **Categories** genre selected, every rail fills its own slots from that genre (no cross-row hide) so rows stay full. Continue Watching and Trakt upcoming calendars can still show titles you are mid-watch or waiting for. (Hourly catalog remount / pull-to-refresh are temporarily off.)
- **Films / TV Shows / Categories** (desktop / TV / phone hero menu) filter every Home rail — **hero included**. The shell stays mounted; posters/hero swap when the matching fetch lands (no full-page reload). With no tab selected, rows mix films and series; pick **Films** or **TV Shows** to limit all rails to that type. **Categories** narrows by TMDB genre (or **All** to clear). The menu overlays the hero and slides away as you scroll past it.
- **Watch services** — on **desktop**, hover **Home** in the nav for ~1s to open a floating streaming-service panel beside the rail (rectangle tiles); leave the panel / Home for ~1s to hide it. On **Android TV**, hold **OK** on Home for ~500ms (or long-press on phone). The selected service appears as a **rectangle** mark before **Films**; tap it to open the panel, tap again to clear the filter. Tap a service in the panel to filter Home; tap the same service again to clear. Click/tap outside the panel (or leave Home) hides it. On TV, ←/→ dismiss the panel; ↑/↓ stay inside it. Each chip is the **service as you’d expect it**: Max includes HBO and HBO Max (new HBO series show up even before TMDB’s availability list catches up); Disney+ includes Hotstar / Star+; Prime includes both regional Prime ids; Paramount+ includes the older Paramount Plus id and with-Showtime. Amazon/Apple “channel” add-ons are not mixed in.
- See **Featured This Month** — popular titles released in the current month. With a watch service selected, new-this-month titles on that service come first (including brand-new series with no rating yet); if that list is thin, the row fills with popular titles on the service.
- Pick a mood circle under **What's your mood?** to filter the mood results row
- See **Tonight's Pick** and **Because you watched…** (BestSimilar) suggestions — the seed title re-rolls on every Home pull-to-refresh (and when you use the shuffle control), picking a different in-progress Continue Watching title when more than one is available
- Resume from **Continue watching** (local watch history)
- **View details** on the hero opens the title page; glass **+** opens the floating Plan to Watch / Watching / On Hold / Completed / Dropped menu (same as posters / details). On **Android TV**, **OK** on the pin focuses that menu; **↑↓** stay inside it; **OK** or **Back** closes it
- Poster **+** / bookmark (top-left on Home, Anime, and Asian Drama cards) opens Plan to Watch / Watching / On Hold / Completed / Dropped — floating menu; each status has its own pin color; hover a row for background + status highlight. Click the active status again to take it off My List. On **Android TV** the pin is hidden on cards (D-pad uses the poster tile; set status from details / hero).
- Swipe or drag on the hero (or tap the step indicators on the right) to cycle featured titles — the full hero slide moves together: backdrop, title, metadata, overview, and actions
- On **desktop**, **Cmd+F** (macOS) or **Ctrl+F** (Windows/Linux) opens the films search overlay (same as the search icon in the hero menu). On macOS this also enables **Edit → Find…**.
- On **Android TV**, first open focuses the **Home** nav rail item; **RIGHT** or **Enter** moves into the page (hero **View details**). From the top **Search** tab, **↓** lands on the hero gallery (not **View details**); D-pad **←/→** on the gallery swaps the entire hero slide; **OK** opens details for the current title; **↓** from the gallery → **View details** → **Featured This Month** → **Popular** (and the rest of the catalog). After **What's your mood?** posters, **↓** lands on the **Because you watched** shuffle control (when more than one in-progress title is available), then **↓** into that row’s posters. **↑** reverses that path: Popular → Featured → View details → gallery → top menu. **←** to the nav rail and **→** restores the same row/card you left.
- Open any poster to view details and play
- View Trakt recommendation and calendar sections when connected

## Setup (if needed)

- **Trakt** (optional, admin): Settings → Connected services → Trakt — unlocks recommendations and calendars on Home
- **Simkl** (optional): Settings → Connected services → Simkl — watchlist / history sync
- **Stremio addons** (optional): Settings → Sources — stream addons like Torrentio appear under Sources → Stremio on details; Search can still surface catalog sections when configured

## Tips

- On **desktop**, drag-select the hero title text to copy it (logo titles are images). Long text titles shrink and wrap up to **3 lines** so they don’t clip into the meta row.
- Continue watching updates automatically when you watch movies or series
- Hover a continue watching card (desktop) to scale it and show a play button; hover the play button to turn it brand-green, float it upward, and pulse the icon — click to resume from the last torrent or web source
- Dismiss an item from continue watching from the details screen or Home

## Related

- [Discover](discover.md)
- [Watch history](watch-history.md)
- [Trakt](../accounts/trakt.md)
- [Stremio addons](../sources/stremio-addons.md)
