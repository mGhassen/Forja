# RFC-022: LAN server/client streaming and one-time-code pairing

**Version:** post-v1.2 (after [RFC-013](013-[draft]-v1.2-sync-lan-party.md))  
**Status:** open  
**Depends on:** [RFC-009 — Rust FFI](fixed/009-[fixed]-rust-ffi.md), [RFC-004 — Provider registry](004-[partial]-provider-registry.md), [issue 003 — playback profiles](../issues/fixed/003-[fixed]-stremio-platform-playback-model.md)  
**Area:** `crates/lan`, `apps/forja/lib/shared/lan`, Settings → LAN

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 8** components (desktop→TV) · **11 / 12** acceptance (desktop→TV) · **0 / 12** acceptance (full matrix) |
| **Current slice** | ATV unpaired HTTP + P2P pair dialog (R22-A23); LAN presence dots (R22-A24); first-frame smoke still open |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R22-C01 | LAN WebSocket server (reuse RFC-007 infra) | ⏭️ |
| 2 | R22-C02 | Pairing + token auth | ⬜ |
| 3 | R22-C03 | Proxy relay for engine resolve | ⬜ |
| 4 | R22-C04 | mDNS discovery | ⬜ |
| 5 | R22-C05 | Constrained client profile | ⬜ |
| 6 | R22-C06 | HDR passthrough relay | ⬜ |
| 7 | R22-C07 | Range seek over LAN | ⬜ |

---

## Components (desktop→TV torrent)

Historical C01–C07 above were never on `main` (stale ✅ from `feat/forja-server`). This slice is HTTP axum + stream tickets, not WebSocket.

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 8 | R22-C08 | `crates/lan` HTTP control (`/health` `/pair` `/open` `/devices` `/revoke`) + remounted torrent/proxy streams | ✅ |
| 9 | R22-C09 | Stream tickets (`?st=` / `X-Forja-Stream-Ticket`) on media GETs — Bearer only on control plane ([026](../issues/026-[open]-lan-stream-playback-bearer-token.md)) | ✅ |
| 10 | R22-C10 | mDNS announce (desktop) + browse (client) | ✅ |
| 11 | R22-C11 | One-time pairing code + device token store / revoke | ✅ |
| 12 | R22-C12 | Dart LAN services, Settings → LAN, ATV paired torrent expose, `LanPlaybackBridge` open path | ✅ |
| 13 | R22-C13 | Desktop LAN torrent activity — persist `/open` history, live status, delete/clear cached downloads | ✅ |
| 14 | R22-C14 | Sticky listen port + client mDNS rediscover by `server_id` + device `last_seen` presence dots | ✅ |
| 15 | R22-C15 | `POST /close` + client release on player exit / cancel — stop matching desktop swarm (keep cache) | ✅ |

---

## Acceptance (v1.2+)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R22-A01 | Server announces over mDNS; client discovers with no typed IP | ⬜ |
| 2 | R22-A02 | mDNS-blocked: manual address entry pairs successfully | ⬜ |
| 3 | R22-A03 | First-time pair with one-time code issues token; code rejected on reuse | ⬜ |
| 4 | R22-A04 | Paired client reconnects across sessions without code prompt | ⬜ |
| 5 | R22-A05 | Revoking a device forces re-pairing | ⬜ |
| 6 | R22-A06 | Direct URL source plays on every client with server offline | ⬜ |
| 7 | R22-A07 | Proxy-gated source: desktop fetches and relays; client plays | ⬜ |
| 8 | R22-A08 | Torrent: desktop serves; Android TV with local-torrent plays locally | ⬜ |
| 9 | R22-A09 | Debrid path plays direct without server when configured | ⬜ |
| 10 | R22-A10 | Relayed 4K HDR / Dolby stream reaches capable client without re-encode | ⬜ |
| 11 | R22-A11 | Range seeking works on file-based playback over LAN | ⬜ |
| 12 | R22-A12 | `constrained` profile: no librqbit; hash streams show clear unavailable state | ⬜ |

---

