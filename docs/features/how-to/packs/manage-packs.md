# Manage packs (enable, plugins, update, remove)

> Turn packs and plugins on/off, refresh scripts, or uninstall.

## Steps

1. **Enable / disable a pack:** **Settings → Forja Packs** → click / OK the **row** (not the chevron). Off packs leave Features / the rail and hide their settings.
2. **Per-plugin toggles:** open the **chevron**. Toggle Providers / Live / Hubs / Torrent / …. Plugins marked **Not available on this device** stay locked here.
3. **Update:** when a newer remote version exists, tap **Update** or **Update all**. After splash, an update toast may offer **Update** once per session.
4. **Reload:** with at least one pack fully installed, tap **Reload** to re-fetch every installed pack’s manifest + scripts from the network (does not reuse the on-device copy). Reopen hub tabs to pick up layout changes.
5. **Remove:** trash on the row → confirm. Drops hub tabs from Features / navbar and profile membership on the next cloud sync.
6. **Pending download:** tap **Download** / **Download all**. If a pending row still shows another device’s local path, Download fetches the official pack; trash drops a bad stub.
7. **Deprecated** (red name): remote manifest returned 404/410. On-disk scripts still run until you Remove and reinstall a replacement.

## Related

- [Install from a manifest URL](install-from-url.md)
- [Show or hide tabs](../home/show-hide-tabs.md)

## Reference

- [Forja Packs](../../settings/forja-packs.md)
