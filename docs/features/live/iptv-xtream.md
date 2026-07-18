# IPTV — Xtream

> Connect Xtream Codes portals — live TV, VOD, series, and EPG.

## What it is

The IPTV tab supports **Xtream Codes** portals. The tab opens on the **catalog** (categories + channels). Pick a portal from the side panel, switch **Live / Movies / Series** from the top bar, and play in the IPTV player.

## How to open it

Tap **IPTV** in the navigation bar. If you used a portal before, its catalog loads automatically; otherwise choose a portal from the **Portals** panel.

## What you can do

- Open the **Portals** panel from the top-bar portal control (status dot + portal name; hover/focus expands left to show connection seats `used/max`) — after a portal is active — to add, scrape, search, favorite, or switch providers; until then use **Open portal** in the empty state
- Switch **Live**, **Movies**, and **Series** from section chips in the top bar once a portal is active — the full top bar (shelf, search, portals) is hidden until you pick a provider
- Catalog is **cached in-session** per portal/section — switching chips reuses the last fetch
- Hover (or focus) the **selected** section chip (**Live** / **Movies** / **Series**) to reveal **Reload** and force a fresh catalog fetch for that shelf
- Browse live channels by category — channel tiles and compact list rows show logos fitted inside the card (not cropped to fill), plus a play control that floats upward with a slowly pulsing play icon, and a slightly brighter border, on hover (desktop) or focus (TV)
- **Search** live, movie, and series catalogs (search icon → slide-in bar on wide layouts, dialog on compact layouts; filters groups and channels as you type; close clears search) — on **desktop**, **Cmd+F** / **Ctrl+F** opens the search bar and focuses the field (same as the search icon; macOS **Edit → Find…** too)
- Watch VOD movies and series with seasons/episodes
- View EPG (program guide) when the portal provides it — disable in **Settings → Playback → IPTV programme guide (EPG)** to skip loading guide data
- Favorite portals in the Portals panel (star icon) — pinned to the top with **gold** title text matching the star; below them, the most recently scraped or added portals appear first (with a **NEW** badge on session-fresh rows until you hover or focus them — styling only, position stays put)
- Portal rows and the top-bar portal control show your **Portal name** when you set one (add / edit / share-code import); otherwise they fall back to the account name from the provider
- Portal rows show the subscription **end date** on the first line (green · yellow · amber · red by time left) and **connection seats** (`used/max`) under the server URL (blue when free capacity, gray when full); the status dot is gray until hover/focus probes the portal (green/red), then returns to gray after about two minutes if you do not check again; hover/focus reveals row actions (**copy share code / edit / delete**) without moving the status icon or star off-center
- **Copy share code** transforms the row into the 8-character code (copied automatically); click the row again to restore portal details. Normal row click still selects the portal when the code is not shown
- Play in the IPTV player screen — on **Android TV** playback uses the native ExoPlayer engine (reliable video surface); other platforms use MediaKit (libmpv). With controls visible, D-pad **←/→** moves between chrome buttons (back, play, mute, guide, fullscreen, …); **↑** from the transport row returns to **back**; **↓** from **back** returns to **play**; **OK** activates the focused control. When controls are hidden, **←/→** seek (VOD) and **↑/↓** adjust volume. On desktop, hover the volume icon to expand the volume bar (tap mutes; long-press pins the bar)
- Use **Player**, **stream stats**, and **Picture-in-picture** from the IPTV player top-right (same flat controls as the movie player) on Android and desktop — **Player** opens built-in / external app options; **stream stats** (MediaKit) shows codec/bitrate/buffer; PiP hides chrome while active; on desktop, hover the PiP window and tap the PiP icon to restore
- Change live channels from the in-player channel guide (groups + channel list overlay; roomier columns, taller rows, logos fitted without cropping) — on **Android TV**, **↑/↓** move the highlight, **←/→** switch between groups and channels (wide layout) or open the channel list (narrow); **Right** on the channel list stays in the panel (does not return to the video); **OK** / **Select** picks the focused group or tunes the focused channel; **Back** returns to groups (narrow) or closes the guide
- Search channels from the in-player search overlay (matches name or category) — dismiss with the borderless **Close** control in the header
- View programme guide (NOW / NEXT with progress) as a floating card at the bottom-right of the player when your portal provides EPG — tap **Read More** on the current programme description to expand it inline
- See the current channel logo at the bottom-left of the player; for VOD it sits immediately before the progress bar, with playback time on the bar's right
- Double-click the video (desktop) to enter/exit fullscreen — same as the fullscreen button

## Setup

