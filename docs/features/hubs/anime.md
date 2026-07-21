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
- Open details with episodes — the episode rail shows skeleton cards until the playable list is ready (not a temporary AniList count that then shrinks). Hero **N eps** is AniList metadata; the rail prefers a matched Anikoto series and rejects stub/movie hits that are far shorter than that total (then falls back to an AniList-sized list). Tap an episode card to select it; click the card’s **play** button (or hero **Play** / **Resume**) to start that episode. On **TV**, **Play** / **Resume** is focused when the page opens; **↑** from hero actions (including **SUB** / **DUB**) focuses the back chevron; **←** from the leftmost hero action moves focus to the shell nav rail; **↑** from episodes or **More Like This** returns focus to **Play**
- Toggle **SUB** / **DUB** before playback — on **TV**, D-pad left/right from **Play** (or clear-progress) reaches the segments; **OK** selects
- Resume from continue watching — fetches fresh catalog data and scans all providers (not a stale one-source cache); clear progress with the trash icon next to **Resume** on details. On **TV**, **↑** from Continue Watching focuses hero **Play**; empty Continue Watching is removed from the D-pad graph; close/info chips on the card are mouse-only
- Mood results: on **TV**, **↑** from the mood poster row returns to the mood chips
- Hover a continue watching card (desktop) to scale it and show a brand-green play button that floats upward while its play icon pulses slowly
- Play in the anime player — races servers in Settings order until the **first** playable stream is found, probes that URL, then opens the player and **stops** scanning. Remaining servers stay in the **Source** panel for manual taps (or dead-stream recovery), not a background fill while you watch. Miruro-backed rows (e.g. **AniKoto**) expand every playable CDN under that provider (named servers when the pipe labels them — VidPlay, Vidstream, VidCloud, …), not only the first HLS URL. Each server row shows **SUB** or **DUB** (purple / amber badge), IPTV-style status glyphs (**...** / spinner / dot / play / failed). Replaying an episode from a saved stream uses the same dead-cache recovery as movies: if that CDN is dead, Forja drops the cache and searches for another server. A green server with a red-X stream means extract listed but the CDN probe failed. Finished episodes (≥90% watched) restart from the beginning on Resume / Continue Watching, same as movies
- Track watch history per series (sub/dub preference)

## Tips

- Anime uses its own player and history — separate from TMDB TV details
- Reorder anime sources under **Settings → Playback → Anime provider order** (same real provider names as the in-player source menu). Default try order starts with **Megaplay** and **Vidwish** (direct embed), then VidNest / AllAnime, then Miruro Cloudflare pipes
- Megaplay plays from AniList id via `/stream/ani/…` (Anikoto `s-2` embed ids still preferred when matched). Vidwish only appears when Anikoto matched an `s-2` id — its `/stream/ani/…` path is dead. Megaplay HLS CDNs (`mewstream`, `nekostream`, …) use a `megaplay.buzz` Referer for probe and play (including cached / reloaded streams). Segments that look like PNG “ads” but wrap real MPEG-TS (Megaplay anti-scraper) are unwrapped through the local HLS proxy and play; only true image-only poison is skipped. Anime hosts, path templates, Miruro/KissKh mirrors, API bases, and CDN Referer rules can be updated remotely (cloud `provider_runtime_config`) without an app update — offline builds keep the same built-in defaults. Miruro works from AniList id alone (Cloudflare WebView pipe — blank / failed challenge pages are not treated as unlocked)
- **VidNest HiAnime** and **VidNest AnimePahe** resolve from AniList id via `new.vidnest.fun` (same decrypt as movie VidNest)
- AllAnime **Default** tries Yt-mp4 first (direct MP4), then S-mp4 / Luf-Mp4 when those clock links still work
- Playback shows a backdrop + title loading screen before the player opens (same pattern as films and Asian drama) — progress shows `N / M CHECKED · K UP`; next to **Cancel**, open the layers icon for the server list and tap a source to check it manually. If nothing works, the same screen explains it in plain language (**No streams found**) with **Try again** and **Close** (on **TV**, **Try again** autofocuses; **↓** → **Close**); a dead saved link offers **Search again**
- **Escape** / **Cancel** during resolve or before video starts returns to details — not the loading screen. Leaving the title or switching shell tabs mid-check also stops the server search (same stop as **Cancel**).
- Part of [content hub scrapers](../scrapers/content-hub-scrapers.md)

## Related

- [Anime Arabic](anime-arabic.md)
- [Playback settings](../settings/playback-settings.md)
- [Next episode](../playback/next-episode.md)