## Acceptance (desktop→TV torrent)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 13 | R22-A13 | Desktop LAN on → ATV/phone pairs → magnet reaches first frame via ticketed `play_url` (no 401 on `/torrents/…`) | ⬜ |
| 14 | R22-A14 | Paired ATV: Settings → Playback shows Direct torrent / Stremio / Nuvio; enabled toggles drive details white Play + Sources (desktop relay) | ✅ |
| 15 | R22-A15 | Desktop Settings → LAN shows active/in-progress torrent + cached history of LAN opens; delete one or Clear all removes download cache | ✅ |
| 16 | R22-A16 | Desktop restart keeps sticky LAN port; if port/IP still changes, paired client rediscovers via mDNS `server_id` and rewrites saved address without re-pair | ✅ |
| 17 | R22-A17 | Settings → LAN shows green/grey status dots — TV desktop online/offline; desktop paired devices Online/Idle from `last_seen` | ✅ |
| 18 | R22-A18 | LAN restore runs after post-splash torrent/proxy warm; ephemeral fallback only on real bind conflict (not “torrent not running”) so sticky port survives app restart | ✅ |
| 19 | R22-A19 | LAN `POST /open` torrent resolves via `stream_magnet_on_engine` (no nested `Runtime::block_on` panic on desktop) | ✅ |
| 20 | R22-A20 | Leaving or cancelling a LAN torrent play on TV/phone stops the matching desktop download (cache/history kept until Delete) | ✅ |
| 21 | R22-A21 | `/close` uses `stop_on_engine` (no nested `block_on`); client closes without requiring parsed info_hash; cancel-before-`play_url` and TV Back→maybePop still stop the desktop swarm | ✅ |
| 22 | R22-A22 | Desktop idle-watch: owner TV idle 120s → pause swarm; still idle +120s → stop + delete cache/history (resume if TV returns during grace) | ✅ |
| 23 | R22-A23 | Unpaired ATV: Direct torrent / Stremio / Nuvio Sources on; HTTP plays on TV; P2P play shows pair dialog; paired P2P stays on desktop | ✅ |
| 24 | R22-A24 | Nav rail + Settings LAN dots: waiting (server up, unpaired), idle, paired/online, playing, client desktop-offline | ✅ |

---

## 1. Summary

Forja ships on **Android, iOS, Windows, macOS, and Linux** today. Not every device can do every job: future TV targets (Tizen, webOS) and the web client ([RFC-010](010-[draft]-web-client.md)) cannot run the full Rust engine or librqbit; phones are poor at sustained torrenting. This RFC defines a **LAN server/client split** so one capable device (the desktop) carries heavy engine work — torrent download, upstream fetch behind the local proxy, WebView-dependent extractors — while every other device stays a thin client that either plays a resolved URL directly or asks the desktop for one.

Devices find each other on the local network with zero typed IP addresses (mDNS). A client is authorised to a server once via a short code shown on the server; a stored token keeps it paired afterward.

**Scope:** LAN only. Same Wi-Fi. Remote access (server and client on different networks) is explicitly out of scope.

**Not in scope for this RFC:** LAN remote control (play/pause/seek) — see [RFC-007](007-[draft]-lan-companion.md). The two features may share mDNS and pairing infrastructure but serve different purposes.

---

## 2. Motivation

Playback routing depends on three facts: whether the source is a direct URL or a magnet/`infoHash`, whether the client needs the **local proxy** (CORS, custom headers, HLS rewrite, site-specific relays), and whether the current device can run the **Rust engine** (librqbit, blocking resolve, WebView extractors). Today every native target runs the full engine locally ([issue 003](../issues/fixed/003-[fixed]-stremio-platform-playback-model.md)); constrained platforms cannot ship that way.

This RFC fixes routing into two paths (**play direct**, or **desktop serves**), plus one opt-in local exception, and specifies discovery and pairing so the desktop is reachable without configuration.

Goals:

- No user ever types an IP address (mDNS first; manual entry only as fallback).
- A client pairs to a server once, then reconnects silently.
- Direct URL sources play on the client with no server dependency.
- Engine-only work (torrent, proxy-gated upstream, heavy resolve) is served by the desktop and reaches every client, including future TV/web builds that cannot run `libffi`.
- When the desktop is offline, direct playback still works everywhere; only server-dependent titles are unavailable.

Non-goals:

