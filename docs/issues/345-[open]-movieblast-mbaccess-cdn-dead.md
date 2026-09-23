# 345 — MovieBlast Sources unplayable — dead `*.mbaccess.site` CDN

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/movieblast.js` · Sources Forja

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 3** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I345-T01 | Confirm catalog API still returns `videos[].link` hosts under `*.mbaccess.site` | ✅ |
| 2 | I345-T02 | Confirm CDN play hosts fail (TLS SAN mismatch + Fastly 421 / Domain Not Found) | ✅ |
| 3 | I345-T03 | Restore playable URLs once upstream publishes a live CDN base (or new link shape) | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I345-A01 | curl signed `https://*.mbaccess.site/…` returns playable media (not 421 / cert fail) | ⬜ |
| 2 | I345-A02 | Provider extract (or SPECS) uses the live CDN host / link format | ⬜ |
| 3 | I345-A03 | App: Sources → MovieBlast opens a playable stream for a catalog hit (manual) | ⬜ |

---

## Summary

MovieBlast catalog still answers on `app.cloud-mb.xyz` / `mb.cloud-mb.xyz` (`/api/search/…`, `/api/media/detail/…`). Detail `videos[].link` values are host-relative paths on `move*.mbaccess.site` / `link*.mbaccess.site` / `linkserie.mbaccess.site`.

Those CDN names resolve through Fastly but are not configured: HTTPS cert is `x.sni-498-default.ssl.fastly.net` (hostname mismatch), and requests return **421 Misdirected Request** / HTTP **500 Domain Not Found**. Signing (`?verify=ts-sig` with the pack HMAC secret) cannot help — the edge has no domain.

Forja extract can still emit Sources rows (probe is `AnimeProbeMode.skip` for MovieBlast). Playback fails because the CDN is dead upstream. APK v2.6 still points API at `https://mb.cloud-mb.xyz/api/` and the same `mbaccess` link hosts.

**Blocked on upstream** until MovieBlast ships a live CDN host or a different play URL shape in detail JSON.

---

## Related

- [RFC-060](../rfc/fixed/060-[fixed]-enginejs-sources-forja-tab.md)
- Changelog 1.4.128 MovieBlast title/probe fixes (extract path; not this CDN outage)
