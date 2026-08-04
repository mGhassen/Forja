# IPTV — M3U

> Add M3U/M3U8 playlist portals by URL — browse live channels in the main IPTV catalog.

## What it is

Forja treats **M3U/M3U8 playlists** as first-class portals next to Xtream and Stalker. Add a playlist URL (optional User-Agent), then browse groups as categories on the **Live** shelf.

## How to open it

**IPTV** → **Portals** → **Add** → choose **M3U**.

## What you can do

- Add a playlist by URL (optional custom User-Agent for hosts that reject the default)
- Tap the folder icon next to the URL field to pick a local `.m3u`/`.m3u8` file instead of pasting a link
- Browse live channels by `group-title` in the same catalog browser as Xtream
- Play a channel in the IPTV player — in-player guide and search work for live
- Manage M3U portals in the Portals panel (edit, favorite, delete, share/CSV)
- Sync M3U portals to your signed-in profile (same cloud list as Xtream)

## Setup

1. Obtain an M3U/M3U8 URL from your provider, or pick a local playlist file
2. **Portals** → **Add** → **M3U** → paste the URL (or choose a file) → confirm
3. Open the portal from the list

## Tips

- **Movies** and **Series** shelf chips are hidden for M3U (playlists are live-only)
- Existing device-local playlists with a URL are migrated into portal entries once
- Large playlists download to a temp file and parse from disk, so multi-hundred-MB provider exports don't stall the app
- `get.php?...&type=...` links are normalized to `type=m3u_plus` automatically so logos and groups aren't missing
- A link that returns an Enigma2/Gigablue set-top-box bouquet (not an m3u) fails with a clear error instead of "no channels"
- Channel logos and groups depend on M3U metadata
- Local file-only playlists from older builds are not migrated — re-add via URL or the file picker
- Public GitHub playlists need the **raw** URL (`raw.githubusercontent.com/…`), not the `/blob/` page — or download the file and use the folder picker

## Related

- [IPTV — Xtream](iptv-xtream.md)
- [IPTV — Stalker](iptv-stalker.md)
- [Player](../playback/player.md)
