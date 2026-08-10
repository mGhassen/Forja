# 101 — Player Back lands on stream loading screen

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** player exit · anime / Asian Drama / movie loading hosts

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I101-T01 | Register stream-loading routes (`loading_overlay`) for movie dialogs + anime/AD hosts | ✅ |
| 2 | I101-T02 | Player Back/Escape pops player then strips registered loading route in the same frame | ✅ |
| 3 | I101-T03 | Keep anime/AD host mounted during playback (I75 Source reload / handoff) — strip only on exit | ✅ |
| 4 | I101-T04 | Harden exit: always `canPop: false` + capture navigator before awaits; `dismissActiveLoadingOverlayRoute` popUntil fallback + post-frame retry; anime/AD pop host before cache cleanup | ✅ |
| 5 | I101-T05 | Strip loading **before** player pop (`removeRoute` under player) — pop-then-dismiss painted one frame of resolve UI | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I101-A01 | Movie/TV: Back from player returns to details — not the resolve loading overlay | ⬜ |
| 2 | I101-A02 | Anime: Back from player returns to anime details — not `AnimePlayerScreen` loading | ⬜ |
| 3 | I101-A03 | Asian Drama: Back from player returns to drama details — not KissKh loading | ⬜ |

---

## Summary

Player and stream-loading UI share the **root** navigator. Details stay on the shell overlay. Back only popped `PlayerScreen`, so a loading dialog/host left underneath became visible — users saw the resolve roulette instead of details.

Movies/TV already strip the dialog via `crossfadeLoadingOverlayToPlayer` during the fade. Anime and Asian Drama **must** keep `AnimePlayerScreen` / `AsianDramaPlayerScreen` under the player for the whole session (issue [075](fixed/075-[fixed]-anime-dead-cache-empty-sources.md) — early `removeRoute` disposed Source cache / `onReloadStreams`). Those hosts are registered and removed **on player exit only**.

### Why the first strip still failed (I101-T04)

Mobile/TV `PopScope` flipped `canPop: true` then deferred the pop. A system/deferred pop could unmount the player **before** `dismissActiveLoadingOverlayRoute` ran (`if (!mounted) return`). Desktop could return early after stop without dismiss, and dismiss relied only on a singleton registration (no-op when cleared). Anime/AD also awaited cache cleanup **before** self-popping the host, so a missed dismiss left the loading page on screen.

### Hardening (I101-T04)

- Desktop / mobile MediaKit / Exo / checking scaffold / external handoff: capture root navigator before awaits; always dismiss after pop (even if State unmounted).
- `canPop: false` for the whole player session (forced `Navigator.pop` still used for episode handoff / sources-exhausted so the host stays).
- `dismissActiveLoadingOverlayRoute`: registered `removeRoute` + `popUntil` by name + next-frame retry.
- Anime/AD: pop (or dismiss) the host **immediately** after `playerFuture`, before cache/notifier cleanup.

### Flash after T04 (I101-T05)

T02/T04 still did **pop player → then dismiss**. That order reveals the loading route for at least one frame (worse when the first `removeRoute` hits a locked navigator and the post-frame retry paints after). Fix: call `dismissActiveLoadingOverlayRoute` **before** `Navigator.pop` on every exit path so `removeRoute` yanks the host from under the player; then pop reveals details.

## Related

- [075](fixed/075-[fixed]-anime-dead-cache-empty-sources.md) — why hub loading hosts stay under the player during playback
- [Player](../features/playback/player.md)
