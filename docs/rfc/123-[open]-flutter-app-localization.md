# RFC-123: Flutter app localization (English + French)

**Status:** open  
**Depends on:** —  
**Area:** `apps/forja/lib/l10n/`, `apps/forja/lib/shared/services/app/app_locale.dart`, `apps/forja/lib/features/settings/`, `packages/rust/lib/src/settings_service.dart`  
**Related:** [RFC-037](037-[open]-web-portal-i18n.md) (web portal; `R37-A09` defers the Flutter app to this RFC)

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 9** components · **4 / 6** acceptance |
| **Current slice** | Tooling, language setting and picker are in. About 1,400 messages cover Settings, the shell, player, details, account and download screens; the welcome screen, Settings and Home were run in a Linux debug build. TMDB titles, overviews, genres and posters follow the app language after a restart. Hub text written by packs follows the app language too (checked on Home). Manifest labels, option lists whose text is also a stored value and text from services with no BuildContext are still English. Remaining Settings pages, shell, player, details, packs and TMDB metadata language are not started. |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R123-C01 | `gen_l10n` tooling: `l10n.yaml`, ARB catalogs `en` (template) and `fr`, generated Dart committed, `flutter_localizations` + `intl` | ✅ |
| 2 | R123-C02 | `AppLocale`: saved choice (`system` / `en` / `fr`), loaded at boot, drives `MaterialApp.locale` | ✅ |
| 3 | R123-C03 | Language picker in Settings → Profile & account | ✅ |
| 4 | R123-C04 | Settings hub (category titles, subtitles, screen title) reads from the catalogs | ✅ |
| 5 | R123-C05 | Catalog guard tests: key parity, placeholder parity, generated Dart not stale | ✅ |
| 6 | R123-C06 | Remaining Settings pages (Addons, Packs, Features, Downloads, Data, About, Profile panel) | 🔄 |
| 7 | R123-C07 | Shell, player, details, account and download host strings | 🔄 |
| 8 | R123-C08 | Pack contract: host passes the app locale to packs (`config.uiLocale`); hub scripts translate their own text through a `HUB_I18N` table in each kit (done); manifest labels (the rail's "Home", setting names) need host support (not started) | 🔄 |
| 9 | R123-C09 | TMDB metadata language and image languages follow the app language: Dart client and the home, anime, IPTV and Asian drama hubs. Home checked in the app; the other hubs by script only | 🔄 |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R123-A01 | Device set to French → Settings opens in French with **System default** (Linux) | ✅ |
| 2 | R123-A02 | Switching language in Settings updates the visible screens without a restart (Linux) | ✅ |
| 3 | R123-A03 | The choice is still applied after restarting the app (Linux) | ✅ |
| 4 | R123-A04 | iOS and macOS resolve a French device language (`CFBundleLocalizations`) | ⬜ |
| 5 | R123-A05 | Titles, overviews and posters follow the app language (Linux, Home hub, after a restart) | ✅ |
| 6 | R123-A06 | Every user-facing string in the in-scope tabs comes from a catalog | ⬜ |

---

## Summary

The Flutter app has no localization today: strings are inline literals, and `MaterialApp` sets no locale, delegates or supported locales. This RFC adds Flutter's own `gen_l10n` pipeline with ARB catalogs, a saved language setting, and a migration path from inline strings to generated accessors, one screen group at a time.

## Decisions

1. **`gen_l10n` with ARB files**, not a third-party package. It is the Flutter-supported path, types every message, and handles plurals and placeholders.
2. **English is the template** (`app_en.arb`); every other catalog must carry exactly the same keys and placeholders. A test enforces it.
3. **Generated Dart is committed.** `flutter analyze` does not run the generator, and `flutter test` does not regenerate it; only `flutter pub get` or `flutter gen-l10n` does. A test fails when a catalog and its generated file disagree.
4. **Keys are camelCase with a screen prefix** (`settingsCategoryProfileTitle`). ARB keys cannot contain dots, so RFC-037's dotted names map by joining segments.
5. **Language names stay in their own language** (English, Français) so a user can always find theirs.
6. **Product names stay as they are** (Addons, Forja Packs) while other screens still show them in English.
7. **Call sites use `context.l10n`.** Data that used to be `const` strings (the Settings category list) now holds resolver functions instead.
8. **Text from an API is requested in the app language, not translated.** TMDB takes a `language` parameter (checked against the project gateway: French titles, overviews, taglines, genres and poster artwork). The host puts the language in `config.uiLocale` for every hub call, because the engine forwards `config` unchanged but drops unknown top-level context fields. Packs that call TMDB read it. English requests stay byte-identical, and matching a provider title to TMDB keeps using English.
9. **Screens switch at once, API content after a restart.** Hubs already loaded keep the previous language until they reload.
10. **Packs translate their own text with a table, English as the key.** Each hub's `_kit.js` carries `HUB_I18N` plus `hubText(cfg, en)`; a missing locale or entry shows the original English, so existing behaviour cannot change. Manifest `label` and `name` fields are read by the host, so they need a host-side lookup before they can follow the language.
11. **The design-system package gets its words from the app** through `ForjaFoundationStringsScope` (read more, retry, back, search, empty states, the facts panel's labels, statuses and dates). Callers that pass their own text still win; with no scope everything stays English.
12. **AniList has no language option** (its schema has no locale argument and descriptions are English), so French anime text comes from the TMDB enrichment the anime hub already does.

## Out of scope

- Arabic and right-to-left layout (RFC-037 covers it for the web portal).
- Shared catalog package between web and Flutter.
- Audio and subtitle language preferences (separate setting, unchanged).
- Translating provider names and stream titles that come from sources.
- Localizing the language names in the audio and subtitle pickers, file sizes (KB, MB) and money formats.
- Manifest labels until the host can look them up per language.

## Related

- [RFC-037](037-[open]-web-portal-i18n.md) — web portal French + Arabic
- [App language](../features/settings/language.md) — user guide
