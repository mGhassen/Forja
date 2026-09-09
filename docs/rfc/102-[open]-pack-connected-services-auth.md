# RFC-102: Pack-declared Connected Services auth

**Status:** open  
**Depends on:** [RFC-089](fixed/089-[fixed]-pack-addon-settings.md), [RFC-101](101-[open]-shahid-hub-provider-exo-widevine.md)  
**Area:** Settings → Connected services, pack manifests, `MetaRuntime` auth actions

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **7 / 8** acceptance (1 ⏭️ pin) |
| **Current slice** | Form session auth shipped; PIN flow deferred |

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
| `auth_begin` | `{ flow: "form", methods: [...] }` or `{ flow: "pin", … }` |
| `auth_login` | params: method + field values → `{ connected, label?, secrets?, config? }` |
| `auth_logout` | clear pack-side state; host clears Keychain |

Host never branches on pack id. Shahid (and future packs) own login methods (email, phone OTP, …) inside `auth_begin` / `auth_login`.

### Related

- [RFC-101](101-[open]-shahid-hub-provider-exo-widevine.md) — DRM + earlier Account fields (login UX moved here)
- [RFC-089](fixed/089-[fixed]-pack-addon-settings.md) — pack Addon fields
