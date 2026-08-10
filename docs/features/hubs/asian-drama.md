# Asian Drama

> Asian dramas and shows via KissKH.

## What it is

Asian Drama aggregates KissKH content: hero browse, explore categories, search, subtitles on streams, continue watching, and a dedicated player for episodes.

## How to open it

Tap **Asian Drama** in the navigation bar.

## What you can do

- Browse hero and explore sections — hub and explore cards use **wide 16:9** frames because KissKH list thumbs are landscape banners (not portrait posters). The desktop/TV hero shows title and a synopsis filled from TMDB when a title matches (KissKH list rows have no synopsis; KissKH `/Drama/{id}` hero enrich is disabled for now to save rate-limit budget). On desktop/mobile the hub hero uses **Ken Burns** pan/zoom (static stills on Android TV)
- Search dramas — **desktop / TV:** same layout as the Search tab (large search field; last 5 searches then up to 16 varied recommendations on the left — tap **X** on a recent to remove it; **TV:** Right focuses that X; recommendations update from the top hit via TMDB match (similar / genre / year / studio — not result card titles); poster grid on the right; **Select** a suggestion to run that search; on desktop, click a result card to open details); **mobile:** search bar + results grid — on **desktop**, **Cmd+F** / **Ctrl+F** opens this search page (or focuses the field when it is already open)
- Open details with episodes — on wide screens the hero shows the same production facts card as movies/TV (no heading). When TMDB finds a confident match for the KissKH title, details also show **genres**, **rating**, richer facts (director / network / language / studio), **Characters**, **Crew**, **Trailers**, and **More Like This** (taps open the normal TMDB movie/TV details page). The hero **rotates random TMDB backdrops** when several exist (Ken Burns on desktop/mobile; static stills on Android TV); episode cards use TMDB stills and titles when season data matches. Playback stays on KissKH. Tap an episode card to select it; click the card’s **play** button (or hero **Play** / **Resume**) to start that episode. On **TV**, **Play** / **Resume** is focused when the page opens; **↑** from hero actions closes details; **←** from the leftmost hero action moves focus to the shell nav rail; **↑** from the episode rail returns focus to **Play**; **↓** from episodes reaches Characters / More Like This when TMDB matched
- Play with subtitle support where available
- While a stream resolves, Forja opens the single enabled KissKH host directly — it does not probe or fail over across mirrors. If an episode isn’t unlocked yet (Upcoming title or countdown widget), or resolve fails, the same cinematic loading screen explains what happened in plain language (**Not available yet**, **Taking a short break**, **Couldn’t find a stream**) with **Check again** / **Try again** and **Close**
- In the player, **Sources** lists only the enabled KissKH host
- Resume from continue watching — **same player launch as details → Resume** (saved episode list + seek position; no extra kisskh call); clear progress with the trash icon next to **Resume** on details. On **TV**, D-pad order matches the page: **↓** from hero **Play** → **Latest Update** → **Continue Watching** → catalog rails; **↑** from Continue Watching lands on Latest (then Play); empty Continue Watching leaves the D-pad graph; close/info chips on the card are mouse-only
- Mark episodes watched / unwatched on details — auto at **≥85%** playback, or right-click (secondary tap) an episode card; local only (not Trakt / Simkl). Cleared with **Settings → Cache & data → Watched episode marks**. Details hero shows series progress (`N of T · %` or **Completed**)
- Under **Settings → Sources → Server reliability → Asian Drama**, `kisskh.nl` is enabled and the other verified mirrors are shown **On hold**
- Hover a continue watching card (desktop) to scale it and show a play button; hover the play button to turn it brand-green, float it upward, and pulse the icon

## Tips

- On **desktop**, drag-select hub and details hero titles to copy them
- KissKH availability can vary by region and site status
- Many KissKH posters are hosted on TMDB’s image CDN (`media.themoviedb.org` / `image.tmdb.org`). On **Android 7.0**, Forja embeds Let's Encrypt roots so those covers load (same path as Home posters)
- Watch history is stored per drama in this hub
- Forja currently uses only `kisskh.nl`. The compatible `.co`, `.ovh`, `.la`, and `.do` aliases are held disabled because automatic checks across them share the same client-IP rate limit
- Stream resolve signs KissKH’s stream key in the app engine and fetches the episode URL directly (same path a normal browser uses — usually about a second). A hidden browser page is only used if that path fails. If KissKH rate-limits your IP (“Too many request”), Forja cools down and asks you to wait — it does **not** hop to another mirror (aliases share the same ban)
- Playback and subtitle requests send the KissKh mirror `Referer`/`Origin` by provider identity (not the CDN hostname), including cached URLs on `streamingcdn` / `cdnvideo` hosts
- **Escape** / **Cancel** during resolve or before video starts returns to details — not a stuck loading screen. Leaving the title or switching shell tabs mid-check also stops the extract (same stop as **Cancel**).

## Related

- [Anime](anime.md)
- [Content hub scrapers](../scrapers/content-hub-scrapers.md)
