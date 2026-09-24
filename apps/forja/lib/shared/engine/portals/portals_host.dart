import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/network/portal_network.dart';
import 'package:forja/shared/engine/portals/share/portal_share.dart';
import 'package:forja/shared/engine/portals/store/portal_vault_inventory.dart';
import 'package:forja/shared/engine/portals/store/storage.dart';
import 'package:forja/shared/engine/runtime/meta/plugin_actions.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shared/sync/api/sync_service.dart';
import 'package:forja/shared/sync/bridge/sync_domain_bridge.dart';
import 'package:forja_foundation/components/form_fields_dialog.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';

/// Host portals API — pack actions + vault / share / probe / deal.
///
/// Paint stays in foundation (`PortalListView` / `PortalListRow` / `PortalsChip`).
/// Chrome wire maps these callables → props / callbacks.
abstract final class PortalsHost {
  PortalsHost._();

  /// Last pack `listPortals` panel chrome (actions / forms). Vault paints reuse it.
  static _PortalListChrome? _panelChrome;

  static DateTime? _lastPortalPanelPullAt;
  static Future<void>? _portalPanelPrepareInflight;

  /// Resolve a hub pack that declares `listPortals` (no pack-id allowlist).
  static Future<String?> resolvePluginId({String? preferTabId}) async {
    final tab = (preferTabId ?? '').trim();
    if (tab.isNotEmpty) {
      final fromTab = PluginNavRegistry.pluginIdForTabSync(tab);
      if (fromTab != null && fromTab.isNotEmpty) {
        final packs = await EngineService.instance.listPacks();
        for (final pack in packs) {
          for (final p in pack.plugins) {
            if (p.id == fromTab && p.hasCapability('listPortals')) {
              return p.id;
            }
          }
        }
      }
    }
    final packs = await EngineService.instance.listPacks();
    for (final pack in packs) {
      if (!pack.enabled) continue;
      for (final p in pack.plugins) {
        if (!p.enabled) continue;
        if (p.hasCapability('listPortals')) return p.id;
      }
    }
    return null;
  }

  /// Opaque pack action (`listPortals`, `selectPortal`, `addPortal`, …).
  ///
  /// After inventory mutations (add/edit/import), mirror vault → [PortalStore]
  /// and schedule cloud sync so web Profile → IPTV sees the same portals
  /// (issue 308 — pack writes vault only).
  static Future<MetaEnvelope> run({
    required String pluginId,
    required String action,
    Map<String, dynamic> params = const {},
  }) async {
    final env = await MetaRuntime.instance.run(
      pluginId: pluginId,
      action: action,
      params: params,
      forceRefresh: true,
    );
    if (env.ok && _actionMutatesPortalInventory(action)) {
      await mirrorVaultToStoreAndScheduleSync();
    }
    return env;
  }

  static bool _actionMutatesPortalInventory(String action) {
    final a = action.trim().toLowerCase();
    return a == 'addportal' ||
        a == 'editportal' ||
        a == 'importportal';
  }

  /// Vault → [PortalStore] → [scheduleIptvSyncPush] (issue 308).
  static Future<void> mirrorVaultToStoreAndScheduleSync({
    bool onlyIfStoreEmpty = false,
  }) =>
      PortalVaultInventory.mirrorVaultToStoreAndScheduleSync(
        onlyIfStoreEmpty: onlyIfStoreEmpty,
      );

