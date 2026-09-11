import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/host/kit/meta_runtime.dart';
import 'package:forja/shared/host/packs/services/pack_connected_auth_spec.dart';
import 'package:forja/shared/host/packs/services/pack_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Session secrets + profile label for pack Connected Services auth (RFC-102).
abstract final class PackConnectedAuthStore {
  PackConnectedAuthStore._();

  static const _labelPrefix = 'pack_auth_label_v1_';
  static const _secretIdsKeyPrefix = 'pack_auth_secret_ids_v1_';

  /// Well-known keys always merged into extract config when present.
  static const defaultSecretIds = <String>[
    'sessionId',
    'jwt',
    'email',
    'password',
    'phone',
  ];

  static String _labelKey(String pluginId) =>
      '$_labelPrefix${pluginId.trim()}';

  static String _secretIdsKey(String pluginId) =>
      '$_secretIdsKeyPrefix${pluginId.trim()}';

  static Future<String?> profileLabel(String pluginId) async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_labelKey(pluginId))?.trim() ?? '';
    return v.isEmpty ? null : v;
  }

  static Future<void> setProfileLabel(String pluginId, String? label) async {
    final prefs = await SharedPreferences.getInstance();
    final k = _labelKey(pluginId);
    final t = label?.trim() ?? '';
    if (t.isEmpty) {
      await prefs.remove(k);
    } else {
      await prefs.setString(k, t);
    }
  }

  static Future<List<String>> trackedSecretIds(String pluginId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_secretIdsKey(pluginId)) ?? const [];
    final out = <String>{...defaultSecretIds, ...raw};
    return out.toList();
  }

  static Future<void> _setTrackedSecretIds(
    String pluginId,
    Iterable<String> ids,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = [
      for (final id in ids)
        if (id.trim().isNotEmpty) id.trim(),
    ];
    await prefs.setStringList(_secretIdsKey(pluginId), cleaned);
  }

  static Future<void> applyLoginResult({
    required String pluginId,
    required Map<String, dynamic> data,
  }) async {
    final label = (data['label'] ?? data['email'] ?? '').toString().trim();
    await setProfileLabel(pluginId, label.isEmpty ? null : label);

    final secretsRaw = data['secrets'];
    final secrets = <String, String>{};
    if (secretsRaw is Map) {
      for (final e in secretsRaw.entries) {
        final k = e.key.toString().trim();
        final v = e.value?.toString() ?? '';
        if (k.isEmpty || v.trim().isEmpty) continue;
        secrets[k] = v.trim();
      }
    }
    // Flat session fields on data (pack convenience).
    for (final id in defaultSecretIds) {
      final v = data[id]?.toString().trim() ?? '';
      if (v.isNotEmpty) secrets[id] = v;
    }
    final configRaw = data['config'];
    if (configRaw is Map) {
      for (final e in configRaw.entries) {
        final k = e.key.toString().trim();
        final v = e.value?.toString() ?? '';
        if (k.isEmpty || v.trim().isEmpty) continue;
        if (defaultSecretIds.contains(k) || k == 'password') {
          secrets[k] = v.trim();
        } else {
          await PackSettingsStore.setString(pluginId, k, v.trim());
        }
      }
    }

    for (final e in secrets.entries) {
      await PackSettingsStore.setSecret(pluginId, e.key, e.value);
    }
    await _setTrackedSecretIds(pluginId, {
      ...await trackedSecretIds(pluginId),
      ...secrets.keys,
    });
  }

  static Future<void> clearSession(String pluginId) async {
    final ids = await trackedSecretIds(pluginId);
    for (final id in ids) {
      await PackSettingsStore.setSecret(pluginId, id, '');
    }
    await setProfileLabel(pluginId, null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_secretIdsKey(pluginId));
  }

  /// Overlay for extract / catalog config (session secrets + optional strings).
  static Future<Map<String, dynamic>> configOverlay(String pluginId) async {
    final out = <String, dynamic>{};
    for (final id in await trackedSecretIds(pluginId)) {
      final v = await PackSettingsStore.getSecret(pluginId, id);
      if (v.isNotEmpty) out[id] = v;
    }
    return out;
  }

  /// Merge auth overlays for an extract provider id (own plugin + hubs that
  /// list it in `extractPluginIds`).
  static Future<Map<String, dynamic>> loadExtractConfigOverlay({
    required String extractPluginId,
    required Iterable<EnginePlugin> plugins,
  }) async {
    final want = extractPluginId.trim();
    if (want.isEmpty) return const {};
    final out = <String, dynamic>{};
    for (final p in plugins) {
      if (!p.enabled) continue;
      final spec = PackConnectedAuthSpec.fromPlugin(p);
      final applies =
          p.id == want || (spec != null && spec.extractPluginIds.contains(want));
      if (!applies) continue;
      out.addAll(await configOverlay(spec?.pluginId ?? p.id));
    }
    return out;
  }
}

