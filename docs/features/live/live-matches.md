# Live Matches

> Watch live sports and events from aggregated stream sources.

## What it is

Live Matches pulls schedules and streams from sports APIs ([PPV](https://ppv.is) / `api.ppv.st`, with CDN Live TV as an alternate path in code). Browse by sport category, pick a match, and watch in the built-in live player (libmpv with buffering and reconnect). If stream extraction fails, playback falls back to an embedded WebView player.

## How to open it

Tap **Live Matches** in the navigation bar.

## What you can do

- Switch sport category tabs
- Browse upcoming and live events
- Open a match and watch the stream (native player when the embed URL can be resolved; WebView fallback otherwise)
- Refresh lists for new events

## Tips

- Streams are third-party — availability changes with broadcasts and region
- WebView fallback may behave differently per platform; some embeds still require a tap if the site blocks unmuted autoplay

## Related

- [Content hub scrapers](../scrapers/content-hub-scrapers.md)
- [IPTV — Xtream](iptv-xtream.md)
