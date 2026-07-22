# Media details

> Full movie and series page — metadata, torrents, streams, episodes, and lists.

## What it is

When you open a title from Home, Discover, Search, or lists, you get the **media details** screen — one screen for torrents, Stremio/Nuvio, and webstreaming. A **cinematic hero** (~82% of the viewport) shows Ken Burns backdrop animation, then a chromeless YouTube trailer after a random **12–20 seconds** (preloaded for a smooth crossfade). After each trailer finishes, the backdrop returns for another random 12–20 seconds, then the trailer plays again. Trailer audio is on by default and fades from quiet to full volume over 3 seconds. A **mute** button in the bottom-right of the hero toggles sound.

On **TV series**, the backdrop continues below the hero chrome so season and episode rails sit on the image — not on a separate black block. The episode rail reserves ~500px of backdrop under the chrome; hero chrome is a bit taller than a single viewport so seasons/episodes sit slightly lower. Synopsis stays as **3 lines + Read More** (same as movies); secondary chrome (director, providers, genres) yields first when space is tight. **Play** / **Resume** stay visible.

The hero overlay is split into two columns on wide screens:

- **Top-left back chevron** — muted until hover or D-pad focus (then white); tap / click / TV **OK** pops the shell overlay back to the previous screen. From the leftmost hero action (**Play** / **Resume**), **↑** focuses the back chevron and **←** moves focus to the shell nav rail (same as Home hero); **→** on the active nav tab returns focus to the details page.
- **Left:** TMDB logo or stylized title, inline genres (`Horror • Thriller`), year · runtime · certification · rating, director line, synopsis (left **40%** of the screen), then green **Play** / **Resume** with play icon (webstreaming best extractor when enabled), white **Play** / **Resume** with link icon (opens the **Sources** panel for torrent / Stremio), a trash icon next to Resume when you have watch progress (clears that title/episode from history **and** the cached webstreaming provider extract so Play re-resolves), **Trailer** (when TMDB has videos — opens the in-app trailer player on the best match), and a combined **+ | download | ⋯** pill for My List, download (opens **Sources**), and overflow; watch progress when you have history appears below the actions.
- **Right:** production facts panel (no heading) — status, language, and TV fields (first/last aired, seasons, episodes, network, production companies, origin, creators) or movie fields (release date, runtime, production, origin, budget/revenue) from TMDB rich details.

Hero text sits in the **upper** area of the hero (not pinned to the bottom). Cast, trailers, and recommendations scroll on the flat shell background (`#141414`), with equal vertical spacing between the episode rail and each body section.

Scroll below the hero for:

1. **Episodes** (TV only) — on the **extended page backdrop** under the hero chrome: horizontal season poster cards (when the show has more than one season), then a horizontal episode rail (skeleton cards while a season is loading); season cards show a highlighted border on hover (desktop) or D-pad focus (TV), and the selected season keeps the same border; **selecting a season updates the hero backdrop** to that season's poster (falls back to the show backdrop when no season art exists); when a season has more than 50 episodes, a range dropdown (**1 - 50**, **51 - 100**, …) sits on the **Episodes** title row (opposite the title). Each episode card shows its air date when TMDB provides one; upcoming (not yet aired) dates appear in **orange** and cannot be opened. Tap a card to select an episode; click its play button to play or resume. On **Android TV**, **OK** on an episode selects it and moves focus to the play icon; **OK** on the play icon starts or resumes webstreaming. Opening a show without a Continue Watching deep link selects season 1 unless you have an in-progress episode (2–90% watched), in which case that season and episode are selected.
2. **Cast** — circular photos, actor and character names
3. **Trailers** — horizontal row of YouTube trailers/teasers from TMDB; tap to open the in-app trailer player (fullscreen over the shell — nav rail hidden; seek bar, ±10s skip, horizontal volume bar, audio, subtitles, quality, playback speed, fullscreen on desktop). Desktop chrome auto-hides after idle like the main player (move/click to bring it back); double-click the video toggles fullscreen. When a title has more than one trailer, a bottom-right **More videos** card (label + next-trailer thumbnail) sits above the progress bar and opens the trailers list. On **Android TV**, D-pad moves focus between chrome controls (back, More videos, progress bar, play, skip, mute, audio, subtitles, quality, speed); on the progress bar **OK** arms the thumb, **←/→** nudge, **OK** commits; **↑** from the bar focuses More videos when shown, otherwise Back. Audio, subtitles, quality, and speed menus use the same option chips as the main player (language flags on audio/subs; tap applies immediately; quality hides **Auto** while Auto is active and highlights the level currently playing). **Back** (remote or the top-left back control) closes an open menu first; a second **Back** exits the player to the details page.
4. **More Like This** — recommendation row

