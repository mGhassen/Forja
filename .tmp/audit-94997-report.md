# Engine-js audit — TMDB 94997 (HOTD) S1E1

Harness: `./scripts/audit-engine-plugins.sh` · `allow_host_fallback: false` (matches Sources panel).

Bucket `ctx_host` = plugin called `ctx.host()` with zero streams — **not** sniffing; Sources ignores it.

## Partial re-audit (hexa / flixcloud / vidcore / 2embed / multiembed — vidrock untouched)

| id | n | bucket | note |
|----|--:|--------|------|
| hexa | 4 | ok | enc-dec crypto path |
| flixcloud | 0 | provider_empty | hop/embed URL required (no TMDB page) |
| vidcore | 0 | provider_empty | crypto chain runs; no playable URLs for this title |
| 2embed / multiembed | 0 | provider_empty | embed servers empty for fixture |

## Plugin changes

- Removed `ctx.host()` from hexa, flixcloud, vidcore, multiembed (2embed shares multiembed.js).
- Vidrock **not modified**.
