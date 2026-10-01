# 274 — Debug and release Forja share session / local data

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Auth · macOS · Android · iOS · Linux · local storage

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4/4** tasks · **0 / 1** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I274-T01 | macOS Debug/Profile → `com.forjahq.app.dev` + display name Forja Dev | ✅ |
| 2 | I274-T02 | iOS Debug/Profile → `com.forjahq.app.dev` + display name Forja Dev | ✅ |
| 3 | I274-T03 | Android debug `applicationIdSuffix=.dev` + Forja Dev label | ✅ |
| 4 | I274-T04 | Linux non-Release `APPLICATION_ID=com.forjahq.app.dev` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I274-A01 | Released Forja + `flutter run -d macos` can sign in/out independently (prefs under separate bundle ids) | ⬜ |

---

## Summary

Debug and shipped builds both used `com.forjahq.app`, so SharedPreferences / secure vault / Application Support (and Android app data) were one namespace. Signing out of `flutter run` cleared the released app session.

**Root fix:** Debug/Profile (and Android debug) use `com.forjahq.app.dev` and show as **Forja Dev**. Release stays `com.forjahq.app`.

**Note:** Both still register the `forja://` URL scheme — Launch Services may route deep links to either app. Session isolation does not depend on that.
