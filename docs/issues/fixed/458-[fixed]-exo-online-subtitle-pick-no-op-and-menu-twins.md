# 458 — Android player: online subtitle pick does nothing; subtitle menu repeats attached subtitles

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android / Android TV Exo player · subtitle menu · sideloads

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 8 / 8** fix · **4 / 5** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I458-T01 | Native: remember the open's URL and options after the old pipeline is released, not before, so a subtitle reload after a fresh open has a media URL to rebuild | ✅ |
| 2 | I458-T02 | Native: a subtitle reload reports how many sideloads it attached; Dart treats zero as a failure | ✅ |
| 3 | I458-T03 | Native sideloads carry an id (the source URL); the tracks report carries the format id; Dart selects the exact track, with the merge-child prefix stripped | ✅ |
| 4 | I458-T04 | A manual pick owns the text track: auto-pick and late provider attach defer to it; a download that finishes after a newer pick is dropped; a pick already attached switches track without a reload | ✅ |
| 5 | I458-T05 | Subtitle menu lists a sideload once (row, not row + in-stream twin) and marks the picked row selected; rows from an earlier provider list never carry over on reopen; late batch reset per open | ✅ |
| 6 | I458-T06 | Source switch keeps the picked sideload and resets per-open subtitle state | ✅ |
| 7 | I458-T07 | Pure session rules module + tests; loading / done / failed chip and logs on every pick step | ✅ |
| 8 | I458-T08 | Native: keep the Media3 subtitle view hidden on every cue (a TV photo on the official build shows the same cue painted twice, one copy ignoring the player chrome); log once when it was found visible | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I458-A01 | TV emulator: pick an online French subtitle on episode 1 → cues render, menu row checked | ✅ |
| 2 | I458-A02 | TV emulator: episode 2 and 3 after the pick → menu counts unchanged, one cue line on screen | ✅ |
| 3 | I458-A03 | TV emulator: pick through the local translate relay (proxy token) works | ✅ |
| 4 | I458-A04 | Unit: three opens with different provider rows do not grow the list; flush vs pick in both interleavings; merged-prefix id match | ✅ |
| 5 | I458-A05 | Physical Android TV: 2× / 3× cue stacking across episodes reported by the user no longer reproduces | ⬜ |

---

## Summary

Reported: a subtitle picked on episode N shows doubled on N+1 and tripled on N+2, and picking an online subtitle from the menu does nothing.

On the Android TV emulator the pick never applied. Device logs showed the native reload returned without touching the player: `open()` stored the stream URL and options, then released the previous pipeline on the fresh-player path, and that release cleared them. Every reload after a fresh open was a silent no-op; only the soft-reopen path kept them. Once the reload ran, the Dart side matched the new text track by language, so with two subtitles in the same language the pick could land on the wrong one or on nothing; Media3 echoes the sideload id as `1:<id>` (merge child prefix), which the selector now strips.

The menu listed each attached subtitle twice (online row + Media3 text track), one more twin per pick, and a failover reopen kept the previous provider rows as if they were online results. No host-side state carries subtitles from one episode route to the next; the cross-episode 2× / 3× cue stacking was not reproduced on the emulator before or after the fix (before: the pick never applied here), so A05 stays open for a physical-device check. A TV photo on the official build shows two separate cue boxes for one line, the lower one over the seek bar; Flutter paints one box per player screen, so the second box most likely comes from the native Media3 subtitle view, which T08 now hides on every cue.

### Related

- [132](../132-[open]-android-tv-exo-auto-subtitle-merging-crash.md) — late sideloads attach only after READY
- [230](../230-[open]-android-tv-exo-subtitles-invisible.md) — cues painted in Flutter
- [RFC-122](../../rfc/122-[draft]-android-tv-remote-ux.md) — branch this landed on
