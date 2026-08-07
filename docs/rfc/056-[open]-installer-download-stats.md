# RFC-056: Installer download stats (admin)

**Status:** open  
**Depends on:** [RFC-015](015-[partial]-in-app-updates.md) (R2 installers)  
**Area:** admin — Cloudflare Analytics → R2 JSON rollup (no Supabase)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** components · **4 / 5** acceptance |
| **Current slice** | Daily Inngest → `stats/downloads.json` · admin reads rollup |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R56-C01 | CF GraphQL GetObject × objectName → day slice | ✅ |
| 2 | R56-C02 | Inngest daily + backfill write `stats/downloads.json` on R2 | ✅ |
| 3 | R56-C03 | Admin `/downloads` reads lifetime rollup from R2 | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R56-A01 | Admin shows lifetime totals + per-platform from JSON | ✅ |
| 2 | R56-A02 | Cron merges yesterday (idempotent replace per day) | ✅ |
| 3 | R56-A03 | Host env: R2 S3 keys + `CLOUDFLARE_API_TOKEN` (Analytics Read) | ⬜ |
| 4 | R56-A04 | Non-installer keys excluded | ✅ |
| 5 | R56-A05 | One-shot backfill last ≤30 CF days into the JSON | ✅ |

---

## Summary

```
CF Analytics (~31d) → Inngest daily → R2 stats/downloads.json (forever)
Admin UI ← read that JSON (S3 GET)
```

### File shape (`stats/downloads.json`)

```json
{
  "schema": 1,
  "updated_at": "…",
  "bucket": "forja-releases",
  "days": {
    "2026-08-06": {
      "by_platform": { "windows": 12, "macos": 4 },
      "by_object": { "latest/Forja-….exe": 12 }
    }
  },
  "totals": { "total": 16, "by_platform": {…}, "by_object": {…} }
}
```

### Env

- `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, optional `R2_BUCKET`
- `CLOUDFLARE_API_TOKEN` — Account Analytics Read

### Out of scope

- Supabase download tables
- Web click beacons
