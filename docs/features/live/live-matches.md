# Live Matches

> Watch live sports and events from aggregated stream sources.

## What it is

Live Matches pulls schedules and streams from sports APIs ([PPV](https://ppv.is) / `api.ppv.st`, [Streamed](https://streamed.pk/docs) / `streamed.pk`, and CDN Live). Browse by sport category, pick a match, and watch in an embedded WebView player. Some third-party embeds cannot be replayed in the native mpv player because their HLS URLs are session-bound.

## How to open it

Tap **Live Matches** in the navigation bar.

## What you can do

- Use **Servers** to switch between All, PPV, Streamed, or CDN Live
- Switch sport category circles (All merges the same sport across servers — e.g. PPV “Football” and Streamed “football” share one chip). **24/7** always-on streams appear only when you select the 24/7 chip — they are hidden from All and from other sports (card grid and timeline)
- Switch between **card view** and **timeline view** with the button to the right of Refresh. Forja remembers this choice across app restarts. Timeline view places each **1-hour** group on a continuous clock — a 00:10 card sits at 00:00 on the ruler (not stuck at the top). Same-hour streams share one horizontal line (swipe sideways for more without moving time). Vertical scroll moves the clock; **Day / 12h / 6h** set how many hours one screen height covers. Click the playhead time badge to jump back to now. Hovering a card scales it up, gives it a white border, and lifts it above nearby cards. CDN channels have no schedule, so timeline shows CDN sport events only.
- Browse upcoming and live events — live matches appear first; only **live** matches are tappable and show the play control on hover/focus; upcoming cards show the start time badge only
- Open a match and watch the stream in the embed player (PPV or Streamed badge top-right; autoplay when the embed allows it)
- Back / Escape exits the embed and **stops audio** (the stream is torn down, not left playing in the background)
- When a Streamed match has several streams, the picker lists each stream with an HD badge, its **source** (Admin / Delta / Echo …), language, and a **viewer count**; streams are ordered by viewers (busiest first) as a rough reliability hint — if one stream is dead, pick the next one
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
