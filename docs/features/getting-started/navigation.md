# Navigation

> Move between movies, live TV, music, reading, and more from the main tab bar.

## What it is

Forja uses a tab-based shell. **Default tab order on every profile:** Search, Home, Asian Drama, Anime, IPTV, Live Matches, My List, and Settings. All are enabled on a fresh install. On desktop and Android TV you get a fixed-width left rail (logo + grey icons, Netflix-style underline on the active tab). The pinned bottom item shows the active Forja profile avatar (or Guest) and opens Settings. On phone and tablet, a flat bottom navigation bar. You can hide, show, and reorder tabs in Settings.

## How to open it

The tab bar is always visible after the app finishes loading. The **profile avatar** is always pinned at the bottom of the desktop rail, opens Settings, and cannot be hidden from the navbar list.

## What you can do

- Tap any tab to switch sections instantly (recently used tabs stay mounted for fast switching; Android TV keeps fewer tabs in memory, and opening the fullscreen player unloads other tabs — keeping the screen under the player — so playback gets max resources). On **Android TV**, details and player opens are an instant cut (no slide) so older sets do not stutter while the new screen loads.
- On desktop, the left rail is a **fixed-width** column; the body is inset so content is not hidden under icons
- On **Home (desktop)**, a **Search** icon then **Films / TV Shows / Categories** menu overlays the hero and slides away as you scroll
- **Search (desktop)** uses a full-page layout with a left search column — no separate shell search bar
- Open **Settings → Features** to toggle tabs on/off, reorder (drag on desktop; **↑/↓** on Android TV), and star the tab that opens on app start and after you switch profiles (only the tabs listed below are available right now)
- Jump to Search or other tabs from deep links inside the app (e.g. from a Stremio addon result)

## Desktop shell layout

- **Home menu (desktop):** Search, then Films / TV Shows / Categories overlaid on the hero; Categories opens a mood picker
- **Left rail:** Forja logo (top), your configured tabs (center), then a larger active profile avatar / Guest with its name always visible (bottom). Every destination is gray while idle and reveals its own accent color on hover or selection; the active underline keeps that same accent while hovered. The avatar uses its profile colors and opens Settings without a circular hover background.
- **Body:** flat `bgDark`; Home hero is full-bleed with pill **Play** plus a combined **info | add** pill for details and My List

## Android TV

