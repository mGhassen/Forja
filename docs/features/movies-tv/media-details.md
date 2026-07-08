# Media details

> Full movie and series page — metadata, torrents, streams, episodes, and lists.

## What it is

When you open a title from Home, Discover, or Search (with torrent mode enabled), you get the **torrent details** screen. A **cinematic hero** (~82% of the viewport) shows Ken Burns backdrop animation, then a chromeless YouTube trailer after a random **12–20 seconds** (preloaded for a smooth crossfade). After each trailer finishes, the backdrop returns for another random 12–20 seconds, then the trailer plays again. Trailer audio is on by default and fades from quiet to full volume over 3 seconds. A **mute** button in the bottom-right of the hero toggles sound.

The hero overlay is split into two columns on wide screens:

- **Left:** TMDB logo or stylized title, inline genres (`Horror • Thriller`), **Play** / **Resume** (white pill — opens Sources), **+** (My List), download (opens Sources), year · runtime · certification · rating, director line, synopsis (left **40%** of the screen), and watch progress when you have history.
- **Right:** a stats panel with runtime (and estimated end time when resuming), language, release date, production companies, origin countries, and budget/revenue for movies when TMDB has them.

Hero text sits in the **upper** area of the hero (not pinned to the bottom). The backdrop **blurs and darkens** into Cast / Trailers below — no hard cut to a flat black block.

Scroll below the hero for:

1. **Seasons** (TV only) — square season photo cards; tap a season to expand the episode rail
2. **Main Characters** — cast photos and roles
3. **Trailers** — horizontal row of YouTube trailers/teasers from TMDB; tap to open in your browser
4. **More Like This** — recommendation row

Torrent search, Stremio/Nuvio streams, and source picking stay in the **Sources** side panel (opened from **Play** in the hero).

## How to open it

Tap any movie or series poster from Home, Discover, Search, or lists — when **Direct streaming mode** is off in Settings.

## What you can do

- Watch the Ken Burns backdrop (12–20s), then chromeless autoplay trailer in the hero when TMDB has one; alternates after each trailer ends (sound on, volume ramps up; mute toggle bottom-right)
- **Play** / **Resume** opens the Sources panel to pick torrents or addon streams
- Add or remove from **My List** (**+** button in hero)
- Trakt/Simkl/collect actions via the **⋯** overflow menu in the hero
- See resume progress in the hero for movies and the selected TV episode
- For TV: pick a season from square cards, then an episode from the expandable rail
- Browse main cast and “More Like This” recommendations below the hero
- Search and sort torrent results in Sources (seeders, size, etc.)
- Resolve torrents through debrid when configured
- Mark watched / unwatched per episode

## Setup (if needed)

- [Torrent scrapers](../scrapers/torrent.md), [Jackett](../scrapers/jackett.md), [Prowlarr](../scrapers/prowlarr.md) for more torrent results
- [Debrid](../sources/debrid.md) for instant cached playback
- [Stremio addons](../sources/stremio-addons.md) for addon streams

## Tips

- Sort order for torrents is set in Settings → Search & Torrents
- Enable **Direct streaming mode** to use the [streaming details](direct-streaming-mode.md) screen instead (same hero layout; **Play** starts stream extraction)

## Related

- [Direct streaming mode](direct-streaming-mode.md)
- [Torrent playback](../playback/torrent-playback.md)
- [Watch history](watch-history.md)
- [My List](my-list.md)
