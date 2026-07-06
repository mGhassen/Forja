# 002 — Torrent stream cache is never purged from disk

**Status:** open  
**Area:** `crates/torrent`, `packages/streaming`, `apps/forja` (player, settings, bootstrap)  
**Reported:** 2026-07-06

## Summary

Torrent playback via librqbit writes downloaded pieces to a persistent directory under the system temp folder (`{temp}/torrent`). Closing the player or switching films only pauses or forgets the torrent in the session — **files are never deleted**. Repeated viewing accumulates gigabytes of orphaned data. Settings expose a RAM/Disk cache toggle that is not wired to the Rust engine.

Playback is **stream-while-download** (not download-then-play): the player reads from a localhost HTTP URL with range support, but librqbit caches every fetched piece on disk as playback progresses.

## Root cause

1. **Hardcoded disk download dir** — `crates/torrent/src/lib.rs` creates a librqbit session at `std::env::temp_dir().join("torrent")`. All streamed bytes are cached on disk as pieces arrive.

2. **Player close only pauses** — `TorrentStreamService.removeTorrent()` → `torrentStop()` → Rust `stop()` calls `session.pause()`. No `session.delete(id, true)`.

3. **Torrent switch uses `forget`, not `delete`** — `prepare_magnet()` calls `api_torrent_action_forget` when the info-hash changes. Per rqbit/librqbit API, forget removes the torrent from the session but **keeps files on disk**.

4. **App shutdown does not wipe cache** — `TorrentStreamService.cleanup()` stops the engine but never deletes `{temp}/torrent`. Contrast: 111477 proxy explicitly purges its on-disk cache on player close and app exit (`purge111477Cache()` in `bootstrap.dart`).

5. **No selective file download** — `AddTorrentOptions` sets `overwrite: true` only. No `only_files` for the selected video index, so multi-file torrents may download more than the stream file.

6. **Misleading settings UI** — Settings → Torrent Engine shows **Cache Type (RAM / Disk)** and **RAM Cache Size**. `packages/streaming/lib/src/torrent_stream_service.dart` never reads `getTorrentCacheType()` or `getTorrentRamCacheMb()`. Leftover from libtorrent; Rust always uses disk.

## Impact

- **Disk growth is unbounded** across sessions. Watching 10 full films at ~4 GB each can leave ~40 GB in temp with no user-visible indication.
- **Partial watches still leak** — only the watched portion is cached, but it is never removed on close.
- **Mobile / small SSD risk** — temp may not be reclaimed by the OS if the subfolder persists across reboots.
- **Settings lie** — users who pick "RAM" cache still write to disk.
- **Inconsistent with 111477** — that proxy was built with explicit disk-bounding and purge; the librqbit port did not inherit the same lifecycle policy.

## Reproduction

1. Play a torrent film to completion (or most of it).
2. Close the player.
3. Inspect `{temp}/torrent` (macOS: `/var/folders/.../T/torrent` or `$TMPDIR/torrent`).
4. Observe video data still present. Repeat with another film — directory grows.

## Workarounds (none reliable)

- Manually delete `{temp}/torrent` while the app is quit.
- Avoid torrent provider if disk space is tight.

## Proposed fix

### Rust (`crates/torrent`)

- Replace `stop()` pause with `session.delete(torrent_id, true)` (delete with files).
- On `stop_engine()` / shutdown: best-effort `remove_dir_all` on `download_dir()` after session is dropped (mirror 111477 purge timing — after player disposed so file handles are released).
- In `prepare_magnet()`: set `only_files` to the selected video file index before or after add.
- Optionally: cap retained torrents (LRU) or max cache size — only if delete-on-close is insufficient.

### Dart (`packages/streaming`, `apps/forja`)

- `removeTorrent()` should trigger delete-with-files, not pause-only.
- `cleanup()` should purge torrent temp dir after engine stop (with grace delay like 111477 on Windows).
- Wire RAM cache setting to librqbit if supported, **or** remove the dead settings UI until implemented.

### Docs

- Document torrent disk policy in `docs/ARCHITECTURE.md` §4.1 (lifecycle + temp path).
- Add acceptance test: play torrent → close player → assert `{temp}/torrent` empty or below threshold.

## Related

- `crates/torrent/src/lib.rs` — `download_dir()`, `stop()`, `prepare_magnet()`, `stop_engine()`
- `packages/streaming/lib/src/torrent_stream_service.dart` — `removeTorrent()`, `cleanup()`
- `apps/forja/lib/shared/player/player/desktop_player_screen.dart` — `dispose()` → `removeTorrent`
- `apps/forja/lib/shared/player/player/mobile_player_screen.dart` — same
- `apps/forja/lib/app/bootstrap.dart` — `cleanup()` on close (no torrent dir purge)
- `apps/forja/lib/features/settings/settings_screen.dart` — unused RAM/Disk cache UI
- `packages/forja_streaming/lib/src/site111477_proxy.dart` — reference implementation for cache purge
- `docs/rfc/006-supabase-sync.md` — mentions "torrent cache" as local-only (sync), not as a disk leak
- [librqbit `Session::delete`](https://docs.rs/librqbit/latest/librqbit/struct.Session.html) — `delete_files: true`
- rqbit API: `POST /torrents/{id}/delete` vs `/forget` (forget keeps files)