- Remote (off-LAN) access, NAT traversal, relay infrastructure.
- Transcoding (playback is passthrough/remux only; see §6).
- Phone-as-server for torrent or relay (the desktop is the sole server).
- VPN integration — Forja has no VPN layer. Geo or network restrictions are handled by **desktop-side upstream fetch + LAN relay** through the existing proxy/torrent axum servers, not a VPN app.

---

## 3. Roles

Two roles. A device may be a client only, or both a client and the server.

| Role | Who | Responsibility |
|------|-----|----------------|
| **Server** | Desktop (win/mac/linux) | Runs `libffi` (Rust engine), holds librqbit + local proxy, resolves sources, downloads torrents, relays video over the LAN, announces via mDNS, issues pairing tokens |
| **Client** | Phone, tablet, iOS, Android, and the desktop itself when not acting as server | Discovers the server, pairs once, plays direct URLs itself, or requests a play URL from the server and plays it |

The phone is a **client only**. It is never a server. This avoids phone-side foreground-service work, iOS background-networking fragility, and battery cost.

Future **constrained clients** (web per RFC-010, Tizen/webOS when added) are client-only with the `constrained` playback profile from issue 003.

---

## 4. Routing model

Routing uses a **playback capability profile** ([issue 003](../issues/fixed/003-[fixed]-stremio-platform-playback-model.md)) plus source kind. The profile is compile-time (platform) with one user override (Android TV local torrent).

### 4.1 Capability profiles (baseline)

| Profile | Platforms | `localTorrentEngine` | `stremioInfoHash` without debrid | `builtinTorrentSearch` |
|---------|-----------|----------------------|----------------------------------|------------------------|
| `desktop` | win / mac / linux | yes (is the LAN server) | LocalEngine | yes |
| `mobile` | Android, iOS | yes on device; prefer desktop for sustained torrent | LocalEngine or Debrid | yes |
| `constrained` | Web (RFC-010), future TV | no | DebridOnly or **DesktopServes** | no |

Expose via `PlatformPlayback.capabilities` in the host (`apps/forja`).

### 4.2 Routing table

| Platform (client) | Direct URL (WebStreamr, template providers, IPTV, Stremio `url`) | Needs local proxy / engine resolve | Torrent / Stremio `infoHash` |
|-------------------|-------------------------------------------------------------------|-------------------------------------|------------------------------|
| Android phone | Play direct | Desktop serves | Desktop serves (or debrid → direct) |
| Android TV | Play direct | Desktop serves | Local if **allow local torrent** setting on; else desktop (or debrid) |
| iOS | Play direct | Desktop serves | Desktop serves (or debrid → direct) |
| Desktop (server) | Play direct | Local (`crates/proxy`) | Local (`crates/torrent` / librqbit) |
| Desktop (client to another server) | Play direct | Remote desktop serves | Remote desktop serves |
| Web / future TV (`constrained`) | Play direct | Desktop serves | Desktop serves or debrid → direct; hide hash streams if neither available |

Three outcomes:

- **Play direct** (lightest): client plays the resolved URL with media_kit (or external player). No LAN server. Covers most WebStreamr, template providers, IPTV, Stremio `url`, and debrid-resolved magnets.
- **Desktop serves**: client calls the LAN control API; desktop resolves or downloads, then returns a LAN play URL on the desktop's axum surface. HDR / Dolby Vision / Atmos preserved via passthrough relay.
- **Local**: desktop runs engine locally; Android TV may opt in to local librqbit via settings (same path as today on desktop/Android, gated by profile).

Fallback: if the desktop is offline, **play direct** cells keep working; **desktop serves** titles show as unavailable (distinct from "never paired" — see §13).

Provider resolution on the server reuses the host orchestration in `packages/api/lib/playback/providers/registry/provider_registry.dart` + `StreamResolver`, calling into `libffi` for Rust pipelines ([RFC-004](004-[partial]-provider-registry.md), [ARCHITECTURE.md](../ARCHITECTURE.md) §4.3).

---

## 5. Discovery (no typed IP)

On the same Wi-Fi, the server announces and the client listens.

