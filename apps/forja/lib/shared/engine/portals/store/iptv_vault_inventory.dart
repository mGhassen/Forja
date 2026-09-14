import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/storage.dart';
import 'package:forja/shared/engine/vault/engine_vault.dart';

/// Pack vault keys for IPTV portal inventory (SoT on device after migrate).
abstract final class IptvVaultKeys {
  static const portals = 'iptv.portals';
  static const active = 'iptv.active';
  static const favorites = 'iptv.portalFavorites';
  static const migrateFlag = 'iptv.migratedFromIptvStore';
}

/// One-shot [IptvStore] → vault migrate + helpers for pack/sync dual-write.
abstract final class IptvVaultInventory {
  IptvVaultInventory._();

  static bool _migrateStarted = false;

  /// Idempotent: copy verified portals into vault when vault is empty.
  static Future<void> ensureMigratedFromStore() async {
    if (_migrateStarted) return;
    _migrateStarted = true;
    try {
      final flag = await EngineVault.get(IptvVaultKeys.migrateFlag);
      if (flag == '1') return;

      final existing = await EngineVault.get(IptvVaultKeys.portals);
      if (existing != null && existing.trim().isNotEmpty && existing != '[]') {
        await EngineVault.set(IptvVaultKeys.migrateFlag, '1');
        return;
      }

      final stored = await IptvStore.load();
      if (stored.isEmpty) {
        await EngineVault.set(IptvVaultKeys.migrateFlag, '1');
        return;
      }

      final rows = <Map<String, dynamic>>[
        for (final p in stored) _portalToVaultMap(p),
      ];
      await EngineVault.set(IptvVaultKeys.portals, jsonEncode(rows));

      final favs = await IptvStore.loadFavorites();
      if (favs.isNotEmpty) {
        await EngineVault.set(
          IptvVaultKeys.favorites,
          jsonEncode(favs.toList()),
        );
      }
      final last = await IptvStore.loadLastPortalKey();
      if (last != null && last.isNotEmpty) {
        await EngineVault.set(IptvVaultKeys.active, last);
      }
      await EngineVault.set(IptvVaultKeys.migrateFlag, '1');
      debugPrint(
        '[IptvVaultInventory] migrated ${rows.length} portals from IptvStore',
      );
    } catch (e, st) {
      debugPrint('[IptvVaultInventory] migrate failed: $e\n$st');
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
        IptvVaultKeys.portals,
        jsonEncode([for (final p in portals) _portalToVaultMap(p)]),
      );
      if (favoriteKeys != null) {
        await EngineVault.set(
          IptvVaultKeys.favorites,
          jsonEncode(favoriteKeys.toList()),
        );
      }
      if (activeKey != null) {
        if (activeKey.isEmpty) {
          await EngineVault.remove(IptvVaultKeys.active);
        } else {
          await EngineVault.set(IptvVaultKeys.active, activeKey);
        }
      }
    } catch (e) {
      debugPrint('[IptvVaultInventory] mirror failed: $e');
    }
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
