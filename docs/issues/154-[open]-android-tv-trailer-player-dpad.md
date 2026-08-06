# 154 — Android TV trailer player lacks D-pad / Back / Exit

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · trailer player · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I154-T01 | `PlayerBackExitGate`: first Back shows chrome + focuses Back; second exits (parity with film player) | ✅ |
| 2 | I154-T02 | More videos card: ←/→ cycle trailers, OK plays, ↑ → Back, ↓ → seekbar; transport ←/→/↑ wired with focus nodes | ✅ |
| 3 | I154-T03 | `PlayerTvRemoteKeyHandler`: do not treat Escape as Back — remote Exit reaches `handleShellExitKey` | ✅ |
| 4 | I154-T04 | Unit test: Escape does not invoke player `onBack` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I154-A01 | Android TV: on More videos, ←/→ change preview, OK plays another trailer, ↑ focuses Back | ⬜ |
| 2 | I154-A02 | Android TV: remote Back focuses Back then exits trailer (menus dismiss first); remote Exit double-confirm quits app | ⬜ |
| 3 | I154-A03 | Android TV: ↑ from transport reaches seekbar; ↑ from seekbar reaches More videos (when multi-trailer) or Back | ⬜ |

---

## Summary

The native trailer player (`TrailerPlayerScreen`) had partial TV chrome but broken remote behavior:

1. **BackExitGate** hid chrome on first Back instead of focusing the Back control (unlike MediaKit / Exo).
2. **More videos** had ←/→ edge callbacks but no ↑/↓ neighbors; transport lacked explicit focus nodes (full-screen `FocusScope` spatial trap — issue 130).
3. **Escape** was mapped to player Back inside `PlayerTvRemoteKeyHandler`, stealing remote **Exit** from `ShellTvBackHandler`.

**Root fix:** same Back-arm ladder as the film player; explicit trailer chrome focus graph; Escape left for Exit.

**Not verified on device** — acceptance rows remain ⬜.

## Related

- [RFC-055](../rfc/055-[open]-native-youtube-trailer-player.md)
- [130](130-[open]-android-tv-player-dpad-stuck-on-play.md) — full-screen FocusScope spatial trap
- [119](119-[open]-android-tv-double-back-exit.md) — Back vs Exit
- [Media details](../features/movies-tv/media-details.md)