  /// Top-bar chip label from vault only — never runs pack `listPortals`.
  ///
  /// Catalog feed and the closed Portals chip must not share the flutter_js
  /// queue with inventory. Panel open paints vault first; cloud soft-syncs.
  static Future<PortalsChipSummary> chipSummary() async {
    try {
      await PortalVaultInventory.ensureMigratedFromStore();
      final raw = await EngineVault.get(PortalVaultKeys.portals);
      if (raw == null || raw.trim().isEmpty || raw.trim() == '[]') {
        return const PortalsChipSummary(label: 'Portals', hasPortal: false);
      }
      final parsed = jsonDecode(raw);
      if (parsed is! List || parsed.isEmpty) {
        return const PortalsChipSummary(label: 'Portals', hasPortal: false);
      }

      final activeRaw = await EngineVault.get(PortalVaultKeys.active);
      final activeKey = (activeRaw ?? '').toString().trim();

      Map<String, dynamic>? hit;
      for (final e in parsed) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        if (activeKey.isNotEmpty &&
            samePortalKey(vaultPortalKey(m), activeKey)) {
          hit = m;
          break;
        }
      }
      if (hit == null) {
        return PortalsChipSummary(
          label: 'Portals',
          hasPortal: true,
        );
      }
      final key = vaultPortalKey(hit);
      final label = portalRowDisplayName(hit, key: key);
      final used = (hit['activeConnections'] ?? '').toString().trim();
      final max = (hit['maxConnections'] ?? '').toString().trim();
      return PortalsChipSummary(
        label: label.isEmpty ? 'Portals' : label,
        hasPortal: true,
        portalKey: key,
        seatsUsed: used.isEmpty ? null : used,
        seatsMax: max.isEmpty ? null : max,
      );
    } catch (_) {
      return const PortalsChipSummary(label: 'Portals', hasPortal: false);
    }
  }

  /// Instant panel paint from vault — no pack / flutter_js.
  ///
  /// Reuses cached pack chrome (actions/forms) from the last [list] call.
  static Future<PortalsInventory> listFromVault({String? preferTabId}) async {
    final pluginId = await resolvePluginId(preferTabId: preferTabId) ?? '';
    try {
      await PortalVaultInventory.ensureMigratedFromStore();
      final raw = await EngineVault.get(PortalVaultKeys.portals);
      final activeRaw = await EngineVault.get(PortalVaultKeys.active);
      final active = (activeRaw ?? '').toString().trim();
      final favs = await loadFavoriteKeys();
      final source = <Map<String, dynamic>>[];
      if (raw != null && raw.trim().isNotEmpty && raw.trim() != '[]') {
        final parsed = jsonDecode(raw);
        if (parsed is List) {
          for (final e in parsed) {
            if (e is! Map) continue;
            source.add(Map<String, dynamic>.from(e));
          }
        }
      }
      return _inventoryFromRows(
        source: source,
        active: active,
        pluginId: pluginId,
        favs: favs,
        chrome: _panelChrome,
      );
    } catch (e) {
      debugPrint('[PortalsHost] listFromVault failed: $e');
      return PortalsInventory(
        portals: const [],
        activeKey: '',
        pluginId: pluginId,
        title: _panelChrome?.title ?? '',
        actions: _panelChrome?.actions ?? const [],
        editForm: _panelChrome?.editForm,
        emptyTitle: _panelChrome?.emptyTitle ?? '',
        emptyDescription: _panelChrome?.emptyDescription ?? '',
        searchPlaceholder: _panelChrome?.searchPlaceholder ?? '',
        width: _panelChrome?.width ?? 380,
        rowHeight: _panelChrome?.rowHeight,
        titleFontSize: _panelChrome?.titleFontSize,
      );
    }
  }

  /// Inventory via pack `listPortals` — updates cached panel chrome.
  static Future<PortalsInventory> list({String? preferTabId}) async {
    final pluginId = await resolvePluginId(preferTabId: preferTabId);
    if (pluginId == null || pluginId.isEmpty) {
      return const PortalsInventory(
        portals: [],
        activeKey: '',
        pluginId: '',
      );
    }
    final env = await run(
      pluginId: pluginId,
      action: 'listPortals',
    );
    if (!env.ok) {
      return PortalsInventory(
        portals: const [],
        activeKey: '',
        pluginId: pluginId,
      );
    }
    final active = (env.data?['active'] ?? '').toString().trim();
    final chrome = _parsePortalListChrome(env.data);
    _panelChrome = chrome;
    final favs = await loadFavoriteKeys();

    final rawItems = env.data?['items'];
    final rawPortals = env.data?['portals'];
    final source = <Map<String, dynamic>>[];
    final preferred =
        rawItems is List && rawItems.isNotEmpty ? rawItems : rawPortals;
    if (preferred is List) {
      for (final e in preferred) {
        if (e is! Map) continue;
        source.add(Map<String, dynamic>.from(e));
      }
    }
    return _inventoryFromRows(
      source: source,
      active: active,
      pluginId: pluginId,
      favs: favs,
      chrome: chrome,
    );
  }

  /// Store → vault mirror. Keeps pack `url|user` active (never host password key).
  /// Never wipe vault with an empty store (cloud pull miss / race).
  /// Never clear `iptv.active` when the store cannot resolve the current key
  /// (select race with panel cloud prepare).
  static Future<void> _mirrorStoreToVault() async {
    final portals = await PortalStore.load();
    if (portals.isEmpty) return;
    final favs = await PortalStore.loadFavorites();
    final vaultActive =
        (await EngineVault.get(PortalVaultKeys.active) ?? '')
            .toString()
            .trim();
    final activePack = packActiveKeyAmong(vaultActive, portals);
    await PortalVaultInventory.mirrorFromStore(
      portals: portals,
      favoriteKeys: favs,
      activeKey: activePack.isNotEmpty ? activePack : null,
    );
  }

  /// Open-panel soft prepare — vault stays painted; cloud merge is async.
  ///
  /// Matches legacy `IptvController.preparePortalPanel`: throttle cloud pull,
  /// mirror store → vault, never wipe Live/Movies catalog.
  ///
  /// Issue 308: pack Add writes vault only — mirror vault → store + schedule
  /// push **before** pull so empty cloud cannot win over unsynced inventory.
  static Future<void> preparePortalPanel() async {
    final inflight = _portalPanelPrepareInflight;
    if (inflight != null) return inflight;

    // Completer first — async body can finish sync (throttle / no await) and
    // must not read an uninitialized `late` future in `finally`.
    final done = Completer<void>();
    final run = done.future;
    _portalPanelPrepareInflight = run;
    () async {
      try {
        if (SyncService.instance.isSignedIn) {
          // Heal vault-only portals into PortalStore before pull/flush.
          await mirrorVaultToStoreAndScheduleSync(onlyIfStoreEmpty: true);
          final now = DateTime.now();
          final recent = _lastPortalPanelPullAt != null &&
              now.difference(_lastPortalPanelPullAt!) <
                  const Duration(seconds: 3);
          if (!recent) {
            _lastPortalPanelPullAt = now;
            await SyncDomainBridge.instance.pullPortalsFromCloud();
            await _mirrorStoreToVault();
          }
        }
        if (!done.isCompleted) done.complete();
      } catch (e) {
        debugPrint('[PortalsHost] preparePortalPanel failed: $e');
        if (!done.isCompleted) done.complete();
      } finally {
        if (identical(_portalPanelPrepareInflight, run)) {
          _portalPanelPrepareInflight = null;
        }
      }
    }();
    return run;
  }

  static String inventoryFingerprint(PortalsInventory inv) {
    final keys = [
      for (final p in inv.portals)
        '${p.id}|${p.label}|${p.favorite}|${p.subtitle ?? ''}',
    ]..sort();
    return '${inv.activeKey}|${keys.join(';')}';
  }

  static PortalsInventory _inventoryFromRows({
    required List<Map<String, dynamic>> source,
    required String active,
    required String pluginId,
    required Set<String> favs,
    required _PortalListChrome? chrome,
  }) {
    final items = <PortalListItem>[];
    final formValues = <String, Map<String, String>>{};

    for (final m in source) {
      final key = (m['key'] ?? m['id'] ?? m['portalKey'] ?? '')
          .toString()
          .trim();
      final resolvedKey = key.isEmpty ? vaultPortalKey(m) : key;
      if (resolvedKey.isEmpty || resolvedKey == '|') continue;
      final label = portalRowDisplayName(m, key: resolvedKey);
      final storedRaw = _nonEmpty(m['label']);
      final storedLabel = storedRaw != null &&
              storedRaw.toLowerCase() != resolvedKey.toLowerCase()
          ? storedRaw
          : '';
      final url = (m['url'] ?? m['subtitle'] ?? m['description'] ?? '')
          .toString()
          .trim();
      final platform = (m['platform'] ?? m['badge'] ?? '').toString().trim();
      final activeConn = m['activeConnections']?.toString();
      final maxConn = m['maxConnections']?.toString();
      final expiryRaw = m['expiry']?.toString();
      final expiryFmt = PortalExpiry.format(expiryRaw);
      final selectedFlag = m['selected'];
      items.add(
        PortalListItem(
          id: resolvedKey,
          label: label,
          subtitle: url.isEmpty ? null : url,
          selected: samePortalKey(resolvedKey, active) ||
              selectedFlag == true ||
              selectedFlag == 1 ||
              selectedFlag?.toString().toLowerCase() == 'true',
          platformLabel: platformLabel(platform),
          expiry: PortalExpiry.isUnknown(expiryFmt) ? null : expiryFmt,
          activeConnections: _seatField(activeConn),
          maxConnections: _seatField(maxConn),
          favorite: favs.contains(resolvedKey),
        ),
      );
      final fv = m['formValues'];
      if (fv is Map) {
        formValues[resolvedKey] = {
          for (final entry in fv.entries)
            entry.key.toString(): entry.value?.toString() ?? '',
        };
      } else {
        final user = (m['username'] ?? '').toString();
        formValues[resolvedKey] = {
          'url': url,
          if (user.isNotEmpty) 'username': user,
          'label': storedLabel,
        };
      }
    }
    items.sort((a, b) {
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      return 0;
    });
    return PortalsInventory(
      portals: items,
      activeKey: active,
      pluginId: pluginId,
      title: chrome?.title ?? '',
      actions: chrome?.actions ?? const [],
      editForm: chrome?.editForm,
      formValues: formValues,
      emptyTitle: chrome?.emptyTitle ?? '',
      emptyDescription: chrome?.emptyDescription ?? '',
      searchPlaceholder: chrome?.searchPlaceholder ?? '',
      width: chrome?.width ?? 380,
      rowHeight: chrome?.rowHeight,
      titleFontSize: chrome?.titleFontSize,
    );
  }

  static FormFieldsSpec? formFromActionMap(Map<String, dynamic> a) {
    final formRaw = a['form'];
    if (formRaw is! Map) return null;
    final merged = Map<String, dynamic>.from(formRaw);
    if ((merged['action'] ?? '').toString().trim().isEmpty) {
      merged['action'] = (a['action'] ?? '').toString();
    }
    return FormFieldsSpec.fromJson(merged);
  }

  static _PortalListChrome _parsePortalListChrome(Map<String, dynamic>? data) {
    const empty = _PortalListChrome(
      title: '',
      actions: <PortalsPanelAction>[],
      editForm: null,
      emptyTitle: '',
      emptyDescription: '',
      searchPlaceholder: '',
      width: 380.0,
    );
    final layout = data?['layout'];
    if (layout is! Map) return empty;
    final widgets = layout['widgets'];
    if (widgets is! List) return empty;
    Map<String, dynamic>? panel;
    for (final w in widgets) {
      if (w is! Map) continue;
      final m = Map<String, dynamic>.from(w);
      final type = (m['type'] ?? '').toString();
      if (type == 'portalList' || (m['id'] ?? '').toString() == 'portals') {
        panel = m;
        break;
      }
    }
    if (panel == null) return empty;
    final title = (panel['title'] ?? '').toString().trim();
    final actions = <PortalsPanelAction>[];
    final rawActions = panel['actions'];
    if (rawActions is List) {
      for (final e in rawActions) {
        if (e is! Map) continue;
        final a = Map<String, dynamic>.from(e);
        final id = (a['id'] ?? '').toString().trim();
        final action = (a['action'] ?? id).toString().trim();
        if (id.isEmpty || action.isEmpty) continue;
        actions.add(
          PortalsPanelAction(
            id: id,
            label: (a['label'] ?? id).toString(),
            action: action,
            icon: (a['icon'] ?? '').toString(),
            form: formFromActionMap(a),
          ),
        );
      }
    }
    FormFieldsSpec? editForm;
    final itemActions = panel['itemActions'];
    if (itemActions is Map) {
      final edit = itemActions['edit'];
      if (edit is Map) {
        editForm = formFromActionMap(Map<String, dynamic>.from(edit));
      }
    }
    final panelMap = panel;
    final widthRaw = panelMap['width'];
    final width = widthRaw is num
        ? widthRaw.toDouble()
        : double.tryParse('$widthRaw') ?? 380.0;
    double? opt(String key) {
      final v = panelMap[key];
      return v is num ? v.toDouble() : null;
    }
    return _PortalListChrome(
      title: title,
      actions: actions,
      editForm: editForm,
      emptyTitle: (panelMap['emptyTitle'] ?? '').toString().trim(),
      emptyDescription: (panelMap['emptyDescription'] ?? '').toString().trim(),
      searchPlaceholder: (panelMap['searchPlaceholder'] ?? '').toString().trim(),
      width: width > 0 ? width : 380.0,
      rowHeight: opt('rowHeight'),
      titleFontSize: opt('titleFontSize'),
    );
  }

  static Future<MetaEnvelope> select({
    required String pluginId,
    required String key,
  }) =>
      run(
        pluginId: pluginId,
        action: 'selectPortal',
        params: {'key': key},
      );

  /// Instant active portal — vault only, no flutter_js.
  ///
  /// Panel selection / chip must not wait on pack `selectPortal` or catalog feed.
  /// Writes pack `url|username` form so list rows / chip match.
  static Future<void> setActiveKey(String key) async {
    final k = key.trim();
    await PortalVaultInventory.ensureMigratedFromStore();
    if (k.isEmpty) {
      await EngineVault.remove(PortalVaultKeys.active);
      await PortalStore.clearLastPortalKey();
      return;
    }
    // Normalize legacy host keys → pack form when possible.
    final portals = await PortalStore.load();
    final pack = packActiveKeyAmong(k, portals);
    final out = pack.isNotEmpty ? pack : k;
    await EngineVault.set(PortalVaultKeys.active, out);
    // Keep store last-key in sync for sync/migrate paths (prefer pack form).
    await PortalStore.saveLastPortalKey(out);
  }

  static Future<MetaEnvelope> remove({
    required String pluginId,
    required String key,
  }) async {
    final before =
        (await EngineVault.get(PortalVaultKeys.active) ?? '').toString().trim();
    final env = await run(
      pluginId: pluginId,
      action: 'removePortal',
      params: {'key': key},
    );
    if (!env.ok) return env;

    if (before.isNotEmpty && samePortalKey(before, key)) {
      // Pack clears vault active; keep store last-key in sync (no fallback).
      await PortalStore.clearLastPortalKey();
    }

    // Pre-pack contract (iptv_controller deleteSelected): vault already updated;
    // mirror → PortalStore then async intentional-delete push. Do not use
    // scheduleIptvSyncPush — that path refuses shrink (issue 118).
    try {
      final keep = await _vaultPortalsExact();
      await PortalStore.save(keep, scheduleSync: false);
      final favs = await PortalStore.loadFavorites();
      final nextFavs = {
        for (final f in favs)
          if (!samePortalKey(f, key)) f,
      };
      if (nextFavs.length != favs.length) {
        await PortalStore.saveFavorites(nextFavs, scheduleSync: false);
      }
      PortalStore.notifyListChanged();
      if (keep.isEmpty) {
        unawaited(SyncDomainBridge.instance.pushEmptyIptvInventory());
      } else {
        unawaited(SyncDomainBridge.instance.pushIptvInventoryAfterDelete());
      }
    } catch (e) {
      debugPrint('[PortalsHost] remove cloud sync failed: $e');
    }
    return env;
  }

  /// Vault inventory with no PortalStore fallback — empty vault means empty.
  static Future<List<VerifiedPortal>> _vaultPortalsExact() async {
    try {
      final raw = await EngineVault.get(PortalVaultKeys.portals);
      if (raw == null || raw.trim().isEmpty || raw.trim() == '[]') {
        return const [];
      }
      final parsed = jsonDecode(raw);
      if (parsed is! List) return const [];
      final out = <VerifiedPortal>[];
      final seen = <String>{};
      for (final e in parsed) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final portal = Portal.fromJson(m);
        if (portal.url.trim().isEmpty) continue;
        final k = vaultPortalKey(m);
        if (k.isEmpty || !seen.add(k)) continue;
        final storedLabel = _nonEmpty(m['label']);
        final label = storedLabel != null &&
                storedLabel.toLowerCase() != k.toLowerCase()
            ? storedLabel
            : '';
        out.add(
          VerifiedPortal(
            portal: portal,
            label: label,
            name: (m['name'] ?? portal.username).toString(),
            expiry: (m['expiry'] ?? '').toString(),
            maxConnections: (m['maxConnections'] ?? m['max'] ?? '1').toString(),
            activeConnections:
                (m['activeConnections'] ?? m['active'] ?? '0').toString(),
          ),
        );
      }
      return out;
    } catch (e) {
      debugPrint('[PortalsHost] _vaultPortalsExact failed: $e');
      return const [];
    }
  }

  static Future<Set<String>> loadFavoriteKeys() async {
    try {
      final raw = await EngineVault.get(PortalVaultKeys.favorites);
      if (raw == null || raw.trim().isEmpty) return {};
      final parsed = jsonDecode(raw);
      if (parsed is! List) return {};
      return {
        for (final e in parsed)
          if (e != null && e.toString().trim().isNotEmpty) e.toString().trim(),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveFavoriteKeys(Set<String> keys) async {
    await EngineVault.set(
      PortalVaultKeys.favorites,
      jsonEncode(keys.toList()),
    );
  }

  /// Returns the new favorite state (`true` = starred).
  static Future<bool> toggleFavorite(String portalKey) async {
    final favs = await loadFavoriteKeys();
    if (favs.contains(portalKey)) {
      favs.remove(portalKey);
      await saveFavoriteKeys(favs);
      unawaited(mirrorVaultToStoreAndScheduleSync());
      return false;
    }
    favs.add(portalKey);
    await saveFavoriteKeys(favs);
    unawaited(mirrorVaultToStoreAndScheduleSync());
    return true;
  }

  static String vaultPortalKey(Map<String, dynamic> m) {
    final explicit = (m['key'] ?? '').toString().trim();
    if (explicit.isNotEmpty) return explicit;
    final url = (m['url'] ?? '').toString().trim().toLowerCase();
    final user = (m['username'] ?? '').toString().trim().toLowerCase();
    return '$url|$user';
  }

  /// Panel / chip title: portal name if set, else username — never `url|user`.
  static String portalRowDisplayName(
    Map<String, dynamic> m, {
    String? key,
  }) {
    final resolvedKey = (key ?? vaultPortalKey(m)).trim();
    final label = _nonEmpty(m['label']);
    if (label != null &&
        label.toLowerCase() != resolvedKey.toLowerCase()) {
      return label;
    }
    final name = _nonEmpty(m['name']) ?? _nonEmpty(m['title']);
    if (name != null &&
        name.toLowerCase() != resolvedKey.toLowerCase()) {
      return name;
    }
    final user = _nonEmpty(m['username']);
    if (user != null) return user;
    return 'Portal';
  }

  static String? _nonEmpty(Object? v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Pack / vault active key form: `url|username` (not host `Portal.key`).
  static String packPortalKey(Portal p) =>
      '${p.url.trim().toLowerCase()}|${p.username.trim().toLowerCase()}';

  /// Match pack `url|user`, legacy `platform|url|user|pass`, or cred keys.
  static bool samePortalKey(String a, String b) {
    final x = a.trim().toLowerCase();
    final y = b.trim().toLowerCase();
    if (x.isEmpty || y.isEmpty) return false;
    if (x == y) return true;
    String packForm(String raw) {
      final parts = raw.split('|');
      if (parts.length >= 4) {
        // platform|url|user|pass
        return '${parts[1]}|${parts[2]}';
      }
      if (parts.length >= 2) return '${parts[0]}|${parts[1]}';
      return raw;
    }
    final px = packForm(x);
    final py = packForm(y);
    if (px.isEmpty || py.isEmpty || px == '|' || py == '|') return false;
    return px == py;
  }

  /// Resolve a vault/store active string to pack `url|user` against [portals].
  static String packActiveKeyAmong(
    String rawActive,
    List<VerifiedPortal> portals,
  ) {
    final raw = rawActive.trim();
    if (raw.isEmpty) return '';
    for (final p in portals) {
      final pack = packPortalKey(p.portal);
      if (samePortalKey(raw, pack) ||
          samePortalKey(raw, p.key) ||
          samePortalKey(raw, p.credKey)) {
        return pack;
      }
    }
    // Already pack-shaped even if portal list drifted.
    final parts = raw.toLowerCase().split('|');
    if (parts.length == 2 && parts[0].isNotEmpty) return '${parts[0]}|${parts[1]}';
    return '';
  }

  static Future<Portal?> loadVaultPortal(String portalKey) async {
    try {
      final raw = await EngineVault.get(PortalVaultKeys.portals);
      if (raw == null || raw.trim().isEmpty) return null;
      final parsed = jsonDecode(raw);
      if (parsed is! List) return null;
      for (final e in parsed) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        if (!samePortalKey(vaultPortalKey(m), portalKey)) continue;
        return Portal.fromJson(m);
      }
    } catch (_) {}
    return null;
  }

  /// Vault portals as [VerifiedPortal] for EPG / playback host paint.
  ///
  /// Pack writes vault only — [PortalStore] alone misses Add/Import portals.
  static Future<List<VerifiedPortal>> loadVaultVerifiedPortals() async {
    try {
      await PortalVaultInventory.ensureMigratedFromStore();
      final raw = await EngineVault.get(PortalVaultKeys.portals);
      if (raw == null || raw.trim().isEmpty || raw.trim() == '[]') {
        return PortalStore.load();
      }
      final parsed = jsonDecode(raw);
      if (parsed is! List) return PortalStore.load();
      final out = <VerifiedPortal>[];
      final seen = <String>{};
      for (final e in parsed) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final portal = Portal.fromJson(m);
        if (portal.url.trim().isEmpty) continue;
        final key = vaultPortalKey(m);
        if (key.isEmpty || !seen.add(key)) continue;
        final storedLabel = _nonEmpty(m['label']);
        final label = storedLabel != null &&
                storedLabel.toLowerCase() != key.toLowerCase()
            ? storedLabel
            : '';
        final name = (m['name'] ?? portal.username).toString();
        out.add(
          VerifiedPortal(
            portal: portal,
            label: label,
            name: name,
            expiry: (m['expiry'] ?? '').toString(),
            maxConnections: (m['maxConnections'] ?? m['max'] ?? '1').toString(),
            activeConnections:
                (m['activeConnections'] ?? m['active'] ?? '0').toString(),
          ),
        );
      }
      if (out.isNotEmpty) return out;
      return PortalStore.load();
    } catch (e) {
      debugPrint('[PortalsHost] loadVaultVerifiedPortals failed: $e');
      return PortalStore.load();
    }
  }

  /// Login/health probe for a vault portal key.
  static Future<PortalProbeResult> probe(String portalKey) async {
    final portal = await loadVaultPortal(portalKey);
    if (portal == null) {
      return const PortalProbeResult(alive: false, errorKind: 'transport');
    }
    try {
      return await PortalClient.probePortal(
        portal,
        timeout: portal.platform == PortalPlatform.m3u
            ? const Duration(seconds: 90)
            : const Duration(seconds: 15),
      );
    } catch (_) {
      return const PortalProbeResult(alive: false, errorKind: 'transport');
    }
  }

  /// 8-char / embedded share code for a vault portal. Null on failure.
  static Future<String?> createShareCode(String portalKey) async {
    try {
      final portal = await loadVaultPortal(portalKey);
      if (portal == null) return null;
      final code = await PortalShare.createShare(portal);
      return PortalShare.formatCode(code);
    } catch (e) {
      debugPrint('[PortalsHost] share code failed: $e');
      return null;
    }
  }

  /// Deal catalog portals into the active profile, then pull into local vault.
  ///
  /// [ids] — cloud assignment UUIDs (empty = pool empty / none dealt).
  /// [synced] — false when RPC assigned portals but local list could not refresh
  /// (dirty inventory / credential pull failure). Credit still burned.
  static Future<({List<String> ids, bool synced})> deal({
    required String profileId,
  }) async {
    final ids = await SyncService.instance.dealPortals(profileId: profileId);
    try {
      await SyncService.instance.pullAccountFeatures(force: true);
    } catch (e) {
      debugPrint('[PortalsHost] deal credits refresh failed: $e');
    }
    if (ids.isEmpty) return (ids: ids, synced: true);

    // Cloud is ahead of local — do not let the 3s panel throttle skip this.
    final ok = await SyncDomainBridge.instance.pullPortalsFromCloud(
      cloudIsSource: true,
    );
    if (!ok) {
      debugPrint(
        '[PortalsHost] deal assigned ${ids.length} but local pull failed',
      );
      return (ids: ids, synced: false);
    }
    await _mirrorStoreToVault();
    _lastPortalPanelPullAt = DateTime.now();
    return (ids: ids, synced: true);
  }

  static String? platformLabel(String raw) {
    final p = raw.trim().toLowerCase();
    if (p.isEmpty) return null;
    return switch (p) {
      'xtream' => 'Xtream',
      'm3u' || 'm3u8' => 'M3U',
      'stalker' || 'mag' => 'Stalker',
      _ => raw.trim(),
    };
  }

  /// Paint-ready seat count — drop nullish JS strings; prefer int form.
  static String? _seatField(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty || s == 'null' || s == 'undefined') return null;
    final asInt = int.tryParse(s) ?? double.tryParse(s)?.round();
    if (asInt != null) return '$asInt';
    return s;
  }
}

