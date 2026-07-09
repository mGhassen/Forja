# Media details

> Full movie and series page — metadata, torrents, streams, episodes, and lists.

## What it is

When you open a title from Home, Discover, or Search (with torrent mode enabled), you get the **torrent details** screen. A **cinematic hero** (~82% of the viewport for movies, ~68% for TV so the episode rail sits higher on the first screen) shows Ken Burns backdrop animation, then a chromeless YouTube trailer after a random **12–20 seconds** (preloaded for a smooth crossfade). After each trailer finishes, the backdrop returns for another random 12–20 seconds, then the trailer plays again. Trailer audio is on by default and fades from quiet to full volume over 3 seconds. A **mute** button in the bottom-right of the hero toggles sound.

The hero overlay is split into two columns on wide screens:

- **Left:** TMDB logo or stylized title, inline genres (`Horror • Thriller`), year · runtime · certification · rating, director line, synopsis (left **40%** of the screen), then **Play** / **Resume** (tries enabled play sources in order; opens **Sources** only if playback cannot start), **Trailer** (when TMDB has videos — opens the in-app trailer player on the best match), and a combined **+ | download | ⋯** pill for My List, download (opens **Sources**), and overflow; watch progress when you have history appears below the actions.
- **Right:** **Production Info** panel — status, language, and TV fields (first/last aired, seasons, episodes, network, production companies, origin, creators) or movie fields (release date, runtime, production, origin, budget/revenue) from TMDB rich details.

Hero text sits in the **upper** area of the hero (not pinned to the bottom). Below the hero, the page uses a **flat shell background** (same `#141414` as the left nav rail and Home catalog rows) — no blurred backdrop bleed-through.

Scroll below the hero for:

1. **Episodes** (TV only) — horizontal episode rail with season picker; when a season has more than 50 episodes, numbered range chips (**1 - 50**, **51 - 100**, …) appear beside the season control to page the rail; visible on the first screen below the hero
2. **Cast** — circular photos, actor and character names
3. **Trailers** — horizontal row of YouTube trailers/teasers from TMDB; tap to open the in-app trailer player (seek bar, ±10s skip, volume, audio, subtitles, quality, playback speed). When a trailer ends and more are available, an **Up next** prompt lets you continue to the next trailer.
4. **More Like This** — recommendation row

Torrent search, Stremio/Nuvio streams, **Webstreaming** (VidLink, WebStreamr, Videasy, …), and source picking stay in the **Sources** side panel. Only play sources enabled in **Settings → Playback** appear there.

## How to open it

Tap any movie or series poster from Home, Discover, Search, or lists — when **Direct streaming mode** is off in Settings.

## What you can do

- Watch the Ken Burns backdrop (12–20s), then chromeless autoplay trailer in the hero when TMDB has one; alternates after each trailer ends (sound on, volume ramps up; mute toggle bottom-right)
- **Play** / **Resume** tries enabled play sources in order; opens **Sources** only if nothing could start
- **Download** or an episode tap opens **Sources** to pick a stream manually
- **Trailer** (when available) opens the in-app trailer player on the best-matching official trailer
- Add or remove from **My List** (**+** button in hero)
- Trakt/Simkl/collect actions via the **⋯** overflow menu in the hero
- See resume progress in the hero for movies and the selected TV episode
- For TV: pick a season from square cards, then tap an episode in the rail to select it and open **Sources** (resume position when you have history is applied when you pick a stream)
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
- Enable **Direct streaming mode** to use the [streaming details](direct-streaming-mode.md) screen instead (same hero layout; **Play** starts stream extraction; **Trailer** works the same way)

## Related

- [Direct streaming mode](direct-streaming-mode.md)
- [Torrent playback](../playback/torrent-playback.md)
- [Watch history](watch-history.md)
- [My List](my-list.md)
