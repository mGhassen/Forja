# Anime

> Dedicated anime hub — discover, search, and multi-server playback.

## What it is

The Anime tab is a full vertical for anime: hero carousel, mood chips, continue watching, curated rails (trending, airing, etc.), discover filters, search, and a dedicated player that probes available stream sources (Megaplay, VidNest, VidLink, AllAnime, plus adult fallbacks when needed).

## How to open it

Tap **Anime** in the navigation bar.

## What you can do

- Browse hero and mood-based rails — titles follow **Settings → Playback → Anime title language** (**Romaji** by default; English or Native optional)
- Continue watching in-progress series
- Discover with filters
- Search anime catalog — **desktop / TV:** same layout as the Search tab (large search field, trending title suggestions on the left, poster grid on the right; **Select** a suggestion to run that search; on desktop, hover a result card to reveal the info button — click it or double-click the card to open details); **mobile:** search bar + results grid — on **desktop**, **Cmd+F** / **Ctrl+F** opens this search page (or focuses the field when it is already open)
- Open details with episodes — on wide screens the hero shows the same production facts card as movies/TV (status, format, episodes, etc.; no heading). The episode rail uses AniList episode totals (same as hero **N eps**), not an Anikoto catalog crawl. On **Play**, Forja matches Anikoto for Megaplay catalog embed ids (and VidNest when AniList ids diverge). Tap an episode card to select it; click the card’s **play** button (or hero **Play** / **Resume**) to start that episode. On **TV**, **Play** / **Resume** is focused when the page opens; **↑** from hero actions (including **SUB** / **DUB**) focuses the back chevron; **←** from the leftmost hero action moves focus to the shell nav rail; **↑** from episodes or **More Like This** returns focus to **Play**
- Toggle **SUB** / **DUB** before playback — on **TV**, D-pad left/right from **Play** (or clear-progress) reaches the segments; **OK** selects
- Resume from continue watching — fetches fresh catalog data and scans all providers (not a stale one-source cache); clear progress with the trash icon next to **Resume** on details. On **TV**, **↑** from Continue Watching focuses hero **Play**; empty Continue Watching is removed from the D-pad graph; close/info chips on the card are mouse-only
- Mark episodes watched / unwatched on details — right-click (secondary tap) an episode card for a checkmark; local only (not Trakt / Simkl). Cleared with **Settings → Cache & data → Watched episode marks**
- Mood results: on **TV**, **↑** from the mood poster row returns to the mood chips
- Hover a continue watching card (desktop) to scale it and show a brand-green play button that floats upward while its play icon pulses slowly
- Play in the anime player — races servers in Settings order until the **first** playable stream is found, probes that URL, then opens the player and **stops** scanning. Remaining servers stay in the **Source** panel for manual taps (or dead-stream recovery), not a background fill while you watch. Each server row shows **SUB** or **DUB** (purple / amber badge), IPTV-style status glyphs (**...** / spinner / dot / play / failed). Replaying an episode from a saved stream uses the same dead-cache recovery as movies: if that CDN is dead, Forja drops the cache and searches for another server. A green server with a red-X stream means extract listed but the CDN probe failed. Finished episodes (≥90% watched) restart from the beginning on Resume / Continue Watching, same as movies
- Track watch history per series (sub/dub preference)

## Tips

- On **desktop**, drag-select hub and details hero titles to copy them
- Anime hub / details heroes prefer TMDB cinematic backdrops (title + year match); AniList banner/cover is fallback. Catalog posters stay AniList. Anime uses its own player and history — separate from TMDB TV details
- Prefer **Romaji** titles under **Settings → Playback → Anime title language** if English names feel wrong — stream matching always tries romaji first, then English, native, and AniList synonyms (so SPECIALS like *Character Endings* can still match scrapers indexed under *Harukanaru…*)
- Reorder anime sources under **Settings → Playback → Anime provider order** (same real provider names as the in-player source menu). Default try order starts with **Megaplay** and **AniKoto** (native site scrape), then VidNest / AllAnime, then **VidLink** (MAL embed), then Miruro **AniKoto** / **AnimePahe** / **AllManga** / **AnimeDao**
- Megaplay prefers Anikoto `s-2` catalog embed ids (getSources works even when the Megaplay HTML page is a 410). `/stream/ani/…` remains a last-resort native URL. **AniKoto** races anikototv.to’s Ajax server list (Vidstream → MegaPlay, VidPlay → VidTube, …) into native HLS — same buttons as the site. Miruro pipes for **AniKoto**, **AnimePahe**, **AllManga**, and **AnimeDao** stay available (CF WebView for unlock only — not a site Web player). Each anime source has its own probe rule from Providers config (e.g. AnimePahe checks the playlist only; Megaplay still samples segments for PNG ads). Megaplay and AllAnime / AllManga playback use their provider origin as Referer (not the CDN hostname) for probe and play — including cached / reloaded streams — so CDN renames do not break playback. Opening a stream walks an **open mind-tree**: classify the URL/body (PNG shell vs plain HLS vs progressive), pick one technique, and on open/decode failure **re-branch** (e.g. PNG→local strip proxy, plain HLS→direct then strip). No per-CDN host allowlists. Only true image-only poison is skipped. There is no Megaplay / VidNest / Anikoto site WebView fallback — if native streams fail, you get **Try again** / **Close**. Anime hosts, path templates, KissKh mirrors, API bases, and per-source probe / PNG-strip profiles can be updated remotely (cloud `provider_runtime_config`) without an app update — offline builds keep the same built-in defaults
- **VidLink** uses the MyAnimeList id from AniList (`idMal`) — `vidlink.pro/anime/{mal}/{ep}/sub|dub` — and sniffs the embed like movie/TV VidLink. Titles without a MAL mapping skip VidLink. On **Android TV**, VidLink is skipped (headless WebView blocked) unless the TV WebView extractor override is on
- **VidNest HiAnime** and **VidNest AnimePahe** resolve via `new.vidnest.fun` for native extract. When Anikoto maps a different AniList id for the same title, that id is used for VidNest
- AllAnime **Default** tries Yt-mp4 first (direct MP4), then S-mp4 / Luf-Mp4 when those clock links still work
- Playback shows a backdrop + title loading screen before the player opens (same pattern as films and Asian drama) — progress shows `N / M CHECKED · K UP`; next to **Cancel**, open the layers icon for the server list and tap a source to check it manually. If nothing works, the same screen explains it in plain language (**No streams found**) with **Try again** and **Close** (on **TV**, **Try again** autofocuses; **↓** → **Close**); a dead saved link offers **Search again**
- **Escape** / **Cancel** during resolve or before video starts returns to details — not the loading screen. Leaving the title or switching shell tabs mid-check also stops the server search (same stop as **Cancel**).
- Part of [content hub scrapers](../scrapers/content-hub-scrapers.md)

## Related

- [Anime Arabic](anime-arabic.md)
- [Playback settings](../settings/playback-settings.md)
- [Next episode](../playback/next-episode.md)
