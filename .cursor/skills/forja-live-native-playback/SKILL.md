---
name: forja-live-native-playback
description: >-
  Forja Live / Live Sports — native playback only (no embed WebView) and catalog
  schedule-only (no streams on catalog rows). Use when editing livesports packs,
  live resolve/unlock, catalog schedule, Providers panel, embed-st unlock, or when
  the user mentions dead stream, webviewOnly, embedUrl, catalog streams, or
  Forja Live playback.
---

# Forja Live — native playback + catalog schedule-only

Always-on stubs: [no-embed-playback.mdc](../../rules/no-embed-playback.mdc) · [live-catalog-schedule-only.mdc](../../rules/live-catalog-schedule-only.mdc)

Index: [feature scope](../../rules/forja-feature-scope.mdc) · [no-hide-as-fix](../../rules/no-hide-as-fix.mdc) · [issue 254](../../../docs/issues/fixed/254-[fixed]-live-catalog-schedule-only-no-streams.md)

---

## No embedded playback

**Embedded / WebView playback is prohibited** for Forja Live and live-sports resolve paths.
Users must get **native player** (Exo / MediaKit) with a real play URL, or **nothing**.

### Forbidden

| Layer | Do not |
|-------|--------|
| **Live plugins** (`plugins/live/**`, `forja-packs/livesports/**`) | Return `webviewOnly: true`, `embedUrl`-only rows, or iframe/catalog pages as “streams” |
| **Live plugins** | Fall back to “open in web player” when GOAT/GASM/sports-embed unlock fails |
| **Host** | Open embed WebView players for **Forja Live** / Live Sports |
| **Host** | Show embed/catalog URLs in the Sources panel when there is no resolved `url` (m3u8/mp4) |
| **Host** | Add new `webviewOnly` handling or extend embed fallback for Forja Live plugins |
| **Changelog / docs** | Describe embed/WebView fallback as a fix or feature for Forja Live |

**Wrong:** `return { webviewOnly: true, embedUrl: raw }` when unlock fails.  
**Wrong:** Engine resolve miss → `embed WebView player` for Streamic / TimStreams / WatchFooty.  
**Right:** Unlock to `{ url, headers?, directPlayback? }` via `embed-st.js` helpers, or **skip** the row (`return null` / omit from list).

### Required contract (live plugins)

On `action: 'resolve'`, each stream row must be **playable natively**:

```json
{ "url": "https://…/index.m3u8", "headers": { "Referer": "…" }, "directPlayback": true }
```

- Unlock embed.st / embedindia / sportsembed with shared `embed-st.js` helpers — not a WebView.
- If unlock fails → **omit** the stream; do not surface the embed page.
- Direct `.m3u8` / `.mp4` URLs are allowed with correct Referer/Origin headers.

### Host playback (Forja Live)

1. Resolve → native `IptvPlaySource` / engine player only.
2. Resolve miss → toast **“no playable stream”** (`LiveMatchesEngine.engineResolveFailed`) — **never** embed fallback.
3. Filter `webviewOnly` rows out of `_rowsFromForjaLiveResolve` and similar list builders.

Legacy embed WebView code may remain for **non–Forja Live** paths — **do not extend** it to Forja Live or new live plugins.

### When asked to “fix” a dead stream

1. **Improve unlock** (GOAT/GASM, headers, mirror priority, new resolver in `embed-st.js`).
2. **Skip** mirrors that cannot unlock — user sees fewer sources, not an embed player.
3. **Ask** before shipping any embed/WebView path, even as a temporary workaround ([honesty](../../rules/honesty-and-completion.mdc)).

Removing a broken embed row is **not** hiding a feature ([no-hide-as-fix](../../rules/no-hide-as-fix.mdc)) — embed was never allowed for Forja Live.

---

## Catalog schedule-only

**Catalog packs** publish the **match schedule** only.  
**Live packs** **discover streams and unlock** playback.

### Forbidden in catalog packs

| Do not | Why |
|--------|-----|
| Emit `streams[]`, `streamCount`, row `iframe`, `embedUrl` | That is stream discovery |
| Map upstream `ev.streams` / embeds into schedule rows | Belongs in live `resolve` |
| Implement `action: 'resolve'` / unlock / goat / gasm | Catalog extract is `catalog` only |
| Surface broadcast/TV-guide packs as Providers sources | No `providerId` → not a stream feed |

**Allowed on catalog rows:** `id`, title, time, category, teams, posters, airing/viewers, opaque `sources: [{ source, id }]` (resolve handoff keys only — **no** `iframe`/`url`), `sportMatchGame.broadcastChannels` for Live TV matching.

### Forbidden in host Providers / schedule ingest

| Do not | Why |
|--------|-----|
| Promote catalog `streams[]` or `sources[].iframe` into Providers | Catalog is not a resolver |
| Soft-match broadcast-only catalogs into stream rows | Guides ≠ streams |
| Require a catalog iframe before calling live `resolve` | Live packs take `matchId` / `eventId` |
| Invent `pending:` / preparing Providers rows when upstream has 0 links | Catalog shows the fixture; Providers only lists real discovered mirrors |

**Right:** soft-match `providerId` catalogs → live discover. Empty discover → no Providers row. Unlock on play for listed embeds.

### Wrong / right

```
❌ catalog row: { streams: [{ embedUrl }], iframe: 'https://embed…' }
❌ Providers paints Live Soccer TV as a stream source
❌ Providers invents pending WatchFooty row while site Stream links (0)
✅ catalog row: { sources: [{ source: 'ppv', id: '123' }] }
✅ Providers lists only when live discover returns real mirrors; unlock on play
```
