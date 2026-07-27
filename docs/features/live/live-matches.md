# Live Matches

> Watch live sports and events from aggregated stream sources.

## What it is

Live Matches pulls schedules and streams from sports APIs ([PPV](https://ppv.is) / `api.ppv.st`, [Streamed](https://streamed.pk/docs) / `streamed.pk`, and CDN Live). Browse by sport category, pick a match, and watch in an embedded WebView player. Some third-party embeds cannot be replayed in the native mpv player because their HLS URLs are session-bound.

## How to open it

Tap **Live Matches** in the navigation bar.

## What you can do

- Use **Servers** to switch between All, PPV, Streamed, or CDN Live
- Switch sport category circles (All merges the same sport across servers — e.g. PPV “Football” and Streamed “football” share one chip). When PPV and Streamed carry the same scheduled match, All also combines them into one card. **24/7** covers PPV’s 24/7 category (including `always_live` channels whose start/end times are stale) and Streamed always-on channels (no schedule date — e.g. Willow Cricket, Tennis Channel, Rally TV). Those appear only on the 24/7 chip — hidden from All and from other sports (card grid and timeline) — and stay tappable as LIVE
- On **phone / desktop**, switch between **card view** and **timeline view** with the button to the right of Refresh. Timeline is the default; Forja remembers this choice across app restarts. Timeline view places each **1-hour** group on a continuous clock — a 00:10 card sits at 00:00 on the ruler (not stuck at the top). Same-hour streams share one horizontal line (swipe sideways for more without moving time). Opening the timeline (or switching to it / reloading) lands on **now**, not the first card; click the playhead time badge to jump back to now anytime. Vertical scroll moves the clock; **Day / 12h / 6h** set how many hours one screen height covers. The ruler tints each day a different colour (today stays white), and a green **NOW** line marks the current time. Hovering a card highlights it in place and lifts just that card above overlapping neighbours (no scale). **Miscellaneous / Other** events that are still airing (e.g. a stage race that started hours ago) stay pinned on the NOW line instead of sitting in the past. CDN channels have no schedule, so timeline shows CDN sport events only
- On **TV (Android TV / leanback)**, Live Matches is **cards only** — no timeline view and no view toggle. Sport chips sit flush left with **Servers** and the card grid (scaled to fit when needed). D-pad moves **Servers → Refresh → sport chips → match cards** (and on CDN Live, **Channels / Sports** chips between sports and the grid). Focused **Servers** uses the brand-green hover chrome; focused **Refresh** turns white. Within the card grid, **←/→** stay on the current row (row ends do not wrap). **↑** from the first card row returns to chips (not skipping to Servers). **←** from the left edge of a row returns to the nav rail. Empty lists autofocus **Refresh**. While a stream is resolving, **Cancel** / Back dismisses the loading dialog instead of trapping the remote. Entering the tab restores the last grid focus
- Browse upcoming and live events — live matches appear first (PPV **Live now** order prefers higher viewer counts; Streamed also merges the site’s **live** feed with the full schedule, so Popular Live rows like ACA / day-long golf are not missing). Only **live** matches are tappable and show the play button (green and floated upward, with a slowly pulsing play icon, on hover/focus). Upcoming cards still highlight and lift on hover in the timeline; they show the start time badge only. PPV cards show a live viewer count when the API reports one.
- Open a match and watch the stream in the embed player (PPV or Streamed badge top-right; autoplay when the embed allows it). On **TV**, the embed keeps Flutter chrome above/below the WebView so the remote is not stolen: focus lands on **Play**; **↑** reaches **Back**; **←/→** moves **Mute**. Select on Play/Pause drives the embed via a media bridge. Back / Escape exits the player. Some PPV streams open the native IPTV player instead — that path keeps the usual IPTV control-row D-pad
- Back / Escape exits the embed and **stops audio** — the top bar sits above the WebView (not overlaid on it) so Back stays clickable on desktop
- When a match has several streams, the picker badges every choice as **PPV** or **Streamed**. Streamed choices also show HD, their source (Admin / Delta / Echo …), language, and viewer count; they are ordered by viewers (busiest first) as a rough reliability hint — if one stream is dead, pick the next one. On **TV**, the first row autofocuses; **↑/↓** moves the list. Focused rows use a flat highlight (background fill, no zoom) with bold white title text — same for the **Servers** and CDN channel pickers
- Double-click the video to enter/exit fullscreen (desktop window fullscreen for embeds; native PPV streams use the IPTV player). On **TV**, there is no fullscreen button — the player is already immersive
- Refresh lists for new events

## Tips

- Streams are third-party — availability changes with broadcasts and region
- Streamed / PPV embeds play inside a WebView on **desktop / iOS**. Forja wraps the embed in an iframe under the catalog site (`streamed.pk` / `ppv.is`) so `document.referrer` matches the website; ad scripts that block the player page are filtered. The catalog wrapper URL is allowed once so the player can paint, then main-frame ad redirects are cancelled so they cannot take over the player. On **Android / Android TV**, Forja still loads that wrapper briefly to capture the HLS playlist, then switches to the **native IPTV player** (System WebView cannot play `embed.st` in-page — CORS blocks the playlist and the host shows “Remove sandbox attributes on the iframe tag”). embedindia PPV feeds that need the WebView stay in the embed player.
- Ad popups are accepted off-screen (required by some Streamed embeds) and never shown over the player; main-frame ad redirects are still cancelled
- WebView playback may behave differently per platform; some embeds still require a tap if the site blocks unmuted autoplay
- On Windows, Live Matches uses the same iframe wrapper + hidden ad `window.open` host as other desktop platforms, and forces an opaque WebView2 surface so the window does not go white/transparent
- Escape still backs out of the embed player on all platforms (and stops the stream)

## Related

- [Content hub scrapers](../scrapers/content-hub-scrapers.md)
- [IPTV — Xtream](iptv-xtream.md)
