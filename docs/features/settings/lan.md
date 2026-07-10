# LAN server / client

**Status:** Settings → LAN (1.2.0 slice)

## Desktop (server)

1. Open **Settings → LAN**
2. Enable **LAN server**
3. Note the **6-digit pairing code** shown on screen

The desktop runs the Rust engine and relays torrent/proxy-heavy streams to paired devices on the same Wi‑Fi.

## Phone / tablet (client)

1. Open **Settings → LAN**
2. Tap **Discover** (mDNS) or enter the desktop **IP and port** manually
3. Enter the **pairing code** from the desktop
4. Tap **Pair**

After pairing, torrent and proxy-gated streams play via the desktop when it is online. Direct URLs (most WebStreamr / Stremio URL streams) still play on the device without the server.

## Android TV

Optional **Allow local torrent on this device** uses the on-box engine instead of the desktop when enabled.

## Security

LAN server is **off by default**. Only devices on your Wi‑Fi that know the pairing code (or an existing token) can access stream routes.

## Related

- [Stremio addons](../sources/stremio-addons.md)
- RFC-022 (LAN server/client)
