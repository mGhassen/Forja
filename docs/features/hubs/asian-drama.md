# Asian Drama

> Asian dramas and shows via KissKH.

## What it is

Asian Drama aggregates KissKH content: hero browse, explore categories, search, subtitles on streams, continue watching, and a dedicated player for episodes.

## How to open it

Tap **Asian Drama** in the navigation bar.

## What you can do

- Browse hero and explore sections — the desktop hero shows title and a synopsis filled from TMDB when a title matches (KissKH list rows have no synopsis; KissKH `/Drama/{id}` hero enrich is disabled for now to save rate-limit budget)
- Search dramas — **desktop / TV:** same layout as the Search tab (large search field, trending title suggestions on the left, poster grid on the right; **Select** a suggestion to run that search; on desktop, hover a result card to reveal the info button — click it or double-click the card to open details); **mobile:** search bar + results grid — on **desktop**, **Cmd+F** / **Ctrl+F** opens this search page (or focuses the field when it is already open)
- Open details with episodes — tap an episode card to select it; click the card’s **play** button (or hero **Play** / **Resume**) to start that episode. On **TV**, **Play** / **Resume** is focused when the page opens; **↑** from hero actions closes details; **←** from the leftmost hero action moves focus to the shell nav rail; **↑** from the episode rail returns focus to **Play**
- Play with subtitle support where available
- While a stream resolves, Forja opens the single enabled KissKH host directly — it does not probe or fail over across mirrors. If an episode isn’t unlocked yet (Upcoming title or countdown widget), or resolve fails, the same cinematic loading screen explains what happened in plain language (**Not available yet**, **Taking a short break**, **Couldn’t find a stream**) with **Check again** / **Try again** and **Close**
- In the player, **Sources** lists only the enabled KissKH host
- Resume from continue watching — **same player launch as details → Resume** (saved episode list + seek position; no extra kisskh call); clear progress with the trash icon next to **Resume** on details
- Under **Settings → Playback → Server reliability → Asian Drama**, `kisskh.nl` is enabled and the other verified mirrors are shown **On hold**
- Hover a continue watching card (desktop) to scale it and show a brand-green play button that floats upward while its play icon pulses slowly

## Tips

- KissKH availability can vary by region and site status
- Watch history is stored per drama in this hub
- Forja currently uses only `kisskh.nl`. The compatible `.co`, `.ovh`, `.la`, and `.do` aliases are held disabled because automatic checks across them share the same client-IP rate limit
- Stream resolve opens a fresh (no HTTP cache) headless browser so KissKH can sign the stream key. If KissKH rate-limits your IP (“Too many request”), Forja cools down and asks you to wait — it does **not** reload the episode page or hop to another mirror (a second load made bans worse)
- Playback and subtitle requests send the `Referer`/`Origin` of the mirror that produced the stream (including cached URLs on `streamingcdn` hosts)
- **Escape** / **Cancel** during resolve or before video starts returns to details — not a stuck loading screen

## Related

- [Anime](anime.md)
- [Content hub scrapers](../scrapers/content-hub-scrapers.md)
