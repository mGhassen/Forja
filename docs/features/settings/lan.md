# LAN server / client

**Status:** Settings → LAN

## How to open it

**Settings → LAN**

## Once — pair (not per movie)

Pairing means **this TV trusts that desktop**. Do it once on the same Wi‑Fi.

### Desktop

1. **Settings → LAN → Enable LAN server**
2. Note the **desktop address** (`IP:port`) and the **6-digit pairing code**
3. Keep Forja running

Paired TVs and phones appear under **Paired devices**. **Revoke** forces that device to pair again.

### Android TV / phone

1. **Settings → LAN**
2. **Discover on Wi‑Fi**, or type the desktop **IP** and **port**
3. Enter the **6-digit code** from the desktop
4. **Pair with desktop**

Status shows **Paired · desktop online**. Unpair anytime from the same screen.

## Every night — watch

1. On the TV, open a title → **Sources → Torrents** (visible after pairing)
2. Pick a torrent
3. The TV asks the desktop to open the magnet; the desktop downloads; the TV plays the stream

You do not re-enter a code per title.

## Android TV — local torrent (optional)

**Allow local torrent on this device** uses the on-box engine instead of the desktop. Leave **off** for the normal LAN setup.

## Security

LAN server is **off by default**. Only devices that complete pairing (or already hold a device token) can call control APIs. Media URLs use a short-lived ticket (`?st=`).

## Related

- [Torrent playback](../playback/torrent-playback.md)
- [Stremio addons](../sources/stremio-addons.md)
- [Playback settings](playback-settings.md)
