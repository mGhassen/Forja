# RFC-102: Pack-declared Connected Services auth

**Status:** open  
**Depends on:** [RFC-089](fixed/089-[fixed]-pack-addon-settings.md), [RFC-101](101-[open]-shahid-hub-provider-exo-widevine.md)  
**Area:** Settings → Connected services, pack manifests, `MetaRuntime` auth actions

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **8 / 10** acceptance (1 ⏭️ pin · 1 ⬜ pairing SSO) |
| **Current slice** | Browser flow opens system browser; auto session import / pairing still open |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R102-C01 | `PackConnectedAuthSpec` from `settings.auth` + `addon: connected_services` | ✅ |
| 2 | R102-C02 | Generic Connected Services panel (status / Login / Logout) — no pack id branches | ✅ |
| 3 | R102-C03 | Pack actions `auth_status` / `auth_begin` / `auth_login` / `auth_logout` + Keychain session | ✅ |
| 4 | R102-C04 | Shahid hub migrates off permanent email/password settings fields | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R102-A01 | Manifest `settings.auth` parses without requiring `fields[]` | ✅ |
| 2 | R102-A02 | Enabled pack with `addon: connected_services` + `auth` shows under Connected services | ✅ |
| 3 | R102-A03 | Host Login/Logout/status uses only pluginId + pack actions (no `shahid` switch) | ✅ |
| 4 | R102-A04 | Session secrets in Keychain; merge into extract config via `extractPluginIds` | ✅ |
| 5 | R102-A05 | Shahid pack: Connected Services login; remove Account email/password fields | ✅ |
| 6 | R102-A06 | Host unit tests use synthetic plugin fixtures only | ✅ |
| 7 | R102-A07 | Feature docs + changelog | ✅ |
| 8 | R102-A08 | `auth_begin` pin flow (Simkl-shaped) for packs that return it | ⏭️ |

---

## Acceptance (slice — browser session import)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R102-A09 | Host handles `auth_begin` `flow: "browser"` — open pack URL in **system browser** (no in-app WebView) | ✅ |
| 2 | R102-A10 | Shahid Google SSO → auto-import session without password (device pairing / handoff) | ⬜ |

---

## Summary

Simkl stays a built-in host panel. Packs that need account sessions declare auth under **Settings → Connected services** without hardcoding the pack in the Flutter root.

### Manifest

```json
"settings": {
  "addon": "connected_services",
  "group": "Shahid",
  "order": 20,
  "extractPluginIds": ["shahid"],
  "auth": {
    "kind": "session",
    "label": "Shahid",
    "subtitle": "Sign in to play premium titles"
  }
}
```

### Pack actions (kit)

| Action | Role |
|--------|------|
| `auth_status` | `{ connected, label? }` |
| `auth_begin` | `{ flow: "form", methods: [...] }` or `{ flow: "browser", url, capture }` or `{ flow: "pin", … }` |
| `auth_login` | params: method + field values → `{ connected, label?, secrets?, config? }` |
| `auth_logout` | clear pack-side state; host clears Keychain |

Host never branches on pack id. Shahid (and future packs) own login methods (browser SSO, email, phone OTP, …) inside `auth_begin` / `auth_login`.

**Browser flow:** pack returns `flow: "browser"` + `url` (+ optional form `methods`). Host opens the URL with the **system browser**. Auto-import from that browser (cookie/session handoff) is R102-A10 / device pairing — not WebView scraping.

### Related

- [RFC-101](101-[open]-shahid-hub-provider-exo-widevine.md) — DRM + earlier Account fields (login UX moved here)
- [RFC-089](fixed/089-[fixed]-pack-addon-settings.md) — pack Addon fields
