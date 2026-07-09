# Media details

> Full movie and series page — metadata, torrents, streams, episodes, and lists.

## What it is

When you open a title from Home, Discover, Search, or lists, you get the **media details** screen — one screen for torrents, Stremio/Nuvio, and webstreaming. A **cinematic hero** (~82% of the viewport for movies, ~68% for TV so the episode rail sits higher on the first screen) shows Ken Burns backdrop animation, then a chromeless YouTube trailer after a random **12–20 seconds** (preloaded for a smooth crossfade). After each trailer finishes, the backdrop returns for another random 12–20 seconds, then the trailer plays again. Trailer audio is on by default and fades from quiet to full volume over 3 seconds. A **mute** button in the bottom-right of the hero toggles sound.

The hero overlay is split into two columns on wide screens:

- **Left:** TMDB logo or stylized title, inline genres (`Horror • Thriller`), year · runtime · certification · rating, director line, synopsis (left **40%** of the screen), then green **Play** / **Resume** with play icon (webstreaming best extractor when enabled), white **Play** / **Resume** with magnet icon (opens the **Sources** panel for torrent / Stremio), **Trailer** (when TMDB has videos — opens the in-app trailer player on the best match), and a combined **+ | download | ⋯** pill for My List, download (opens **Sources**), and overflow; watch progress when you have history appears below the actions.
- **Right:** **Production Info** panel — status, language, and TV fields (first/last aired, seasons, episodes, network, production companies, origin, creators) or movie fields (release date, runtime, production, origin, budget/revenue) from TMDB rich details.

Hero text sits in the **upper** area of the hero (not pinned to the bottom). Below the hero, the page uses a **flat shell background** (same `#141414` as the left nav rail and Home catalog rows) — no blurred backdrop bleed-through.

Scroll below the hero for:

1. **Episodes** (TV only) — horizontal episode rail with season picker; when a season has more than 50 episodes, numbered range chips (**1 - 50**, **51 - 100**, …) appear beside the season control to page the rail; visible on the first screen below the hero
2. **Cast** — circular photos, actor and character names
3. **Trailers** — horizontal row of YouTube trailers/teasers from TMDB; tap to open the in-app trailer player (seek bar, ±10s skip, volume, audio, subtitles, quality, playback speed). When a trailer ends and more are available, an **Up next** prompt lets you continue to the next trailer.
4. **More Like This** — recommendation row

Torrent search and Stremio streams share one **Sources** list. The panel chrome is compact: **Sources** + count, then **All / Torrents / Stremio** (and **Nuvio** when installed) chips, optional provider chips when filtered, then search + filters. **Webstreaming** is started from the hero green **Play** / **Resume** (play icon) — it is not in Sources. Only torrent/Stremio play sources enabled in **Settings → Playback** appear in the panel.

## How to open it

Tap any movie or series poster from Home, Discover, Search, or lists.

## What you can do

- Watch the Ken Burns backdrop (12–20s), then chromeless autoplay trailer in the hero when TMDB has one; alternates after each trailer ends (sound on, volume ramps up; mute toggle bottom-right)
- Green **Play** / **Resume** (play icon) auto-extracts the best direct webstreaming link when that play source is enabled
- White **Play** / **Resume** (magnet icon) opens **Sources** so you pick a torrent/Stremio stream
- **Download** or an episode tap opens **Sources** to pick a torrent/Stremio stream manually
- **Trailer** (when available) opens the in-app trailer player on the best-matching official trailer
- Add or remove from **My List** (**+** button in hero)
- Trakt/Simkl/collect actions via the **⋯** overflow menu in the hero
- See resume progress in the hero for movies and the selected TV episode
- For TV: pick a season from square cards, then tap an episode in the rail to select it and open **Sources** (resume position when you have history is applied when you pick a stream)
- Browse main cast and “More Like This” recommendations below the hero
- Search and sort torrent results in Sources (seeders, size, etc.)
- Filter Sources by quality, size (`<1 GB` · `1–3 GB` · `3–8 GB` · `8–20 GB` · `20 GB+`, multi-select OR), language, tech, and audio
- Resolve torrents through debrid when configured
- Mark watched / unwatched per episode
- Use [Webstreaming](direct-streaming-mode.md) via the hero green **Play** / **Resume** (play icon) button

## Setup (if needed)

- [Torrent scrapers](../scrapers/torrent.md), [Jackett](../scrapers/jackett.md), [Prowlarr](../scrapers/prowlarr.md) for more torrent results
- [Debrid](../sources/debrid.md) for instant cached playback
- [Stremio addons](../sources/stremio-addons.md) for addon streams
- [Stream providers](../sources/stream-providers.md) — webstreaming extractor order

## Tips

- Sort order for torrents is set in Settings → Search & Torrents
- Enable only **Webstreaming** under Play sources if you want a single green **Play** / **Resume** without torrent/Stremio **Sources**

## Related

- [Webstreaming](direct-streaming-mode.md)
- [Playback settings](../settings/playback-settings.md)
- [Torrent playback](../playback/torrent-playback.md)
- [Watch history](watch-history.md)
- [My List](my-list.md)