1. Get portal URL, username, and password from your IPTV provider
2. Open **Portals** → **Add** (or **Scrape** / **Find Portals** when your Forja account has the IPTV scrape feature enabled) to discover providers from Reddit IPTV posts
3. To import from a share code: in the portal dialog (**Share code** title), paste or type the 8-character code into the tall **XXXX-XXXX** squares centered in the dialog — when the code resolves, the dialog asks for an optional **Portal name**, then connects after you confirm (or cancel to go back). Tap the **↓** control on the bottom edge to expand manual entry (title becomes **Add Portal**; optional **Portal name**, then URL, username, password as underline fields) — confirm with the green check icon or dismiss with the muted close icon at the bottom-right (only when expanded); use the header **X** to close without saving. **Edit portal** includes the same **Portal name** field. On the **web** remote settings page, add portals with the manual form, or **Export CSV** to download portals (credentials included) as a spreadsheet file; **Save** to sync.
4. Tap a portal in the list to load its catalog

## Tips

- Portal passwords on this device use Keychain / Keystore; CSV import/export files still contain passwords in plain text — keep those files private
- **Portals** panel on the right (desktop / Android TV) holds add and the full portal list (plus scrape when the account feature is on) — search filters by portal name, account name, or URL
- Section chips (**Live** / **Movies** / **Series**) switch the catalog; data stays cached until you hit **Reload** on the selected shelf (or the centered **Reload** button when the catalog failed to load)
- On **Android TV**, focusable controls (search, portals, dialogs, back/close, portal actions, group rows) use **brand green** when D-pad focused — **Live / Movies / Series** shelf chips keep their own section colors on focus (same as hover)
- On **Android TV**, search fields focus in browse mode first — press **Enter** on the remote to open the keyboard, then type
- On **Android TV**, D-pad from **Open portal** (no provider yet) opens the **Portals** panel with focus on **Add** (+)
- On **Android TV**, in the **Portals** panel: **Down** from the top-bar **Portals** button enters the header actions (**Add**); **Up** from header actions returns to the top-bar **Portals** button; **Down** from header actions enters the portal list; **Up** from the first portal row returns to **Add**; **Left** on a focused row reaches **Favorite**; **Right** moves through **copy / edit / delete**; **Back** closes the panel and restores **category** focus
- On **Android TV**, **Add portal** dialog opens with focus on the manual-entry **↓** control (not the share-code keyboard); **Up** / **Down** move between share code and expand when collapsed — expand first to reach Portal name, URL, username, password, then the green **check** / muted **close** icons; after a share code resolves, focus lands on **Portal name** before connect; **Up** from share code does not move to the header **X** (use **Back** to dismiss); fields use an underline highlight on focus — press **Enter** to open the keyboard and type; **Edit portal** opens with Portal name highlighted (Enter to edit)
- On **Android TV**, top bar: **Portals** ← **Search** ← **Live / Movies / Series** (search field stays out of the chain until you activate search); **Down** from shelf tabs or **Search** jumps to the **selected group** row in the catalog sidebar (when the **Portals** panel is closed, **Down** from **Portals** does the same; when the panel is open, **Down** from **Portals** enters the panel header actions instead)
- On **Android TV**, catalog: **Right** from a group row focuses the **channel** list (restores your last channel when possible); **Left** from the first column of channels (or any channel in the compact list) returns to that channel's **group** row in the sidebar; **Up** from the first channel row goes to the **active shelf tab** (left columns) or the **Portals** button (rightmost column); **Up** from the first group row returns to the active shelf tab
- On **Android TV**, choosing **IPTV** in the nav menu lands focus on the **first group row** once the catalog has loaded (spinner shown while loading)
- On **Android TV**, D-pad moves **Live / Movies / Series** → categories → streams; with the **Portals** panel open, **Right** from the stream grid (or portal button) enters the portal list, **Left** from a portal row returns focus to the **selected category** row
- Press **Back** / **Escape** to close the Portals panel before leaving the tab
- While watching **live TV**, tap the grid icon in the player controls to open the channel guide
- Programme guide is optional — turn off **IPTV programme guide (EPG)** under Settings → Playback if you want zero EPG network requests
- **Scrape** / **Find Portals** is available only when your signed-in account has `iptvScrape` enabled in cloud account features (default off; guests never see it). When enabled, scrape walks Reddit IPTV communities only (GitHub XML2 dump scraping is disabled for now), and the web **Account → IPTV** page shows a VIP **Activated** banner for that perk
- Portal quality varies — timeouts usually mean provider or network issues
- Clear stale alive checks / channel scan hits from **Settings → Data & backup → IPTV portal cache** (portals and favorites stay)
- Export or import Xtream portals as CSV from **Settings → Data & backup → IPTV portals** (same format as the web remote settings page; import adds only portals that are not already saved)
- Series VOD uses the same player as live with seek support when the stream allows — the VOD seek bar uses Forja brand green for the played fill and thumb

## Related

- [IPTV — M3U](iptv-m3u.md)
- [Cache & data](../settings/cache-data.md)
- [Player](../playback/player.md)
