# LAN server / client

**Status:** Settings → LAN

## How to open it

**Settings → LAN**

## Desktop (server)

1. Enable **LAN server**
2. Note the **6-digit pairing code** (refresh anytime)
3. Keep Forja running on the same Wi‑Fi as your phone / Android TV

The desktop runs the Rust engine and relays torrent (and proxy-gated) streams to paired devices. Stream URLs use a short-lived ticket (`?st=`) so the player does not need an Authorization header.

## Phone / tablet / Android TV (client)

1. Tap **Discover** (mDNS) or enter the desktop **IP and port** manually
2. Enter the **pairing code** from the desktop
3. Tap **Pair**

After pairing, torrent and Stremio hash sources appear even on Android TV (local torrent engine stays off). Playback opens a desktop `play_url` over LAN. Direct URLs still play on the device without the server.

## Android TV — local torrent (optional)

**Allow local torrent on this device** (Settings → LAN) uses the on-box engine instead of the desktop when enabled. Default: use the paired desktop.

## Security

LAN server is **off by default**. Only devices that complete pairing (or already hold a device token) can call control APIs; media GETs need a valid stream ticket minted at open time.

## What you can do

- Start / stop the desktop LAN server
- Pair / unpair / revoke devices
- Discover servers without typing an IP (when mDNS works)
- Play magnets on TV/phone via the desktop when paired

## Related

- [Torrent playback](../playback/torrent-playback.md)
- [Stremio addons](../sources/stremio-addons.md)
- [Playback settings](playback-settings.md)