class PortalsPanelAction {
  const PortalsPanelAction({
    required this.id,
    required this.label,
    required this.action,
    this.icon = '',
    this.form,
  });

  final String id;
  final String label;
  final String action;
  final String icon;
  final FormFieldsSpec? form;
}

class _PortalListChrome {
  const _PortalListChrome({
    required this.title,
    required this.actions,
    required this.editForm,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.searchPlaceholder,
    required this.width,
    this.rowHeight,
    this.titleFontSize,
  });

  final String title;
  final List<PortalsPanelAction> actions;
  final FormFieldsSpec? editForm;
  final String emptyTitle;
  final String emptyDescription;
  final String searchPlaceholder;
  final double width;
  final double? rowHeight;
  final double? titleFontSize;
}

/// Closed Portals chip paint — vault-only, no pack round-trip.
class PortalsChipSummary {
  const PortalsChipSummary({
    required this.label,
    required this.hasPortal,
    this.portalKey = '',
    this.seatsUsed,
    this.seatsMax,
  });

  final String label;
  final bool hasPortal;

  /// Vault / pack portal key for hover health probe.
  final String portalKey;
  final String? seatsUsed;
  final String? seatsMax;
}

/// Inventory DTO for foundation paint + pack-declared panel chrome/forms.
class PortalsInventory {
  const PortalsInventory({
    required this.portals,
    required this.activeKey,
    required this.pluginId,
    this.title = '',
    this.actions = const [],
    this.editForm,
    this.formValues = const {},
    this.emptyTitle = '',
    this.emptyDescription = '',
    this.searchPlaceholder = '',
    this.width = 380,
    this.rowHeight,
    this.titleFontSize,
  });