Torrent search, Stremio, and Nuvio streams share one **Sources** list in a frosted right-side panel (BackdropFilter glass over the details page). They load **only when you open Sources** (white Play / Resume with link icon, or Download) — not when the details page first opens, and not when you only select an episode. Each kind appears only when its **Play source** is on in Settings (**Direct torrent**, **Stremio**, **Nuvio**). The panel opens on **Torrents** when Direct torrent is enabled, otherwise **Nuvio**, then **Stremio** — there is no **All** kind. Switching kind loads that category if it is not already cached; leaving a kind while it is still loading **stops** that fetch so it cannot finish in the background. Results stay cached for about **30 minutes** for the same title/episode, so closing and reopening Sources does not re-search. Closing the panel (or tapping **Cancel**) **stops** any still-running Torrents / Stremio / Nuvio checks so they do not keep loading in the background. The **selected** category tab shows a **reload** icon (spins on hover; mouse-only on **TV**) to force a fresh fetch for that open category only. On **TV**, **Torrents / Stremio / Nuvio** tabs are D-pad focusable; while a fetch runs, **Cancel** autofocuses. Opening or reloading **Stremio** re-reads installed stream addons for the plugin chip row. Search and Filters stay in the chrome even when the list is still empty. Leaving the details page also cancels in-flight checks. The panel chrome is compact: **Sources** + matching count, then **Torrents / Stremio / Nuvio** tabs when enabled, then a horizontal **provider chip** row (Forja / Jackett / Prowlarr, Stremio addons, or Nuvio scrapers), then search + **Filters**. Torrents and Stremio show every row returned by their fetch. Nuvio runs one selected scraper when opened; **Load next provider** runs one additional selected scraper and appends that scraper's complete response. **Nuvio** appears when **Direct torrent** is enabled (same play source as Forja search) — not under Stremio or webstreaming. **Filters** opens as a second full-height frosted panel docked to the left of Sources (same top/bottom edge) only when you tap the tune control — not automatically with Sources, and not as a bottom sheet. Filters only covers the area left of Sources, so Torrents / Stremio / Nuvio rows stay clickable. You can close Filters with the tune control or its close button; closing Sources also dismisses Filters. Sources stays usable while Filters is open. In the player, Sources and Filters use a translucent dark shell (no freeze-frame image; no BackdropFilter over live video). Each torrent/Stremio/Nuvio row uses the same card: **title** on the left with **provider** and seed count (↑ number, no badge) stacked on the right, then a meta row with language **flags** as plain emoji (no pill) plus badges for **quality**, **file size** (scraper / Torrentio `behaviorHints.videoSize` / size token in stream title), codec, and tech tags when known. **Webstreaming** is started from the hero green **Play** / **Resume** (play icon) — it is not in Sources. Only play sources enabled in **Settings → Playback** appear in the panel (Direct torrent → Forja + Nuvio; Stremio → addon streams).

## How to open it

Tap any movie or series poster from Home, Discover, Search, or lists.

## What you can do

- Watch the Ken Burns backdrop (12–20s), then chromeless autoplay trailer in the hero when TMDB has one; alternates after each trailer ends (sound on, volume ramps up; mute toggle bottom-right)
- Green **Play** / **Resume** (play icon) auto-extracts the best direct webstreaming link when that play source is enabled
- If Play can’t start a stream, the cinematic loading screen stays up with a plain-language error (**Couldn’t start playback**) and **Try again** / **Close** — not a toast that vanishes. On **TV**, **Try again** is focused; **↓** reaches **Close**; **OK** activates
- **Cancel**, **Escape**, leaving the title, or switching to another shell tab (e.g. IPTV) while servers are still checking **stops** the search — Forja does not keep probing the next embed in the background
- Returning to the same title/episode reuses a cached **webstreaming** extract when still reachable (see [Webstreaming](direct-streaming-mode.md)) — not Stremio Direct or torrent
- White **Play** / **Resume** (link icon) opens **Sources** so you pick a torrent/Stremio stream
- **Download** opens **Sources** to pick a torrent/Stremio stream manually
- **Trailer** (when available) opens the in-app trailer player on the best-matching official trailer
- Add or remove from **My List** (**+** button in hero)
- Trakt/Simkl/collect actions via the **⋯** overflow menu in the hero
- See resume progress in the hero for movies and the selected TV episode
- Clear resume progress with the trash icon next to **Resume** (removes that movie or selected episode from continue watching, and drops the cached stream provider for that title/episode so the next Play re-extracts)
- For TV: pick a season from the horizontal poster row (multi-season shows) — the hero backdrop crossfades to that season's poster; then tap an episode card to **select** it (does not start playback or open Sources). Click the card's **play** button to play or resume that episode (webstreaming when enabled, otherwise opens **Sources**). Hero green **Play** / **Resume** and white **Play** / **Resume** (link icon) / **Download** still apply to the **selected** episode. Without Continue Watching, the page opens season 1 unless you have an in-progress episode (2–90%), then that season is selected.
- Browse main cast and “More Like This” recommendations below the hero
- Search and sort torrent results in Sources (seeders, size, etc.)
- Pick a provider from the chip row under the Torrents / Stremio / Nuvio tabs; filter by quality, size (`<1 GB` · `1–3 GB` · `3–8 GB` · `8–20 GB` · `20 GB+`, multi-select OR), language, tech, and audio; under Nuvio, tap **All** for every scraper or tap a scraper chip (tap again to deselect and clear its rows); selection is remembered on this device; more chips load lazily one at a time
- Resolve torrents through debrid when configured
- Mark watched / unwatched per episode
- Use [Webstreaming](direct-streaming-mode.md) via the hero green **Play** / **Resume** (play icon) button

## Setup (if needed)

- [Torrent scrapers](../scrapers/torrent.md), [Jackett](../scrapers/jackett.md), [Prowlarr](../scrapers/prowlarr.md) for more torrent results
- [Debrid](../sources/debrid.md) for instant cached playback
- [Stremio addons](../sources/stremio-addons.md) for addon streams
- [Stream providers](../sources/stream-providers.md) — webstreaming extractor order

## Tips

- On **desktop**, drag-select the stylized hero title to copy it (TMDB logo titles are images, not text)
- Sort order for torrents is set in Settings → Sources
- Enable only **Webstreaming** under Play sources if you want a single green **Play** / **Resume** without torrent/Stremio **Sources**

## Related

- [Webstreaming](direct-streaming-mode.md)
- [Playback settings](../settings/playback-settings.md)
- [Torrent playback](../playback/torrent-playback.md)
- [Watch history](watch-history.md)
- [My List](my-list.md)
