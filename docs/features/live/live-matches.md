# Live Matches

> Watch live sports and events from aggregated stream sources.

## What it is

Live Matches pulls schedules and streams from sports APIs ([PPV](https://ppv.is) / `api.ppv.st`, [Streamed](https://streamed.pk/docs) / `streamed.pk`, and CDN Live). Browse by sport category, pick a match, and watch in an embedded WebView player. Some third-party embeds cannot be replayed in the native mpv player because their HLS URLs are session-bound.

## How to open it

Tap **Live Matches** in the navigation bar.

## What you can do

- Use **Servers** to switch between All, PPV, Streamed, or CDN Live
- Switch sport category circles (All merges the same sport across servers — e.g. PPV “Football” and Streamed “football” share one chip). When PPV and Streamed carry the same scheduled match, All also combines them into one card. **24/7** covers PPV’s 24/7 category (including `always_live` channels whose start/end times are stale) and Streamed always-on channels (no schedule date — e.g. Willow Cricket, Tennis Channel, Rally TV). Those appear only on the 24/7 chip — hidden from All and from other sports (card grid and timeline) — and stay tappable as LIVE
- Switch between **card view** and **timeline view** with the button to the right of Refresh. Forja remembers this choice across app restarts. Timeline view places each **1-hour** group on a continuous clock — a 00:10 card sits at 00:00 on the ruler (not stuck at the top). Same-hour streams share one horizontal line (swipe sideways for more without moving time). Opening the timeline (or switching to it / reloading) lands on **now**, not the first card; click the playhead time badge to jump back to now anytime. Vertical scroll moves the clock; **Day / 12h / 6h** set how many hours one screen height covers. The ruler tints each day a different colour (today stays white), and a green **NOW** line marks the current time. Hovering a card highlights it in place and lifts just that card above overlapping neighbours (no scale). CDN channels have no schedule, so timeline shows CDN sport events only.
- Browse upcoming and live events — live matches appear first; only **live** matches are tappable and show the play button (green on hover/focus). Upcoming cards still highlight and lift on hover in the timeline; they show the start time badge only
- Open a match and watch the stream in the embed player (PPV or Streamed badge top-right; autoplay when the embed allows it)
- Back / Escape exits the embed and **stops audio** — the top bar sits above the WebView (not overlaid on it) so Back stays clickable on desktop
- When a match has several streams, the picker badges every choice as **PPV** or **Streamed**. Streamed choices also show HD, their source (Admin / Delta / Echo …), language, and viewer count; they are ordered by viewers (busiest first) as a rough reliability hint — if one stream is dead, pick the next one
- Double-click the video to enter/exit fullscreen (desktop window fullscreen for embeds; native PPV streams use the IPTV player)
- Refresh lists for new events

## Tips

- Streams are third-party — availability changes with broadcasts and region
- Streamed / PPV embeds play inside a WebView iframe that mirrors the website parent page (`streamed.pk` / `ppv.is`); ad scripts that block the player page are filtered, and main-frame ad redirects are cancelled so they cannot take over the player
- Ad popups are accepted off-screen (required by some Streamed embeds) and never shown over the player; main-frame ad redirects are still cancelled
- WebView playback may behave differently per platform; some embeds still require a tap if the site blocks unmuted autoplay
- On Windows, Live Matches loads the embed URL directly (the path that played before the macOS iframe rewrite) and forces an opaque WebView2 surface so the window does not go white/transparent; other platforms keep the iframe wrapper + hidden ad `window.open` host
- Escape still backs out of the embed player on all platforms (and stops the stream)

## Related

- [Content hub scrapers](../scrapers/content-hub-scrapers.md)
- [IPTV — Xtream](iptv-xtream.md)