  final List<PortalListItem> portals;
  final String activeKey;
  final String pluginId;
  final String title;
  final List<PortalsPanelAction> actions;
  final FormFieldsSpec? editForm;

  /// Opaque field values by portal key (from pack `formValues`).
  final Map<String, Map<String, String>> formValues;

  final String emptyTitle;
  final String emptyDescription;
  final String searchPlaceholder;
  final double width;
  final double? rowHeight;
  final double? titleFontSize;

  String get activeLabel {
    for (final p in portals) {
      if (PortalsHost.samePortalKey(p.id, activeKey)) return p.label;
    }
    final t = title.trim();
    return t.isEmpty ? 'Portals' : t;
  }
}

/// Debounced health probe — shared TTL cache across chip + panel.
///
/// Callers: hub-open chip preload ([immediate]), hover/focus dwell,
/// Refresh ([force]). Chip tap must not probe. Fresh results skip re-probe
/// until [ttl] expires or [invalidate]. UI owns one instance; call [dispose]
/// from the widget.
///
/// Panel rows subscribe via [listenableFor] so one probe does not
/// `setState` the whole inventory. Chip may still use [onChanged].
class PortalHealthTracker {
  PortalHealthTracker({this.onChanged}) {
    _listeners.add(this);
  }

  final VoidCallback? onChanged;