- Server advertises `_forja._tcp` via mDNS/Bonjour with LAN IP, control port, and stable server id in TXT.
- Client listens, learns IP/port, refreshes when the address changes between sessions.
- Direction: server announces, client discovers (Chromecast / Plex pattern).

**Fallback:** manual "enter server address" when multicast is blocked.

**Implementation:**

| Layer | Location | Notes |
|-------|----------|-------|
| mDNS responder | Rust (`crates/` — new module or small crate wired through `ffi`) | Runs in the desktop `libffi` process alongside axum |
| mDNS client | Flutter host (`apps/forja`) | `multicast_dns` or platform NSD |

Do **not** revive `packages/streaming` — it was deleted in wave 1. All LAN HTTP lives in Rust axum inside `libffi`.

---

## 6. Playback and streaming

The server **relays**; it does not transcode.

- **Direct play:** bytes forwarded untouched when the client's player accepts the container/codecs.
- **Remux only when needed:** if codecs are fine but the container is wrong, repackage with ffmpeg stream copy (`-c copy`). No decode/encode — HDR / DV / Atmos survive. *Not implemented today; add only if a concrete source requires it.*
- **No transcoding:** re-encoding drops HDR/DV metadata; unnecessary on LAN bandwidth.

Existing relay surfaces (today bound to `127.0.0.1`, extended to LAN in this RFC):

| Subsystem | Rust module | Routes |
|-----------|-------------|--------|
| Torrent stream | `crates/torrent` → `engine_torrent.rs` | `GET /torrents/{id}/stream/{file_id}/{*filename}` |
| Local proxy | `crates/proxy` → `engine_proxy.rs` | `/health`, `/proxy`, `/hls-proxy`, `/proxy/{token}`, `/jellyfin-stream`, … |

Both run **inside the `libffi` process** ([ARCHITECTURE.md](../ARCHITECTURE.md) §3.4), not a separate OS service.

**Range requests:** torrent and file-based proxy routes must support HTTP `Range` for seeking (torrent handler already serves pieces this way).

**Token gating:** LAN-facing stream routes require the same bearer token as control API (§8).

---

## 7. Pairing (one-time code)

The code hands the client a durable token on first contact. After pairing, the token replaces the code.

### 7.1 First-time flow

1. Desktop server starts, announces mDNS, displays a 6-digit code (optional QR: code + server id).
2. Client discovers the server and prompts for the code once.
3. Client `POST /pair` with code + device id.
4. Server validates, generates opaque token, stores `{ device_id, paired_at, label? }` in `crates/storage` KV, returns token.
5. Client stores token in host prefs (`packages/rust` / secure storage).

### 7.2 Later sessions

- Client discovers via mDNS, attaches token to every control and stream request.
- Missing or rejected token → code screen again.

### 7.3 Code rules

- Single use: expires on first successful pair and after a short TTL (e.g. 5 minutes).
- Digits minimum; QR optional accelerator for phone clients.

### 7.4 Token rules

- Random, opaque, per device. Stored server-side with metadata.
- Required on all endpoints except `/health` and `/pair`.
- Revocable via `POST /revoke` (server management UI).

---

## 8. Control API (Rust axum, desktop server)

New routes on the desktop's LAN-bound axum router (same process as proxy/torrent). JSON marshaling per [RFC-009](fixed/009-[fixed]-rust-ffi.md): complex payloads as JSON strings; errors as `{"error":"..."}`.

| Method + route | Auth | Purpose |
|----------------|------|---------|
| `GET /health` | none | Liveness; confirm discovered server is Forja |
| `POST /pair` | code | Exchange one-time code for token |
| `GET /search?q=` | token | Torrent search (wraps `scrapers::search_all` via FFI pipeline) |
| `POST /resolve` | token | Resolve title to candidate sources (host calls server; server runs provider registry + engine) |
| `POST /open` | token | Open stream (torrent add or proxy route register); returns LAN play URL |
| `POST /close` | token | Stop matching torrent swarm when client leaves player (`info_hash`); keeps cache |
| `GET /status?handle=` | token | Stream status (progress, buffered, errors) |
| `GET /devices` | token | List paired devices |
| `POST /revoke` | token | Revoke a device token |

Plus existing stream routes (§6), bound to `0.0.0.0` (or selected LAN interface) instead of `127.0.0.1`, token-gated.

