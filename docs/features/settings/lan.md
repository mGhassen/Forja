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

Paired TVs and phones appear under **Paired devices** with a per-device talk dot and a short line under the name: **Active** (green) = recent traffic; **Idle** (grey) = still trusted, not talking right now (the server is still up — another device can pair/play); **Playing** (green, pulsing) = that device is streaming a LAN torrent. Date and device id sit on their own lines below. Use the **reload** icon if a device just paired and the list still says waiting. **Revoke** forces that device to pair again.

The profile name on the nav rail uses a LAN mark: **desktop** (the server) shows **● |** — a **dot** (listening) then a bold **vertical bar** (session: amber pulse = waiting for a pair, green = paired, grey = idle, green pulse = playing). Idle greys only the bar — the server dot stays green so you can still connect. **Android TV / phone** (clients) show only the **dot**: green = desktop reachable, red = unreachable.

The desktop reuses the same LAN **port** across toggles and app restarts. If the IP still changes (or the sticky port is unavailable), a paired TV rediscovers this PC on Wi‑Fi (same server id) and updates the saved address — you do not re-enter the pairing code.

**Torrent activity** is one list: history of magnets opened by paired devices. An active download shows a progress bar, percent, status chip, speed, and peer count; device, date, and size sit as separate chips below (not one dotted line). Use the trash icon to stop an active download and delete its cached file. **Clear all** stops the engine torrent, wipes the torrent download cache, and clears history.

### Android TV / phone

1. **Settings → LAN**
2. **Discover on Wi‑Fi**, or type the desktop **IP** and **port**
3. Enter the **6-digit code** from the desktop
4. **Pair with desktop**

On Android TV, **OK** on a field opens the keyboard and the page scrolls so the field stays visible above it.

Status shows **Paired** with a status **dot**: green = desktop reachable, red = desktop down. The screen periodically re-checks the desktop (and rediscovers it if the port changed). Use the **reload** icon next to the status to re-check now (D-pad focusable on Android TV). Unpair anytime from the same screen. The TV nav profile name uses the same single dot.

## Every night — watch

1. On the TV, **Settings → Playback** → turn on **Direct torrent** (and **Stremio** / **Nuvio** if you want those)
2. Open a title → white **Play** / **Sources → Torrents**
3. Pick a torrent
4. The TV asks the desktop to open the magnet; the desktop downloads; the TV plays the stream
5. When you leave the player (or cancel before it opens), the desktop **stops that download** — cached files stay until you delete them under **Torrent activity**
6. If the TV goes **Idle** (no contact for ~2 minutes) while a torrent is still open, the desktop **pauses** the download; if the TV stays idle another ~2 minutes, the desktop **stops and deletes** that cached download (same as trash in Torrent activity). If the TV comes back during the pause window, download **resumes**

You do not re-enter a code per title. Direct HTTP Stremio/Nuvio streams still play on the TV when unpaired or when the desktop is offline. Magnets / torrents need the desktop — if you pick one while unpaired (or the desktop is offline), the TV shows a dialog with **Open LAN** on top and **Cancel** as text under it. **Open LAN** switches to Settings with **LAN** selected in the hub (category list + pane).

If you turn on Direct torrent / Stremio / Nuvio and have not acknowledged P2P on this TV, Forja shows the **P2P streaming** disclaimer in **Playback**. Cancel leaves that source off.

## Android TV — local torrent (optional)

**Allow local torrent on this device** uses the on-box engine instead of the desktop. Leave **off** for the normal LAN setup.

## Security

LAN server is **off by default**. Only devices that complete pairing (or already hold a device token) can call control APIs. Media URLs use a short-lived ticket (`?st=`).

## Related

- [Torrent playback](../playback/torrent-playback.md)
- [Stremio addons](../sources/stremio-addons.md)
- [Playback settings](playback-settings.md)