  static final Set<PortalHealthTracker> _listeners = {};

  /// Shared so chip + panel paint the same result and Refresh clears both.
  static final Map<String, bool?> _health = {};
  static final Map<String, DateTime> _probedAt = {};
  static final Map<String, String> _probeExpiry = {};
  static final Map<String, String> _probeActive = {};
  static final Map<String, String> _probeMax = {};
  static final Map<String, PortalProbeResult> _probes = {};
  static final Set<String> _inFlight = {};
  static final Map<String, Timer> _debounce = {};
  static final Map<String, ValueNotifier<int>> _ticks = {};

  static const ttl = Duration(minutes: 2);
  static const hoverDelay = Duration(milliseconds: 500);
  static const tvDelay = Duration(seconds: 2);

  /// Per-portal tick — panel rows rebuild from [paint] without a panel setState.
  ValueListenable<int> listenableFor(String portalKey) {
    final key = portalKey.trim();
    return _ticks.putIfAbsent(key, () => ValueNotifier(0));
  }

  static void _publishKey(String portalKey) {
    final n = _ticks[portalKey];
    if (n != null) n.value++;
  }

  static void _notify() {
    for (final t in _listeners) {
      t.onChanged?.call();
    }
  }

  static void _publishKeyAndNotify(String portalKey) {
    _publishKey(portalKey);
    _notify();
  }

