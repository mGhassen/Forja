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
- Open details with episodes — on wide screens the hero shows the same production facts card as movies/TV (status, format, episodes, etc.; no heading). Multi-season franchises (AniList PREQUEL/SEQUEL spine) show a **Season 1…N** rail above episodes; picking a season switches that AniList entry (title, hero, episodes, Resume, watched marks) without leaving details — episode lists load only for the season you open. Single-cour titles stay one season. Continuous series like One Piece stay one Media (AniList has no arc seasons) — films, specials, and other franchise links appear under **Related** (directly under episodes) with AniList relation badges (Side Story, Summary, …). Then: **Characters**, **Staff**, **Trailers** (YouTube when AniList has one), and **More Like This** (AniList recommendations — separate from Related). The episode rail uses AniList episode totals (same as hero **N eps**), not an Anikoto catalog crawl. On **Play**, Megaplay / VidNest / Miruro use the AniList id on the card (plus MAL for Megaplay / VidLink when mapped) — no Anikoto title remap. Tap an episode card to select it; click the card’s **play** button (or hero **Play** / **Resume**) to start that episode. On **TV**, **Play** / **Resume** is focused when the page opens; **↑** from hero actions (including **SUB** / **DUB**) focuses the back chevron; **←** from the leftmost hero action moves focus to the shell nav rail; **↑** from seasons / episodes or lower rows returns focus to **Play**. Seasons already on the rail are omitted from **Related**
- Toggle **SUB** / **DUB** before playback — on **TV**, D-pad left/right from **Play** (or clear-progress) reaches the segments; **OK** selects
- Resume from continue watching — fetches fresh catalog data and scans all providers (not a stale one-source cache); clear progress with the trash icon next to **Resume** on details. After you leave the player, details refresh the hero progress bar, Resume label, and episode-rail bar from the same watch history. On **TV**, **↑** from Continue Watching focuses hero **Play**; empty Continue Watching is removed from the D-pad graph; close/info chips on the card are mouse-only
- Mark episodes watched / unwatched on details — auto at **≥85%** playback, or right-click (secondary tap) an episode card; local only (not Trakt / Simkl). Cleared with **Settings → Cache & data → Watched episode marks**. Details hero shows series progress (`N of T · %` or **Completed**)
- Mood results: on **TV**, **↑** from the mood poster row returns to the mood chips
- Hover a continue watching card (desktop) to scale it and show a brand-green play button that floats upward while its play icon pulses slowly
- Play in the anime player — races servers in Settings order until the **first** playable stream is found, probes that URL, then opens the player and **stops** scanning. Remaining servers stay in the **Source** panel for manual taps (or dead-stream recovery), not a background fill while you watch. Each server row shows **SUB** or **DUB** (purple / amber badge), IPTV-style status glyphs (**...** / spinner / dot / play / failed). Replaying an episode from a saved stream uses the same dead-cache recovery as movies: if that CDN is dead, Forja drops the cache and searches for another server. A green server with a red-X stream means extract listed but the CDN probe failed. Finished episodes (≥85% watched) restart from the beginning on Resume / Continue Watching, same as movies
- Track watch history per series (sub/dub preference)

## Tips

- On **desktop**, drag-select hub and details hero titles to copy them
- Anime hub hero paints AniList banner/cover first, then swaps in TMDB cinematic backdrops when ready (title + year match). Details heroes prefer TMDB the same way. Catalog posters stay AniList. Anime uses its own player and history — separate from TMDB TV details
- Prefer **Romaji** titles under **Settings → Playback → Anime title language** if English names feel wrong — stream matching always tries romaji first, then English, native, and AniList synonyms (so SPECIALS like *Character Endings* can still match scrapers indexed under *Harukanaru…*)
- Reorder anime sources under **Settings → Playback → Anime provider order** (same real provider names as the in-player source menu). Default try order starts with **Megaplay**, then **AniKoto** only when you pin it (native site scrape), then VidNest / AllAnime, then **VidLink** (MAL embed), then Miruro **AniKoto** / **AnimePahe** / **AllManga** / **AnimeDao**
- **Megaplay** uses the AniList id from the title you opened (`/stream/ani/…`) and, when a MAL id is resolved, also races `/stream/mal/…` — no Anikoto title match / `s-2` catalog remap (that could play the wrong show with no way to know). **AniKoto** (pinned) races anikototv.to’s Ajax server list into native HLS. Miruro pipes for **AniKoto**, **AnimePahe**, **AllManga**, and **AnimeDao** stay available (CF WebView for unlock only — not a site Web player). Each anime source has its own probe rule from Providers config (Miruro pipes and Megaplay sample media segments for PNG/ad poison; a master playlist alone is not enough). Megaplay and AllAnime / AllManga playback use their provider origin as Referer (not the CDN hostname) for probe and play — including cached / reloaded streams — so CDN renames do not break playback. Opening a stream walks an **open mind-tree**: classify the URL/body (PNG shell vs plain HLS vs progressive), pick one technique, and on open/decode failure **re-branch** (e.g. PNG→local strip proxy, then direct if strip fails; plain HLS→direct then strip). Decode confirm only watches for a frame — it does not reopen or force software decode (that stays with player recovery after a confirmed open). No per-CDN host allowlists. Only true image-only poison is skipped. There is no Megaplay / VidNest / Anikoto site WebView fallback — if native streams fail, you get **Try again** / **Close**. Anime hosts, path templates, KissKh mirrors, API bases, and per-source probe / PNG-strip profiles can be updated remotely (cloud `provider_runtime_config`) without an app update — offline builds keep the same built-in defaults
- **VidLink** needs a MyAnimeList id from MAL (relations map AniList→MAL, confirmed via Jikan) — `vidlink.pro/anime/{mal}/{ep}/sub|dub` — then sniffs the embed like movie/TV VidLink. Not AniList’s `idMal` field. Titles with no MAL mapping skip VidLink. On **Android TV**, VidLink is skipped (headless WebView blocked) unless the TV WebView extractor override is on
- **VidNest HiAnime** and **VidNest AnimePahe** resolve via `new.vidnest.fun` with the same AniList id as the card (no Anikoto id remap)
- AllAnime **Default** tries Yt-mp4 first (direct MP4), then S-mp4 / Luf-Mp4 when those clock links still work
- Playback shows a backdrop + title loading screen before the player opens (same pattern as films and Asian drama) — progress shows `N / M CHECKED · K UP`; next to **Cancel**, open the layers icon for the server list and tap a source to check it manually. If nothing works, the same screen explains it in plain language (**No streams found**) with **Try again** and **Close** (on **TV**, **Try again** autofocuses; **↓** → **Close**); a dead saved link offers **Search again**
- **Escape** / **Cancel** during resolve or before video starts returns to details — not the loading screen. Leaving the title or switching shell tabs mid-check also stops the server search (same stop as **Cancel**).
- Part of [content hub scrapers](../scrapers/content-hub-scrapers.md)

## Related

- [Anime Arabic](anime-arabic.md)
- [Playback settings](../settings/playback-settings.md)
- [Next episode](../playback/next-episode.md)
