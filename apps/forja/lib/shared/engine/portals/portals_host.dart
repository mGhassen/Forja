import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/network/portal_network.dart';
import 'package:forja/shared/engine/portals/share/portal_share.dart';
import 'package:forja/shared/engine/portals/store/portal_vault_inventory.dart';
import 'package:forja/shared/engine/runtime/meta/plugin_actions.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shared/sync/api/sync_service.dart';
import 'package:forja_foundation/components/form_fields_dialog.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';

/// Host portals API — pack actions + vault / share / probe / deal.
///
/// Paint stays in foundation (`PortalListPanel` / `PortalListRow` / `PortalsChip`).
/// Chrome wire maps these callables → props / callbacks.
abstract final class PortalsHost {
  PortalsHost._();

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
  static Future<MetaEnvelope> run({
    required String pluginId,
    required String action,
    Map<String, dynamic> params = const {},
  }) {
    return MetaRuntime.instance.run(
      pluginId: pluginId,
      action: action,
      params: params,
      forceRefresh: true,
    );
  }

  /// Top-bar chip label from vault only — never runs pack `listPortals`.
  ///
  /// Catalog feed and the closed Portals chip must not share the flutter_js
  /// queue with inventory. Full list loads when the panel opens.
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
      Map<String, dynamic>? first;
      for (final e in parsed) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        first ??= m;
        if (activeKey.isNotEmpty && vaultPortalKey(m) == activeKey) {
          hit = m;
          break;
        }
      }
      final row = hit ?? first;
      if (row == null) {
        return const PortalsChipSummary(label: 'Portals', hasPortal: false);
      }
      final label = (row['label'] ??
              row['name'] ??
              row['username'] ??
              row['url'] ??
              '')
          .toString()
          .trim();
      final key = vaultPortalKey(row);
      final used = (row['activeConnections'] ?? '').toString().trim();
      final max = (row['maxConnections'] ?? '').toString().trim();
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

  /// Inventory for paint — favorites sorted first + pack panel chrome/forms.
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
    final active = (env.data?['active'] ?? '').toString();
    final chrome = parsePortalListChrome(env.data);
    final favs = await loadFavoriteKeys();
    final items = <PortalListItem>[];
    final formValues = <String, Map<String, String>>{};

    final rawItems = env.data?['items'];
    final rawPortals = env.data?['portals'];
    final source = rawItems is List && rawItems.isNotEmpty
        ? rawItems
        : (rawPortals is List ? rawPortals : const []);

    for (final e in source) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final key = (m['key'] ?? m['id'] ?? m['portalKey'] ?? '')
          .toString()
          .trim();
      if (key.isEmpty) continue;
      final label = (m['label'] ??
              m['title'] ??
              m['name'] ??
              m['username'] ??
              key)
          .toString()
          .trim();
      final url = (m['url'] ?? m['subtitle'] ?? m['description'] ?? '')
          .toString()
          .trim();
      final platform = (m['platform'] ?? m['badge'] ?? '').toString().trim();
      final activeConn = m['activeConnections']?.toString();
      final maxConn = m['maxConnections']?.toString();
      final expiry = m['expiry']?.toString();
      items.add(
        PortalListItem(
          id: key,
          label: label.isEmpty ? key : label,
          subtitle: url.isEmpty ? null : url,
          selected: key == active || m['selected'] == true,
          platformLabel: platformLabel(platform),
          expiry: (expiry ?? '').trim().isEmpty ? null : expiry!.trim(),
          activeConnections: activeConn,
          maxConnections: maxConn,
          favorite: favs.contains(key),
        ),
      );
      final fv = m['formValues'];
      if (fv is Map) {
        formValues[key] = {
          for (final entry in fv.entries)
            entry.key.toString(): entry.value?.toString() ?? '',
        };
      } else {
        final user = (m['username'] ?? '').toString();
        formValues[key] = {
          'url': url,
          if (user.isNotEmpty) 'username': user,
          'label': label.isEmpty ? key : label,
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
      title: chrome.title,
      actions: chrome.actions,
      editForm: chrome.editForm,
      formValues: formValues,
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

  static ({
    String title,
    List<PortalsPanelAction> actions,
    FormFieldsSpec? editForm,
  }) parsePortalListChrome(Map<String, dynamic>? data) {
    final layout = data?['layout'];
    if (layout is! Map) {
      return (title: 'Portals', actions: const [], editForm: null);
    }
    final widgets = layout['widgets'];
    if (widgets is! List) {
      return (title: 'Portals', actions: const [], editForm: null);
    }
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
    if (panel == null) {
      return (title: 'Portals', actions: const [], editForm: null);
    }
    final title = (panel['title'] ?? 'Portals').toString().trim();
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
    return (
      title: title.isEmpty ? 'Portals' : title,
      actions: actions,
      editForm: editForm,
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

  static Future<MetaEnvelope> remove({
    required String pluginId,
    required String key,
  }) =>
      run(
        pluginId: pluginId,
        action: 'removePortal',
        params: {'key': key},
      );

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
      return false;
    }
    favs.add(portalKey);
    await saveFavoriteKeys(favs);
    return true;
  }

  static String vaultPortalKey(Map<String, dynamic> m) {
    final explicit = (m['key'] ?? '').toString().trim();
    if (explicit.isNotEmpty) return explicit;
    final url = (m['url'] ?? '').toString().trim().toLowerCase();
    final user = (m['username'] ?? '').toString().trim().toLowerCase();
    return '$url|$user';
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
        if (vaultPortalKey(m) != portalKey) continue;
        return Portal.fromJson(m);
      }
    } catch (_) {}
    return null;
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

  /// Deal catalog portals into the active profile. Empty list = none dealt.
  static Future<List<String>> deal({required String profileId}) {
    return SyncService.instance.dealPortals(profileId: profileId);
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
    this.title = 'Portals',
    this.actions = const [],
    this.editForm,
    this.formValues = const {},
  });

  final List<PortalListItem> portals;
  final String activeKey;
  final String pluginId;
  final String title;
  final List<PortalsPanelAction> actions;
  final FormFieldsSpec? editForm;

  /// Opaque field values by portal key (from pack `formValues`).
  final Map<String, Map<String, String>> formValues;

  String get activeLabel {
    for (final p in portals) {
      if (p.id == activeKey) return p.label;
    }
    return portals.isEmpty ? title : portals.first.label;
  }
}

