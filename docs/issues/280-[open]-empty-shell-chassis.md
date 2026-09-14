# Issue 280: Empty shell chassis — starve `lib/shell/` product + paint

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** shell / foundation / RFC-109

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 5** tasks |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I280-T01 | Law + docs: RFC-109 Wave E / empty-shell slice; design-system + pack-product rules | ✅ |
| 2 | I280-T02 | Delete product chrome (`KitChromeTopBar`, `ShellSearchBar`) + strip `home*` / CW / iptv shell APIs | ✅ |
| 3 | I280-T03 | Move brand + focus/layout paint into `forja_foundation` | 🔄 |
| 4 | I280-T04 | Relocate opaque bus / VF registry under `shared/engine`; expand foundation empty-shell primitives | ✅ |
| 5 | I280-T05 | Collapse `lib/shell/` to chassis wire only; zero product tab id hardcoding | ✅ |

---

## Summary

App must be an **empty chassis**: foundation paints nav + body; packs fill product. Today `apps/forja/lib/shell/` still owns brand paint, dead hub chrome, and Home-hardcoded bus/TV APIs.

**Landed:** brand paint in foundation; `EmptyShellFrame` + `catalog_density`; bus/VF/focus_edge under `shared/engine/runtime/` (shell re-exports removed for VF — registry + rail live in kit/`nav`); product chrome deleted; shell TV/bus zero `'home'`/`'search'` hardcoding; vertical filters rail floats inside `PackLayoutPainter` (not shell scaffold).

**Still open (T03 / R109-A79):** toast paint, `ForjaInteractive` (host TV deps), full scaffold peel into foundation.

Parent: [RFC-109](../rfc/109-[open]-forja-pack-product-host.md) empty-shell slice (A77–A81). Depends on [279](279-[open]-hub-catalog-design-regressions-thin-painter.md) I279-A11 for pack `topBar` mount (do not rebuild chrome in shell).
