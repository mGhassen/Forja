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

Paired TVs and phones appear under **Paired devices**. Use the **reload** icon if a device just paired and the list still says waiting. **Revoke** forces that device to pair again.

**Torrent activity** lists the torrent currently downloading/serving (when any) and a cached history of magnets opened by paired devices. Use the trash icon on a row to stop that download if it is active and delete its cached file. **Clear all** stops the engine torrent, wipes the torrent download cache, and clears history.

### Android TV / phone

1. **Settings → LAN**
2. **Discover on Wi‑Fi**, or type the desktop **IP** and **port**
3. Enter the **6-digit code** from the desktop
4. **Pair with desktop**

On Android TV, **OK** on a field opens the keyboard and the page scrolls so the field stays visible above it.

Status shows **Paired · desktop online**. Unpair anytime from the same screen.

## Every night — watch

1. On the TV, **Settings → Playback** → turn on **Direct torrent** (and **Stremio** / **Nuvio** if you want those)
2. Open a title → white **Play** / **Sources → Torrents**
3. Pick a torrent
4. The TV asks the desktop to open the magnet; the desktop downloads; the TV plays the stream

You do not re-enter a code per title. Unpair hides those Playback toggles again (Webstreaming stays). If the desktop goes **offline**, Direct torrent / Stremio / Nuvio turn off and stay disabled until it is online again — your previous checks come back automatically.

## Android TV — local torrent (optional)

**Allow local torrent on this device** uses the on-box engine instead of the desktop. Leave **off** for the normal LAN setup.

## Security

LAN server is **off by default**. Only devices that complete pairing (or already hold a device token) can call control APIs. Media URLs use a short-lived ticket (`?st=`).

## Related

- [Torrent playback](../playback/torrent-playback.md)
- [Stremio addons](../sources/stremio-addons.md)
- [Playback settings](playback-settings.md)