/// Debounced hover/focus health probe session for a portals panel.
///
/// UI owns one instance; call [dispose] from the widget.
class PortalHealthTracker {
  PortalHealthTracker({this.onChanged});

  final VoidCallback? onChanged;

  final Map<String, bool?> _health = {};
  final Map<String, String> _probeExpiry = {};
  final Map<String, String> _probeActive = {};
  final Map<String, String> _probeMax = {};
  final Set<String> _inFlight = {};
  final Map<String, Timer> _debounce = {};

  static const hoverDelay = Duration(milliseconds: 350);
  static const tvDelay = Duration(seconds: 2);

  bool isChecking(String portalKey) =>
      _inFlight.contains(portalKey) || _debounce.containsKey(portalKey);

  void schedule(String portalKey, {required bool leanback}) {
    if (portalKey.isEmpty) return;
    if (_inFlight.contains(portalKey)) return;
    cancel(portalKey);
    onChanged?.call();
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

  Future<void> _run(String portalKey) async {
    if (!_inFlight.add(portalKey)) return;
    onChanged?.call();
    try {
      final probe = await PortalsHost.probe(portalKey);
      _health[portalKey] = probe.alive;
      if (probe.expiry.trim().isNotEmpty &&
          probe.expiry.toLowerCase() != 'unknown') {
        _probeExpiry[portalKey] = probe.expiry;
      }
      if (probe.activeConnections.trim().isNotEmpty) {
        _probeActive[portalKey] = probe.activeConnections;
      }
      if (probe.maxConnections.trim().isNotEmpty) {
        _probeMax[portalKey] = probe.maxConnections;
      }
    } finally {
      _inFlight.remove(portalKey);
      onChanged?.call();
    }
  }

  bool? healthFor(String portalKey) => _health[portalKey];

  String? seatsActiveFor(String portalKey) => _probeActive[portalKey];

  String? seatsMaxFor(String portalKey) => _probeMax[portalKey];

  /// Merge probe state onto a list item for paint.
  PortalListItem paint(PortalListItem p, {bool deleting = false}) {
    final checking = isChecking(p.id);
    final healthy = _health.containsKey(p.id) ? _health[p.id] : p.healthy;
    return PortalListItem(
      id: p.id,
      label: p.label,
      subtitle: p.subtitle,
      selected: p.selected,
      healthy: healthy,
      checking: checking,
      platformLabel: p.platformLabel,
      expiry: _probeExpiry[p.id] ?? p.expiry,
      activeConnections: _probeActive[p.id] ?? p.activeConnections,
      maxConnections: _probeMax[p.id] ?? p.maxConnections,
      favorite: p.favorite,
      isNew: p.isNew,
      deleting: deleting,
    );
  }

  void dispose() {
    for (final t in _debounce.values) {
      t.cancel();
    }
    _debounce.clear();
  }
}
