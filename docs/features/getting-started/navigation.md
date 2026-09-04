# Navigation

> Move between movies, live TV, and catalog hubs from the main tab bar.

## What it is

Forja uses a tab-based shell. **Default tab order on every profile:** Home, Asian Drama, Anime, IPTV, Live Sports, My List, and Settings. All are enabled on a fresh install. **Home / Anime / Asian Drama / Arabic / Brstej / كرتون / Kids** labels and tab bodies come from ForjaHQ hub packs (`nav` on each catalog plugin); other tabs stay app-owned. A hub tab only appears in **Settings → Features** (and the rail) while its pack+plugin is **enabled** under **Settings → Sources → Forja**; Features then show/hide among those. On desktop and Android TV you get a fixed-width left rail (logo + grey icons, Netflix-style underline on the active tab). The pinned bottom item shows the active Forja profile avatar (or Guest) and opens Settings. On phone and tablet, a flat bottom navigation bar. You can hide, show, and reorder tabs in Settings.

## How to open it

The tab bar is always visible after the app finishes loading. The **profile avatar** is always pinned at the bottom of the desktop rail, opens Settings, and cannot be hidden from the navbar list.

## What you can do

- Tap any tab to switch sections instantly (recently used tabs stay mounted for fast switching; Android TV keeps fewer tabs in memory, and opening the fullscreen player unloads other tabs — keeping the screen under the player — so playback gets max resources). The nav rail stays mounted under root fullscreen players (movies, trailers, Live Sports, IPTV) the same way as the underlay tab. On **Android TV**, details and player opens are an instant cut (no slide) so older sets do not stutter while the new screen loads.
- On desktop, the left rail is a **fixed-width** column; the body is inset so content is not hidden under icons
- On **Home / Anime / Asian Drama / Arabic / Brstej / كرتون / Kids (desktop)**, a text top menu — **Search**, **Films**, **Series** (TV Shows on Home), **Categories** — overlays the hero and slides away as you scroll
- **Search (desktop)** uses a full-page layout with a left search column — no separate shell search bar
- Open **Settings → Features** to toggle tabs on/off, reorder (drag on desktop; **↑/↓** on Android TV), and star the tab that opens on app start and after you switch profiles (only the tabs listed below are available right now)
- Jump to Search or other tabs from deep links inside the app (e.g. from a Stremio addon result)

## Desktop shell layout

- **Home / Anime / Asian Drama / Arabic / Brstej / كرتون / Kids menu (desktop):** pack-declared chrome — **Search** (if `search`), then any `filters.menus[]` tabs, then **Categories** when `fields` has options (genre / country / Larozaa section / letter, …)
- **Left rail:** Forja logo (top), your configured tabs (center), then a larger active profile avatar / Guest with its name always visible (bottom). Next to the profile name, LAN status is a **dot** (green = up, red = unreachable). On **desktop** (the LAN server) a bold **vertical bar** after the dot is the session (amber = waiting to pair, green = paired, grey = idle, pulse = playing). Android TV is a client, so it is the dot only. Every destination is gray while idle and reveals its own accent color on hover or selection; the active underline keeps that same accent while hovered. The avatar uses its profile colors and opens Settings without a circular hover background.
- **Body:** flat `bgDark`; Home hero is full-bleed with **View details** plus a My List **+** pill

## Android TV

