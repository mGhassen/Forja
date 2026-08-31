# Search

> **Archived:** Out of scope or not in the default navigation surface. See [Archive](../README.md).

> Find movies and series across TMDB and your VOD Stremio addons.

## What it is

Search combines TMDB results with installed Stremio addons that support search and target **Sources** (VOD). Live Matches catalogs (sport / `*live*` feeds) are not searched here — they stay on Live Matches. TMDB cards appear as soon as TMDB responds; addon sections fill in afterward. Cards show **FILM** or **TV** next to the year (same labels as Home).

On TMDB, Search also understands **structured queries**: a person name (`nolan`, `christopher nolan`), a genre (`horror`, `sci-fi`), a year (`2025`), a year range (`2020-2025`), a score (`>=8`, `>8 <9`, `8-9`), and type (`films` / `series`) — alone or combined (`>8 <9 2020-2025 films`). Those use TMDB discover under the hood and still show only movie/TV cards (not people).

Tap the **tune** icon beside the search field to open the **filter lens**: All/Films/Series segment, a score scrub (≥), and a year-range timeline. Active filters show as ghost tokens you can clear. Addon sections search the title/person text only (they skip score/year/type tokens; filters-only queries stay on TMDB).

## How to open it

From **Home**, tap top-bar **Search** or use **Cmd/Ctrl+F** — both open this overlay (TMDB structured search + Stremio addons). The Home hub pack declares `host_search` so those entry points stay the same. Anime / Asian Drama top-bar Search stays pack-only hub search. The Search nav tab is temporarily hidden from the shell and Settings → Features.

## What you can do

- Type a title, person, genre, year/range, score, or type (e.g. `dune 2021`, `nolan 2022-2025`, `horror 2025`, `>=8 films`, `>8 <9 2020-2025`)
- Open the **tune** filter lens for Films/Series, genre, country, minimum score, and year range without typing operators
- **Desktop / TV:** type in the search field on the left; on **desktop** (mouse or D-pad) the field is ready to type as soon as Search opens — no **Enter** / **OK** first. Your last 5 searches stay above up to 16 recommendations. Idle uses a varied catalog pool; while searching, recommendations refresh from the top match (similar titles, genre, year, language, director/creator, studio/network) and never list the same titles as the result cards. Result cards on the right mix **FILM** and **TV** in TMDB relevance order (not all movies first). Tap the **X** on a recent search to remove it. On **Android TV**, a search is saved to recent only when you press **OK** (not letter-by-letter while the keyboard is open). On desktop, click a card to open details (same as Home poster cards)
- **TV:** focus starts on the search field; **OK** opens typing; **OK** again on a filled field re-opens typing without re-running search (IME Search / Done still submits); **Down** moves to recent searches / recommendations (or into the **filter lens** controls when the tune panel is open — type → score → year → genre → country → Search); **Right** on a recent search focuses its delete **X**, **OK** removes it, **Left** returns to the title, **Right** from X (with results) goes to film cards; **Right** on the search field (with a query) focuses clear (X), **Left** returns to the field, **Down** from clear goes to film cards (or the filter lens when open); **Left** from the first card column returns to the aligned suggestion; **Left** from the search field stays on the field (does not jump to the nav); **Left** from suggestions returns to the nav rail
- **Mobile / narrow:** use the search bar at the top; results appear in horizontal rows by source (TMDB Movies and TMDB Shows are separate rows)
- Browse TMDB movie and TV results (shown first, before slower addons finish)
- See matching results from each VOD Stremio addon (combined list on desktop; separate sections on mobile)
- Tap any result to open details or addon-specific views

## Setup (if needed)

Install Stremio addons in **Settings → Providers & Addons** to unlock addon search sections. Addons marked **Live Matches** only (or live/sport catalogs) do not appear in Search.

## Tips

- Addon search depends on what each addon exposes — not all addons support search
- TMDB results open the standard movie/series details flow
- Genre names are matched as whole words (`horror`, `comedy`, `sci-fi`, …). Romance / Horror / Thriller also apply to Series (TMDB tags many shows with those genre ids)
- A year in the query filters TMDB title hits to that year (or range)
- Score filters use TMDB `vote_average` (not IMDb). Double-tap the score or year scrub to clear that filter
- **Android TV:** focus the score or year scrub first (browse only); **OK** to arm it, then **←/→** to move. On year, **↑/↓** switch start vs end thumb; **OK** again (or Back) to disarm. Desktop still drags

## Related

- [Stremio addons](../sources/stremio-addons.md)
- [Media details](../../movies-tv/tmdb-details.md)
- [Discover](discover.md)