  static bool _isFresh(String portalKey) {
    if (!_health.containsKey(portalKey)) return false;
    final at = _probedAt[portalKey];
    if (at == null) return false;
    return DateTime.now().difference(at) < ttl;
  }

  bool isChecking(String portalKey) => _inFlight.contains(portalKey);

  /// Schedule a probe after hover debounce. No-op while TTL is fresh unless
  /// [force] (hover soft-refresh / Refresh).
  ///
  /// Does **not** clear last painted health — UI keeps green/red until the
  /// new result lands. [force] ignores TTL; [immediate] starts now (else
  /// [hoverDelay] / [tvDelay] dwell — no spinner until the probe actually
  /// runs). Hub-open preload uses [immediate] only (TTL still applies).
  void schedule(
    String portalKey, {
    required bool leanback,
    bool force = false,
    bool immediate = false,
  }) {
    if (portalKey.isEmpty) return;
    if (_inFlight.contains(portalKey)) return;
    if (!force && _isFresh(portalKey)) return;
    cancel(portalKey);
    if (immediate) {
      unawaited(_run(portalKey));
      return;
    }
    _debounce[portalKey] = Timer(
      leanback ? tvDelay : hoverDelay,
      () {
        _debounce.remove(portalKey);
        unawaited(_run(portalKey));
      },
    );
  }