- **Nav rail order:** Home, Asian Drama, Anime, IPTV, Live Sports, My List, then the **profile avatar** (same Settings hub as desktop — always last and cannot be hidden)
- The app **opens on your chosen default tab** (Home unless you change it in Settings); **first focus** lands on that tab’s **nav rail** item (Home by default), not the hero **View details** button
- **Settings hub:** wide TV uses the desktop-style left category rail + right detail pane; **OK** or **→** enters the detail pane and focuses the first control (detail scroll snaps to the top so titles/section labels stay visible); D-pad moves among detail controls by on-screen position (spatial); text fields focus without opening the keyboard until **OK**; **Back** steps detail → selected category → first category → nav rail (or leaves typing first when a field is being edited)
- **Account:** cold start (desktop and Android TV) offers Sign in (code or QR via `/connect`) or Continue as guest; after link you pick a profile on Who’s watching?
- Same left **nav rail** as desktop (no bottom bar) — **same per-tab accent colors**; icon size and spacing **shrink to fit every enabled tab** on screen (no rail scroll); profile avatar is smaller and sits nearer the bottom; selected / D-pad-focused items show their accent and label **instantly** (no scale/color tween); D-pad moves focus to the nearest on-screen control (spatial 2D), with a white ring on page controls
- **D-pad (all tabs):** arrows move to the nearest focusable neighbor in that direction — not a single next/previous line across the page. Catalog shelves keep in-row ←/→ and row-to-row ↑/↓ with position memory; left from the first card still returns to the nav rail
- **Layout:** catalog rows fill the body edge-to-edge (no extra section gutters); only the fixed nav rail insets content on the left; device-reported overscan padding is applied once at the shell when present
- **Leanback density:** **115px** poster cards, 6px row gaps, tight section chrome — hero + first row peek like desktop, multiple rows visible when scrolling
- **Nav rail:** UP/DOWN only move between nav items (trap at first tab and Settings); LEFT is trapped; **RIGHT** returns to the last focused control on the **active** page (catalog row, details episode, hero, … — including shell overlay routes) without switching tabs; **Enter/Select** switches to the focused nav tab and restores that tab’s focus; **Back** travels up one shell level at a time: **player** (remote Back hides chrome, then leaves — or **OK** on the Back icon) **→ detail → tab page → nav rail** (in-tab sub-routes such as IPTV portals pop before leaving the tab); leaving **details** restores D-pad to the **last selected catalog card** (scroll stays); on tab root, **Back** focuses the **active** nav tab; **Back** twice on the nav rail (within ~2s) exits the app; remote **Exit** twice from anywhere also exits (single Back never quits from a page); remote **power** (standby) also exits. Focus chrome on the rail and catalog **snaps** (no scale/color tween) so D-pad browsing stays responsive on weak sets
- **Catalog rows:** LEFT/RIGHT move within the row only (no vertical scroll jump); DOWN/UP move between rows and restore each row’s own last-focused item (not the column from the row you left); last row DOWN stops (no escape to nav)
- **Hero:** UP from the first row scrolls the hero fully visible and focuses **View details**; LEFT from **View details** focuses the **active** nav tab (not a geometric neighbor)
- **Home / Anime / Asian Drama hero (TV):** DOWN from the top menu (Search / Films / Series or TV Shows / Categories) focuses the **hero gallery** (backdrop carousel); **←/→** change the featured title and backdrop image; UP from the gallery returns to the top menu; DOWN from the gallery focuses **View details**; UP from **View details** (and My List) focuses the gallery. On **Home**, DOWN from **View details** continues to **Featured This Month** then **Popular** (UP reverses)
- **Home, Search, Anime, Asian Drama, My List, Settings, IPTV, and Live Sports** use the **same card sizes, spacing, and section layout as desktop**; D-pad focus and coordinator-registered rows/chips are unchanged
- **Home (TV):** catalog rows and mood chips use the shared `TvFocusGraph` recipes (same D-pad rules: left from first card → nav; mood ↓ → results; ↑ from results → moods)
- **Anime / Asian Drama (TV):** same `TvFocusGraph` recipes as Home for catalog rows and continue watching; Anime vibe chips match Home mood D-pad
- **Live Sports / IPTV (TV):** same `TvFocusGraph` recipes — Live Sports sport/CDN chips and card grids; IPTV category rail, stream grid, EPG channel list, portal/M3U lists, and player top/controls via `iptvCatalogRow` (search-field chrome still syncs before focus)
- **Search (TV):** results use the `TvGrid` recipe (4 columns); trending helpers use a vertical `TvCatalogRow`; first-column Left still jumps to helpers, first-row Up to the search field
- **My List / Settings / details (TV):** My List posters use `TvGrid`; Settings category rail uses `TvCatalogRow` (detail pane is spatial inside a focus trap — Back exits left); TMDB details cast, trailers, play, and torrent action rows sit in the same focus graph
- **Live Sports embed / Who’s watching (TV):** embed Back / Play / Mute chrome registers via `TvCatalogRow`; profile chooser uses the shared overlay focus host (spatial D-pad inside the panel)
- **Anime / Asian Drama hubs:** same browse hero TV focus as Home (gallery **←/→**, then **View details**), plus the shared top menu (**Search** / Films / Series / Categories as text). Anime D-pad order is **View details → Trending → Continue Watching → Pick your vibe → catalog**; Asian Drama is **View details → Latest Update → Continue Watching → catalog**. **↑** from Continue Watching lands on the bleed row under the hero (Trending / Latest), then View details. Anime vibes use the same circular mood icons as Home (centered on TV); mood posters **↑** return to those vibes; empty Continue Watching is not in the focus graph; **→** from the nav rail restores real page focus (not a blank overlay scope). Open search from the top-bar **Search** text tab or **Find** (desktop) / platform search shortcut
- Search uses the **two-column desktop layout** on TV (last searches then trending suggestions, focused-result detail pane, fluid results grid); D-pad lands on the **search field** first — **Down** moves to suggestions
- Phone layout is unchanged — leanback density / launcher still apply only on Android TV
- **Desktop:** same D-pad / arrow-key focus graph as Android TV (focus rings, shelf ←/→, left-to-nav), plus normal mouse hover. Layout density and rail chrome stay desktop; hero Ken Burns pan/zoom stays on (static stills remain Android TV–only). Player **Sources** / **Episodes** / **Source** stay right-side panels like details on desktop and Android TV
- **Dev:** `flutter run --dart-define=FORJA_ANDROID_TV=true` forces TV profile on any Android device (layout/defaults only — not leanback launcher proof). See [Platforms](platforms.md#android-tv-development).

## Available tabs

**Default (fresh install):** Home · Asian Drama · Anime · IPTV · Live Sports · My List · Settings

Hub tabs (**Home**, **Anime**, **Asian Drama**, **Arabic** / **Brstej** / **كرتون** / **Kids** when their packs are installed) come from ForjaHQ catalog packs — layout and rows update when the pack changes. If a pack is missing, the tab shows a retry panel.

**Archived tabs** (built in code, hidden from shell and Settings → Features): Search, Discover, Similar, Magnet, Media Downloader, Audiobooks, Books, Music, Comics, Manga, Jellyfin, Anime Arabic — see [archive](../archive/README.md).

## Tips

- Hide tabs you never use to reduce clutter — among the tabs listed in Settings → Features
- Startup follows your profile: splash warms the default hub layout + first-paint rails into the shared catalog cache; torrent / Nuvio / Forja / Webstreaming engines start **after** splash when those play sources are on **and** you have a VOD tab (Home, Anime, Asian Drama, or My List). IPTV + Live Sports alone skip them. Restored-session cold start paints the logo splash immediately (update check + cloud sync run in the background). After sign-in, choosing a profile uses the avatar profile splash (same as mid-session switches).
- Movie and series details open on top of the current tab; the player opens full-screen from there
- On **desktop**, the mouse **Back** side button and **Escape** act like the in-app **Back** control — player first, then details, then in-tab screens. A two-finger trackpad swipe-right on empty page chrome (not over the Sources panel, addon chips, catalog rows, or other horizontal strips) shows a left-edge arrow; when the ring fills completely, Back commits.

## Related

- [Features settings](../settings/navigation-bar.md)
- [Home](../movies-tv/home.md)
