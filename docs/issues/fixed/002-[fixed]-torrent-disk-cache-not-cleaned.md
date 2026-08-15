# 002 — Torrent stream cache is never purged from disk

**Priority:** P2  
**Severity:** High  
**Status:** fixed  
**Area:** `crates/torrent`, `packages/rust/lib/src/playback/torrent/torrent_stream_service.dart`, `apps/forja` (player, settings)  
**Reported:** 2026-07-06

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 8 / 8** fix · **2 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I02-T01 | Rust: `stop()` uses `session.delete(id, true)` | ✅ |
| 2 | I02-T02 | Rust: `stop_engine()` purges `{temp}/torrent` | ✅ |
| 3 | I02-T03 | Rust: `only_files` for selected video index | ✅ |
| 4 | I02-T04 | Dart: `removeTorrent()` triggers delete-with-files | ✅ |
| 5 | I02-T05 | Dart: `cleanup()` purges torrent temp dir | ✅ |
| 6 | I02-T06 | Wire or remove dead RAM/Disk cache settings UI | ✅ |
| 7 | I02-T07 | Rust: disk cache budget + LRU reclaim (protect active files, keep DHT state) | ✅ |
| 8 | I02-T08 | Settings: disk cache size (GB) slider wired to the engine | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I02-A01 | Unit tests: reclaim evicts oldest idle files, never protected or `dht_state.json` | ✅ |
| 2 | I02-A02 | Settings disk cache GB defaults: desktop 2, phone/TV 1; clamp 1–16 | ✅ |
| 3 | I02-A03 | Manual: play torrent → close player → `{temp}/torrent` at or under the cap | ⬜ |

---


## Summary

Torrent playback via librqbit writes downloaded pieces to a persistent directory under the system temp folder (`{temp}/torrent`). Closing the player or switching films only pauses or forgets the torrent in the session — **files are never deleted**. Repeated viewing accumulates gigabytes of orphaned data. Settings expose a RAM/Disk cache toggle that is not wired to the Rust engine.

Playback is **stream-while-download** (not download-then-play): the player reads from a localhost HTTP URL with range support, but librqbit caches every fetched piece on disk as playback progresses.

## Root cause

1. **Hardcoded disk download dir** — `crates/torrent/src/lib.rs` creates a librqbit session at `std::env::temp_dir().join("torrent")`. All streamed bytes are cached on disk as pieces arrive.

2. **Player close only pauses** — `TorrentStreamService.removeTorrent()` → `torrentStop()` → Rust `stop()` calls `session.pause()`. No `session.delete(id, true)`.

3. **Torrent switch uses `forget`, not `delete`** — `prepare_magnet()` calls `api_torrent_action_forget` when the info-hash changes. Per rqbit/librqbit API, forget removes the torrent from the session but **keeps files on disk**.

4. **App shutdown does not wipe cache** — `TorrentStreamService.cleanup()` stops the engine but never deletes `{temp}/torrent`. Contrast: 111477 proxy explicitly purges its on-disk cache on player close and app exit (`purge111477Cache()` in `bootstrap.dart`).

5. **No selective file download** — `AddTorrentOptions` sets `overwrite: true` only. No `only_files` for the selected video index, so multi-file torrents may download more than the stream file.

6. **Misleading settings UI** — Settings → Torrent Engine shows **Cache Type (RAM / Disk)** and **RAM Cache Size**. `packages/api/lib/playback/torrent/torrent_stream_service.dart` never reads `getTorrentCacheType()` or `getTorrentRamCacheMb()`. Leftover from libtorrent; Rust always uses disk.

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
- `docs/rfc/006-[partial]-supabase-sync.md` — mentions "torrent cache" as local-only (sync), not as a disk leak
- [librqbit `Session::delete`](https://docs.rs/librqbit/latest/librqbit/struct.Session.html) — `delete_files: true`
- rqbit API: `POST /torrents/{id}/delete` vs `/forget` (forget keeps files)

## Shipped (2026-08-15)

Root cause of unbounded growth is fixed in `crates/torrent`:

- `stop()` / torrent switch / failed add use `api_torrent_action_delete` (files go with the swarm). LAN idle pause is unchanged (`pause_active_on_engine`).
- `stop_engine()` / `cleanup()` delete the active torrent then **reclaim to the disk budget**. Not `remove_dir_all` on `{temp}/torrent` — `dht_state.json` stays. T02/T05 intent (no unbounded leftover) is this path, not a full wipe.
- `only_files` was already applied on stream start (I02-T03).
- Settings **Cache type RAM/Disk** is gone. **Disk cache: N GB** (1–16) drives `torrent_set_disk_cache_bytes`. Defaults: desktop 2 GB, phone/TV 1 GB. Playing files are protected; oldest idle files are LRU-evicted.
- Clear cache (Sources / Settings data cleaner / LAN) calls reclaim with target 0 (unprotected files only).

**Verify:** `cargo test -p torrent` (reclaim unit tests). Manual I02-A03 still ⬜.