/// Runs pack auth kit actions (RFC-102).
abstract final class PackConnectedAuthService {
  PackConnectedAuthService._();

  static Future<MetaEnvelope> _run(
    String pluginId,
    String action, {
    Map<String, dynamic> params = const {},
  }) {
    return MetaRuntime.instance.run(
      pluginId: pluginId,
      action: action,
      params: params,
      forceRefresh: true,
      timeout: const Duration(seconds: 60),
    );
  }

  static Future<({bool connected, String? label})> status(
    PackConnectedAuthSpec spec,
  ) async {
    try {
      final env = await _run(spec.pluginId, 'auth_status');
      if (env.ok && env.data != null) {
        final connected = env.data!['connected'] == true;
        final label = (env.data!['label'] ?? '').toString().trim();
        if (connected) {
          return (
            connected: true,
            label: label.isNotEmpty
                ? label
                : await PackConnectedAuthStore.profileLabel(spec.pluginId),
          );
        }
      }
    } catch (e) {
      debugPrint('[PackAuth] auth_status ${spec.pluginId}: $e');
    }
    // Fall back to local session presence.
    final overlay =
        await PackConnectedAuthStore.configOverlay(spec.pluginId);
    final hasSession = (overlay['sessionId'] ?? '').toString().isNotEmpty ||
        (overlay['jwt'] ?? '').toString().isNotEmpty;
    return (
      connected: hasSession,
      label: await PackConnectedAuthStore.profileLabel(spec.pluginId),
    );
  }

  static Future<Map<String, dynamic>?> begin(PackConnectedAuthSpec spec) async {
    final env = await _run(spec.pluginId, 'auth_begin');
    if (!env.ok || env.data == null) {
      throw Exception(env.error?.message ?? 'auth_begin failed');
    }
    return env.data;
  }

  static Future<void> login(
    PackConnectedAuthSpec spec, {
    required String method,
    required Map<String, String> fields,
  }) async {
    final env = await _run(
      spec.pluginId,
      'auth_login',
      params: {
        'method': method,
        'fields': fields,
      },
    );
    if (!env.ok || env.data == null) {
      throw Exception(env.error?.message ?? 'Login failed');
    }
    if (env.data!['connected'] != true && env.data!['ok'] != true) {
      final msg = (env.data!['message'] ?? env.error?.message ?? 'Login failed')
          .toString();
      throw Exception(msg);
    }
    await PackConnectedAuthStore.applyLoginResult(
      pluginId: spec.pluginId,
      data: env.data!,
    );
  }

  static Future<void> logout(PackConnectedAuthSpec spec) async {
    try {
      await _run(spec.pluginId, 'auth_logout');
    } catch (e) {
      debugPrint('[PackAuth] auth_logout ${spec.pluginId}: $e');
    }
    await PackConnectedAuthStore.clearSession(spec.pluginId);
  }

  static Future<List<PackConnectedAuthSpec>> listEnabled() async {
    final packs = await PluginRegistry.instance.listPacksRaw();
    final plugins = [for (final p in packs) ...p.plugins];
    return PackConnectedAuthSpec.listEnabled(plugins);
  }
}