  void cancel(String portalKey) {
    _debounce[portalKey]?.cancel();
    _debounce.remove(portalKey);
  }

  /// Drop cached health (all keys, or one). Next hover re-probes.
  void invalidate([String? portalKey]) {
    final key = portalKey?.trim() ?? '';
    if (key.isEmpty) {
      for (final t in _debounce.values) {
        t.cancel();
      }
      _debounce.clear();
      _inFlight.clear();
      _health.clear();
      _probedAt.clear();
      _probeExpiry.clear();
      _probeActive.clear();
      _probeMax.clear();
      _probes.clear();
      for (final n in _ticks.values) {
        n.value++;
      }
    } else {
      cancel(key);
      _inFlight.remove(key);
      _health.remove(key);
      _probedAt.remove(key);
      _probeExpiry.remove(key);
      _probeActive.remove(key);
      _probeMax.remove(key);
      _probes.remove(key);
      _publishKey(key);
    }
    _notify();
  }

  Future<void> _run(String portalKey) async {
    if (!_inFlight.add(portalKey)) return;
    _publishKeyAndNotify(portalKey);
    try {
      final probe = await PortalsHost.probe(portalKey);
      _health[portalKey] = probe.alive;
      _probes[portalKey] = probe;
      _probedAt[portalKey] = DateTime.now();
      // Probe miss: keep vault scrape date with `*` (paint merges in [paint]).
      if (PortalExpiry.isUnknown(probe.expiry)) {
        _probeExpiry[portalKey] = '*';
      } else {
        _probeExpiry[portalKey] = PortalExpiry.format(probe.expiry);
      }
      if (probe.activeConnections.trim().isNotEmpty) {
        _probeActive[portalKey] =
            PortalsHost._seatField(probe.activeConnections) ??
                probe.activeConnections.trim();
      }
      if (probe.maxConnections.trim().isNotEmpty) {
        _probeMax[portalKey] =
            PortalsHost._seatField(probe.maxConnections) ??
                probe.maxConnections.trim();
      }
    } finally {
      _inFlight.remove(portalKey);
      _publishKeyAndNotify(portalKey);
    }
  }

