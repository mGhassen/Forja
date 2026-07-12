# Live Matches

> Watch live sports and events from aggregated stream sources.

## What it is

Live Matches pulls schedules and streams from sports APIs ([PPV](https://ppv.is) / `api.ppv.st`, with CDN Live TV as an alternate path in code). Browse by sport category, pick a match, and watch in an embedded WebView player (same embed ppv.is uses). Some third-party embeds cannot be replayed in the native mpv player because their HLS URLs are session-bound.

## How to open it

Tap **Live Matches** in the navigation bar.

## What you can do

- Switch sport category tabs
- Browse upcoming and live events
- Each card shows a centered play control; it highlights and scales when you hover or focus the card
- Open a match and watch the stream in the embed player (autoplay when the embed allows it)
- Double-click the video to enter/exit fullscreen (desktop window fullscreen for embeds; native PPV streams use the IPTV player)
- Refresh lists for new events

## Tips

- Streams are third-party — availability changes with broadcasts and region
- WebView playback may behave differently per platform; some embeds still require a tap if the site blocks unmuted autoplay

## Related

- [Content hub scrapers](../scrapers/content-hub-scrapers.md)
- [IPTV — Xtream](iptv-xtream.md)
