---
paths:
  - "apps/forja/lib/**/*.dart"
  - "packages/forja_foundation/lib/**/*.dart"
---

# TV / D-pad / focus / text fields

Read `.cursor/rules/forja-tv-scope.mdc` before touching focus, D-pad, leanback, search chrome, or **any text field**.

The line that bites: on leanback TV, D-pad focus on a text field **only highlights**. Activation (keyboard, edit mode, open search, submit) needs OK / Enter / click. Desktop and phone type on focus. Gate with `ShellInputPolicy.browseTextUntilActivate`; use `TvBrowseTextField` / `SettingsTextField`, or give the foundation widget a field-builder prop that the host fills.

Read platform via `ShellScope.metricsOf` / `inputPolicyOf`, never `ShellTokens.isTvLayout` in widgets (CI `check_tv_shell_boundary.sh`).

In-scope TV tabs: Home, Search, Anime, Asian Drama, IPTV, Live Sports, Lists, Settings. Fixing D-pad on one tab → grep the same pattern across the other seven before saying done.