- **Nav rail order:** Search, Home, Asian Drama, Anime, IPTV, Live Matches, My List, then the **profile avatar** (same Settings hub as desktop — always last and cannot be hidden)
- The app **opens on your chosen default tab** (Home unless you change it in Settings); **first focus** lands on that tab’s **nav rail** item (Home by default), not the hero Play button
- **Settings hub:** wide TV uses the desktop-style left category rail + right detail pane; **OK** or **→** enters the detail pane and focuses the first control; D-pad stays in the right pane; **Back** steps detail → selected category → first category → nav rail
- **Account:** cold start offers Sign in (code or QR via `/connect`) or Continue as guest; after link you pick a profile on Who’s watching?
- Same left **nav rail** as desktop (no bottom bar) — **same per-tab accent colors**; icon size and spacing **shrink to fit every enabled tab** on screen (no rail scroll); profile avatar is smaller and sits nearer the bottom; selected / D-pad-focused items show their accent and label; D-pad moves focus with a white ring on page controls
- **Layout:** catalog rows fill the body edge-to-edge (no extra section gutters); only the fixed nav rail insets content on the left; device-reported overscan padding is applied once at the shell when present
- **Leanback density:** **115px** poster cards, 6px row gaps, tight section chrome — hero + first row peek like desktop, multiple rows visible when scrolling
- **Nav rail:** UP/DOWN only move between nav items (trap at Search and Settings); LEFT is trapped; **RIGHT** returns to the **active** tab’s last focus (row, hero, or default) without switching tabs; **Enter/Select** switches to the focused nav tab and restores that tab’s focus; **Back** travels up one shell level at a time: **player → detail → tab page → nav rail** (in-tab sub-routes such as IPTV portals pop before leaving the tab); on tab root, **Back** focuses the **active** nav tab; **Back** twice on the nav rail (within ~2s) exits the app; remote **Exit** twice from anywhere also exits (single Back never quits from a page)
- **Catalog rows:** LEFT/RIGHT move within the row only (no vertical scroll jump); DOWN/UP move between rows and restore each row’s own last-focused item (not the column from the row you left); last row DOWN stops (no escape to nav)
- **Hero:** UP from the first row scrolls the hero fully visible and focuses Play; LEFT from Play focuses the **active** nav tab (not a geometric neighbor)
- **Home hero (TV):** DOWN from the top menu (Search / Films / TV Shows / Categories) focuses the **hero gallery** (backdrop carousel); **←/→** change the featured title and backdrop image; UP from the gallery returns to the top menu; DOWN from the gallery focuses **Play**; UP from **Play** (and the info / My List pills) focuses the gallery
- **Home, Search, Anime, Asian Drama, My List, Settings, IPTV, and Live Matches** use the **same card sizes, spacing, and section layout as desktop**; D-pad focus and coordinator-registered rows/chips are unchanged
- **Home (TV):** catalog rows, mood chips, and Stremio **Show All** use the shared `TvFocusGraph` recipes (same D-pad rules: left from first card → nav; mood ↓ → results; ↑ from results → moods)
- **Anime / Asian Drama (TV):** same `TvFocusGraph` recipes as Home for catalog rows and continue watching; Anime vibe chips match Home mood D-pad
- **Live Matches / IPTV (TV):** same `TvFocusGraph` recipes — Live Matches sport/CDN chips and card grids; IPTV category rail, stream grid, EPG channel list, portal/M3U lists, and player top/controls via `iptvCatalogRow` (search-field chrome still syncs before focus)
- **Search (TV):** results use the `TvGrid` recipe (4 columns); trending helpers use a vertical `TvCatalogRow`; first-column Left still jumps to helpers, first-row Up to the search field
- **My List / Settings / hub search / details (TV):** My List posters use `TvGrid`; Settings category rail uses `TvCatalogRow` (detail pane stays linear); Anime/Asian Drama hub search matches Search grid recipes; media details cast, trailers, play, and torrent action rows sit in the same focus graph
- **Live Matches embed / Who’s watching (TV):** embed Back / Play / Mute chrome registers via `TvCatalogRow`; profile chooser uses the shared overlay focus host
- **Anime / Asian Drama hubs:** Anime D-pad order is **Play → Trending → Continue Watching → Pick your vibe → catalog**; Asian Drama is **Play → Latest Update → Continue Watching → catalog**. **↑** from Continue Watching lands on the bleed row under the hero (Trending / Latest), then Play. Anime vibes use the same circular mood icons as Home (centered on TV); mood posters **↑** return to those vibes; empty Continue Watching is not in the focus graph; **→** from the nav rail restores real page focus (not a blank overlay scope)
- Search uses the **two-column desktop layout** on TV (trending suggestions, focused-result detail pane, fluid results grid); D-pad lands on the **search field** first — **Down** moves to suggestions
- Phone layout is unchanged — TV behavior applies only on Android TV / leanback devices
- **Dev:** `flutter run --dart-define=FORJA_ANDROID_TV=true` forces TV profile on any Android device (layout/defaults only — not leanback launcher proof). See [Platforms](platforms.md#android-tv-development).

## Available tabs

Home · Search · My List · Live Matches · IPTV · Anime · Asian Drama · Settings

Discover, Similar, Media Downloader, Magnet, Audiobooks, Books, Music, Comics, Manga, Jellyfin, Anime Arabic, and Arabic are built but temporarily hidden from the shell and Navigation settings.

## Tips

- Hide tabs you never use to reduce clutter — they can be re-enabled anytime (among the available tabs)
- Startup follows your profile: Home / Search / My List pull movie catalogs; torrent / Stremio / Webstreaming engines only start when those play sources are on **and** you have a VOD tab (Home, Search, Anime, Asian Drama, or My List). IPTV + Live Matches alone skip them at splash. After sign-in, choosing a profile uses the avatar profile splash (same as mid-session switches); guest / restored-session cold start uses the logo boot splash
- Movie and series details open on top of the current tab; the player opens full-screen from there
- On **desktop**, the mouse **Back** side button, **Escape**, and a strong two-finger horizontal trackpad swipe (while details or the player is open) all act like the in-app **Back** control — player first, then details, then in-tab screens

## Related

- [Features settings](../settings/navigation-bar.md)
- [Home](../movies-tv/home.md)
