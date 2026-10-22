---
name: forja-tv-dpad
description: >-
  Android TV / leanback audit for Forja: D-pad focus, text-field browse-until-
  activate, ShellScope usage, and the eight in-scope tabs sweep. Use when the
  user mentions Android TV, leanback, D-pad, remote, focus lost, keyboard pops,
  TV search, or when a TV fix lands on one tab.
argument-hint: "[tab | path]"
allowed-tools: Bash, Read, Grep, Glob
---

# /forja-tv-dpad $ARGUMENTS

Read `.cursor/rules/forja-tv-scope.mdc` first. In-scope TV tabs: Home, Search, Anime, Asian Drama, IPTV, Live Sports, Lists, Settings. Hub tabs are pack JSON painted by the kit interpreter, so the host-side sweep is `apps/forja/lib/{shell,shared,features/settings}` plus `packages/forja_foundation/lib`.

## Grep sweep (run all; `rg` may need Claude Code's vendored binary on PATH)

| Smell | Command |
|-------|---------|
| Platform read in widgets | `rg -n 'ShellTokens\.(isTvLayout\|isAndroidTvDevice)' apps/forja/lib packages/forja_foundation/lib` |
| Raw text fields | `rg -n 'TextField\(\|TextFormField\(' apps/forja/lib packages/forja_foundation/lib` — each must be `TvBrowseTextField`, `SettingsTextField`, or gated by `browseTextUntilActivate` |
| Focus → activate | `rg -n 'onFocusChange' apps/forja/lib packages/forja_foundation/lib` — none may call open/edit/submit handlers |
| Autofocus into edit | `rg -n 'autofocus: *true' apps/forja/lib packages/forja_foundation/lib` |
| Raw width breakpoints | `rg -n 'width *> *900' apps/forja/lib` |
| Tappables without focus | `rg -n 'GestureDetector\(\|InkWell\(' apps/forja/lib packages/forja_foundation/lib` — cards/tiles should use `shellFocusableTap` / `FocusableControl` / `ForjaInteractive` |

Allowed homes for platform reads: `packages/forja_foundation/lib/tokens/forja_shell_tokens.dart`, shell profile resolver, `PlatformInfo.isAndroidTv` for no-context routes (player, webview, bootstrap).

## Checklist per in-scope screen

- D-pad reaches every interactive control; nothing is a focus trap; back behaves (no double-back exit regressions — see issue 119).
- Hero CTA gets initial focus when `policy.heroPlayAutoFocus`.
- Text field: D-pad land highlights only; OK/Enter opens IME; `readOnly` + `TextInputType.none` while browsing.
- Overlays: `ExcludeFocus` on empty overlay stays (`shell_overlay_navigator.dart`).
- Player: top bar and menus reachable by D-pad on both Exo and MediaKit (issues 110, 122, 125 track known gaps).

## Report

Table: screen · smell · path:line · fix or "clean". Then: which of the eight tabs you swept and which you could not (no pack checkout, no device). Changelog bullets for TV fixes go under **TV**.