# Asian Drama

> Asian dramas and shows via KissKH.

## What it is

Asian Drama aggregates KissKH content: hero browse, explore categories, search, subtitles on streams, continue watching, and a dedicated player for episodes.

## How to open it

Tap **Asian Drama** in the navigation bar.

## What you can do

- Browse hero and explore sections — the desktop hero shows title, year/type badge, and synopsis (filled after KissKH details enrich)
- Search dramas — **desktop / TV:** same layout as the Search tab (large search field, trending title suggestions on the left, poster grid on the right; **Select** a suggestion to run that search; on desktop, hover a result card to reveal the info button — click it or double-click the card to open details); **mobile:** search bar + results grid — on **desktop**, **Cmd+F** / **Ctrl+F** opens this search page (or focuses the field when it is already open)
- Open details with episodes — on **TV**, **Play** / **Resume** is focused when the page opens; **↑** from hero actions closes details; **←** from the leftmost hero action moves focus to the shell nav rail; **↑** from the episode rail returns focus to **Play**
- Play with subtitle support where available
- While a stream resolves, the loading screen first checks each KissKH mirror URL in parallel (dead / timed-out hosts show DOWN within a few seconds), then opens a browser only for healthy mirrors. Tap a mirror to check it next. If kisskh marks the title **Upcoming** (countdown on the site, not published yet), Forja skips extract and explains that on the same screen — with the expected release date when kisskh provides one
- In the player, **Sources** lists the same mirrors so you can switch hosts without leaving playback
- Resume from continue watching — **same player launch as details → Resume** (saved episode list + seek position; no extra kisskh call); clear progress with the trash icon next to **Resume** on details
- Reorder KissKH mirrors under **Settings → Playback → Server reliability → Asian Drama**
- Hover a continue watching card (desktop) to scale it and show a brand-green play button

## Tips

- KissKH availability can vary by region and site status
- Watch history is stored per drama in this hub
- Forja checks the API-compatible KissKH mirrors (`.co`, `.nl`, `.ovh`, `.la`, `.do`) and keeps the first working one; unrelated sites using the KissKH name are not used
- Stream resolve probes mirror APIs in parallel with a short deadline first (so one hung host cannot block the rest), then tries healthy hosts in your Settings order with a fresh (no HTTP cache) headless browser so KissKH can sign the stream key
- Playback and subtitle requests send the `Referer`/`Origin` of the mirror that produced the stream (including cached URLs on `streamingcdn` hosts)
- **Escape** / **Cancel** during resolve or before video starts returns to details — not a stuck loading screen

## Related

- [Anime](anime.md)
- [Content hub scrapers](../scrapers/content-hub-scrapers.md)
