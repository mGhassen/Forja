# 029 — LAN range seek over relay unverified (R22-A11)

**Status:** draft  
**Priority:** P3  
**Severity:** Low  
**Area:** `crates/lan`, `crates/proxy`, `crates/torrent`, player

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 2** verification |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I29-A01 | Seek/scrub works on LAN-relayed torrent stream (206/Range end-to-end) | ⬜ |
| 2 | I29-A02 | Seek/scrub works on LAN-relayed proxy stream (HLS or file proxy) | ⬜ |

---

## Summary

RFC-022 R22-A11 requires range seeking on file-based playback over LAN. Localhost engine already forwards `Range` in `crates/proxy` and handles ranges in `crates/torrent` stream handler — **not verified** through the LAN gateway + token middleware + client player path.

This is **verification debt**, not necessarily missing engine logic. File code bugs only if manual QA fails after [026](026-[open]-lan-stream-playback-bearer-token.md).

**Does not block:** pairing, `/open`, or first-frame play.

## Related

- [RFC-022](../rfc/022-[draft]-lan-server-client.md) R22-A11, R22-C07
- [026](026-[open]-lan-stream-playback-bearer-token.md)
- [027](027-[draft]-lan-server-client-manual-qa.md)