  bool? healthFor(String portalKey) => _health[portalKey];

  PortalProbeResult? probeFor(String portalKey) => _probes[portalKey];

  String? seatsActiveFor(String portalKey) => _probeActive[portalKey];

  String? seatsMaxFor(String portalKey) => _probeMax[portalKey];

  static String? _portsLine(PortalServerInfo server) {
    final ports = <String>[
      if (server.port.isNotEmpty) server.port,
      if (server.httpsPort.isNotEmpty) 'https ${server.httpsPort}',
      if (server.rtmpPort.isNotEmpty) 'rtmp ${server.rtmpPort}',
    ];
    if (ports.isEmpty) return null;
    return ports.join(' · ');
  }

  static PortalProbeDetail? _detailFor(PortalProbeResult? probe) {
    if (probe == null) return null;
    final message = probe.message.trim();
    final protocol = probe.server.protocol.trim();
    final timezone = probe.server.timezone.trim();
    return PortalProbeDetail(
      statusLabel: probe.statusLabel,
      alive: probe.alive,
      message: message.isEmpty ? null : message,
      protocol: protocol.isEmpty ? null : protocol,
      ports: _portsLine(probe.server),
      timezone: timezone.isEmpty ? null : timezone,
    );
  }

  /// Merge probe state onto a list item for paint.
  PortalListItem paint(
    PortalListItem p, {
    bool deleting = false,
    bool? selected,
  }) {
    final checking = isChecking(p.id);
    final healthy = _health.containsKey(p.id) ? _health[p.id] : p.healthy;
    return PortalListItem(
      id: p.id,
      label: p.label,
      subtitle: p.subtitle,
      selected: selected ?? p.selected,
      healthy: healthy,
      checking: checking,
      platformLabel: p.platformLabel,
      expiry: _expiryForPaint(p),
      activeConnections: _probeActive[p.id] ?? p.activeConnections,
      maxConnections: _probeMax[p.id] ?? p.maxConnections,
      favorite: p.favorite,
      isNew: p.isNew,
      deleting: deleting,
      shelfLoading: p.shelfLoading,
      probeDetail: _detailFor(_probes[p.id]) ?? p.probeDetail,
    );
  }

  /// Confirmed probe date wins; probe miss keeps vault scrape as `date*`.
  String? _expiryForPaint(PortalListItem p) {
    final probed = _probeExpiry[p.id];
    if (probed == null) return p.expiry;
    if (PortalExpiry.isUnknown(probed)) {
      return PortalExpiry.mergeOnProbe(p.expiry ?? '', probed);
    }
    return probed;
  }

  void dispose() {
    _listeners.remove(this);
    if (_listeners.isEmpty) {
      for (final t in _debounce.values) {
        t.cancel();
      }
      _debounce.clear();
    }
  }
}