These are **thin HTTP wrappers** over engine calls that already exist — no new engine logic. Long resolves on the server run on the FFI tokio runtime; clients must not block the UI thread on their own resolves either ([ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md), `Isolate.run`).

**Client-side:** new Dart service in `apps/forja/lib/shared/lan/` (or `packages/rust` if prefs-heavy) — HTTP only, no duplicate engine logic in Dart.

---

## 9. Storage

| Side | What | Where |
|------|------|-------|
| Server | Issued tokens, pairing metadata, server settings | `crates/storage` JSON KV (same as engine storage today) |
| Client | Token, last-known server id/address | Host prefs via `packages/rust` (`SettingsService` / KV) |

---

## 10. Settings surface

| Setting | Scope | Default |
|---------|-------|---------|
| Enable LAN server | Desktop only | off |
| Allow local torrent on this device | Android TV (capable boxes) | off |
| Paired server / manual address | Client | empty until paired |
| Paired devices + revoke | Server management UI | — |
| Re-show pairing code | Server | — |

No per-source relay toggles. No phone-as-server.

Server auto-disable when app backgrounded: configurable (align with RFC-007 security note).

---

## 11. Platform notes

| Platform | Engine | LAN role |
|----------|--------|----------|
| **Windows / macOS / Linux** | Full `libffi` | Server + client |
| **Android / iOS** | Full `libffi` today | Client only (prefer desktop for torrent/proxy-heavy paths) |
| **Web (RFC-010)** | WASM subset, no librqbit | Client only (`constrained`) |
| **Tizen / webOS** | Not in repo yet | Future client only (`constrained`); native player must accept server stream URLs |

Host-only concerns stay in Flutter: media_kit player, WebView extractors (when resolve must stay on server, client never runs WebView for that title), OAuth, secure storage.

---

## 12. Doability

| Piece | Status |
|-------|--------|
| Torrent + proxy axum in `libffi` | **Shipped** — localhost only |
| Provider registry + resolver | **Shipped** — `packages/api/lib/playback/` |
| Playback profiles | **Implemented** — [issue 003](../issues/fixed/003-[fixed]-stremio-platform-playback-model.md) |
| Debrid → direct URL | **Shipped** — bypasses torrent engine |
| Bind axum to LAN + token auth | New |
| mDNS announce/discover | New |
| Pairing endpoints + UI | New |
| Control API wrappers | New (thin over existing FFI) |

No research-grade problems. This RFC adds LAN plumbing on top of existing engine surfaces.

---

## 13. Open questions

- QR at launch, or digits only for v1?
- Token lifetime: indefinite until revoked, or expiry with silent refresh?
- Multiple desktops on one LAN: client pick-list or first-found?
- Distinct UI for "server offline" vs "never paired"?
- Share mDNS/pairing layer with [RFC-007](007-[draft]-lan-companion.md) remote control?
- Server-side resolve: run full Dart `StreamResolver` in an isolate on desktop, or port resolve orchestration to Rust in wave 2?

---


---

## 15. Related

- [RFC-009 — Rust FFI](fixed/009-[fixed]-rust-ffi.md)
- [RFC-004 — Provider registry](004-[partial]-provider-registry.md)
- [RFC-007 — LAN companion](007-[draft]-lan-companion.md) (remote control)
- [RFC-010 — Web client](010-[draft]-web-client.md)
- [RFC-013 — v1.2 sync / LAN party](013-[draft]-v1.2-sync-lan-party.md)
- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md)
- [issue 003 — playback profiles](../issues/fixed/003-[fixed]-stremio-platform-playback-model.md)
- [issue 026 — LAN stream Bearer token](../issues/026-[open]-lan-stream-playback-bearer-token.md) (blocks playback)
- [issue 027 — LAN manual QA](../issues/027-[draft]-lan-server-client-manual-qa.md)
- [issue 028 — desktop LAN client](../issues/028-[draft]-desktop-lan-client-not-implemented.md)
- [issue 029 — LAN range seek](../issues/029-[draft]-lan-range-seek-unverified.md)
- [issue 030 — LAN HDR passthrough](../issues/030-[draft]-lan-hdr-passthrough-unverified.md)
