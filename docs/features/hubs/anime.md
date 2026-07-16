# Anime

> Dedicated anime hub — discover, search, and multi-server playback.

## What it is

The Anime tab is a full vertical for anime: hero carousel, mood chips, continue watching, curated rails (trending, airing, etc.), discover filters, search, and a dedicated player that probes available stream sources (Megaplay/Vidwish via Anikoto, Miruro pipes, AllAnime, plus adult fallbacks when needed).

## How to open it

Tap **Anime** in the navigation bar.

## What you can do

- Browse hero and mood-based rails
- Continue watching in-progress series
- Discover with filters
- Search anime catalog — **desktop / TV:** same layout as the Search tab (large search field, trending title suggestions on the left, poster grid on the right; **Select** a suggestion to run that search; on desktop, hover a result card to reveal the info button — click it or double-click the card to open details); **mobile:** search bar + results grid — on **desktop**, **Cmd+F** / **Ctrl+F** opens this search page (or focuses the field when it is already open)
- Open details with episodes — tap an episode to select it; **Play** / **Resume** starts that episode. On **TV**, **Play** / **Resume** is focused when the page opens; **↑** from hero actions closes details; **←** from the leftmost hero action moves focus to the shell nav rail; **↑** from episodes or **More Like This** returns focus to **Play**
- Toggle **SUB** / **DUB** before playback
- Resume from continue watching — fetches fresh catalog data and scans all providers (not a stale one-source cache); clear progress with the trash icon next to **Resume** on details
- Hover a continue watching card (desktop) to scale it and show a brand-green play button that enlarges and floats upward
- Play in the anime player — launches once ~4 sources work (Settings order), then keeps finding more in the background so the in-player **Source** panel fills while you watch. Each server row shows **SUB** or **DUB** (purple / amber badge), IPTV-style status glyphs (**...** / spinner / dot / play / failed), and you can tap several unloaded servers in parallel to fetch streams without leaving the panel
- Track watch history per series (sub/dub preference)

## Tips

- Anime uses its own player and history — separate from TMDB TV details
- Reorder anime sources under **Settings → Playback → Anime provider order** (same real provider names as the in-player source menu)
- Megaplay / Vidwish need Anikoto catalog linkage; Miruro works from AniList id alone (via a Cloudflare WebView pipe when plain HTTP is blocked)
- **VidNest HiAnime** and **VidNest AnimePahe** resolve from AniList id via `new.vidnest.fun` (same decrypt as movie VidNest)
- AllAnime **Default** tries Yt-mp4 first (direct MP4), then S-mp4 / Luf-Mp4 when those clock links still work
- Playback shows a backdrop + title loading screen before the player opens (same pattern as films and Asian drama) — progress shows `N / M CHECKED · K UP`; next to **Cancel**, open the layers icon for the server list and tap a source to check it manually
- **Escape** / **Cancel** during resolve or before video starts returns to details — not the loading screen
- Part of [content hub scrapers](../scrapers/content-hub-scrapers.md)

## Related

- [Anime Arabic](anime-arabic.md)
- [Playback settings](../settings/playback-settings.md)
- [Next episode](../playback/next-episode.md)
