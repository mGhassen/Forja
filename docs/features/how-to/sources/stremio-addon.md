# Add a Stremio addon and use it

> Install a Stremio manifest, target Sources or Live Sports, then play.

## Steps

1. Enable **Stremio** under **Settings → Addons**.
2. Open **Settings → Addons → Stremio** (chevron).
3. Paste a manifest URL (usually ends with `/manifest.json`, or copy from a configure page) → **Install**.
4. Set **Sources** and/or **Live Sports** chips (at least one stays on). Sport addons should target **Live Sports**.
5. Use the switch next to trash to disable without uninstalling.
6. **Play (VOD):** open a title → Sources → **Stremio** → pick the addon chip → tap a stream. Direct `url` streams play natively; `infoHash` uses local torrent or debrid when configured.
7. **Live Sports:** open Live Sports → **Catalog** lists the addon after install — pick it for that schedule.

## Tips

- On Android TV, hash/magnet Stremio rows need a paired desktop (LAN) unless debrid resolves them.
- If Torrentio 403s while another addon works, Sources may switch the chip to the one that returned streams.

## Related

- [Enable play sources](enable-play-sources.md)
- [Add debrid](debrid.md)
- [Watch Live Sports](../live/live-sports.md)

## Reference

- [Stremio addons](../../sources/stremio-addons.md)
