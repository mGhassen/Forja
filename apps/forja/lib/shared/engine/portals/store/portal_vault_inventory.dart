import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/store/storage.dart';
import 'package:forja/shared/engine/vault/engine_vault.dart';

/// Pack vault keys for IPTV portal inventory (SoT on device after migrate).
abstract final class PortalVaultKeys {
  static const portals = 'iptv.portals';
  static const active = 'iptv.active';
  static const favorites = 'iptv.portalFavorites';
  static const migrateFlag = 'iptv.migratedFromIptvStore';
}

/// One-shot [PortalStore] → vault migrate + helpers for pack/sync dual-write.
abstract final class PortalVaultInventory {
  PortalVaultInventory._();

  static bool _migrateStarted = false;

  /// Idempotent: copy verified portals into vault when vault is empty.
  static Future<void> ensureMigratedFromStore() async {
    if (_migrateStarted) return;
    _migrateStarted = true;
    try {
      final flag = await EngineVault.get(PortalVaultKeys.migrateFlag);
      if (flag == '1') return;

      final existing = await EngineVault.get(PortalVaultKeys.portals);
      if (existing != null && existing.trim().isNotEmpty && existing != '[]') {
        await EngineVault.set(PortalVaultKeys.migrateFlag, '1');
        return;
      }

      final stored = await PortalStore.load();
      if (stored.isEmpty) {
        await EngineVault.set(PortalVaultKeys.migrateFlag, '1');
        return;
      }

      final rows = <Map<String, dynamic>>[
        for (final p in stored) _portalToVaultMap(p),
      ];
      await EngineVault.set(PortalVaultKeys.portals, jsonEncode(rows));

      final favs = await PortalStore.loadFavorites();
      if (favs.isNotEmpty) {
        await EngineVault.set(
          PortalVaultKeys.favorites,
          jsonEncode(favs.toList()),
        );
      }
      final last = await PortalStore.loadLastPortalKey();
      if (last != null && last.isNotEmpty) {
        // Prefer pack `url|user` — never write host Portal.key into vault active.
        var activePack = '';
        for (final p in stored) {
          final pack =
              '${p.portal.url.trim().toLowerCase()}|${p.portal.username.trim().toLowerCase()}';
          final lastL = last.trim().toLowerCase();
          if (lastL == pack ||
              lastL == p.key.toLowerCase() ||
              lastL == p.credKey.toLowerCase()) {
            activePack = pack;
            break;
          }
          final parts = lastL.split('|');
          if (parts.length >= 4 &&
              parts[1] == p.portal.url.trim().toLowerCase() &&
              parts[2] == p.portal.username.trim().toLowerCase()) {
            activePack = pack;
            break;
          }
        }
        if (activePack.isNotEmpty) {
          await EngineVault.set(PortalVaultKeys.active, activePack);
        }
      }
      await EngineVault.set(PortalVaultKeys.migrateFlag, '1');
      debugPrint(
        '[PortalVaultInventory] migrated ${rows.length} portals from PortalStore',
      );
    } catch (e, st) {
      debugPrint('[PortalVaultInventory] migrate failed: $e\n$st');
      _migrateStarted = false;
    }
  }

  /// Dual-write vault after store save (until Portals Dart is deleted).
  static Future<void> mirrorFromStore({
    required List<VerifiedPortal> portals,
    Set<String>? favoriteKeys,
    String? activeKey,
  }) async {
    try {
      await EngineVault.set(
        PortalVaultKeys.portals,
        jsonEncode([for (final p in portals) _portalToVaultMap(p)]),
      );
      if (favoriteKeys != null) {
        await EngineVault.set(
          PortalVaultKeys.favorites,
          jsonEncode(favoriteKeys.toList()),
        );
      }
      if (activeKey != null) {
        if (activeKey.isEmpty) {
          await EngineVault.remove(PortalVaultKeys.active);
        } else {
          await EngineVault.set(PortalVaultKeys.active, activeKey);
        }
      }
    } catch (e) {
      debugPrint('[PortalVaultInventory] mirror failed: $e');
    }
  }

  /// Pack Add/Import write vault only — cloud push reads [PortalStore].
  ///
  /// Copy vault → store and schedule IPTV sync so web Addons → IPTV sees the
  /// same inventory (issue 308). No-op when vault is empty (delete uses a
  /// dedicated allow-shrink push).
  ///
  /// When [onlyIfStoreEmpty] is true (soft-pull / panel heal), skip if the
  /// store already has rows — avoid replacing a pulled cloud cache with a
  /// thinner vault before merge.
  static Future<void> mirrorVaultToStoreAndScheduleSync({
    bool onlyIfStoreEmpty = false,
  }) async {
    try {
      final portals = await loadVerifiedPortalsExact();
      if (portals.isEmpty) return;
      if (onlyIfStoreEmpty) {
        final store = await PortalStore.load();
        if (store.isNotEmpty) return;
      }
      final favs = await loadFavoriteKeys();
      await PortalStore.save(portals, scheduleSync: true);
      await PortalStore.saveFavorites(favs, scheduleSync: false);
      PortalStore.notifyListChanged();
      debugPrint(
        '[PortalVaultInventory] mirrored ${portals.length} vault '
        'portal(s) → store/sync',
      );
    } catch (e) {
      debugPrint(
        '[PortalVaultInventory] mirrorVaultToStoreAndScheduleSync failed: $e',
      );
    }
  }

  /// Vault inventory with no PortalStore fallback — empty vault means empty.
  static Future<List<VerifiedPortal>> loadVerifiedPortalsExact() async {
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
        final k = _vaultPortalKey(m);
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
      debugPrint('[PortalVaultInventory] loadVerifiedPortalsExact failed: $e');
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

  static String _vaultPortalKey(Map<String, dynamic> m) {
    final url = (m['url'] ?? '').toString().trim().toLowerCase();
    final user = (m['username'] ?? '').toString().trim().toLowerCase();
    if (url.isEmpty) return '';
    return '$url|$user';
  }

  static String? _nonEmpty(Object? v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  static Map<String, dynamic> _portalToVaultMap(VerifiedPortal p) {
    final portal = p.portal;
    return {
      'url': portal.url,
      'username': portal.username,
      'password': portal.password,
      'label': p.label,
      'name': p.name,
      'platform': portal.platform.wire,
      if (portal.userAgent.isNotEmpty) 'userAgent': portal.userAgent,
      'activeConnections': p.activeConnections,
      'maxConnections': p.maxConnections,
      'expiry': p.expiry,
    };
  }
}
