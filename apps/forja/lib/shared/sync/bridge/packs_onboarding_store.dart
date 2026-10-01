import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:forja/shared/sync/bridge/sync_domain_bridge.dart';
import 'package:forja/shared/sync/api/sync_service.dart';

/// Local cache + cloud sync for packs onboarding completion.
///
/// Signed-in: `connectedServices.forja.onboarded` (prefs keyed by user+profile).
/// Guest: device-local prefs only (`forja_packs_onboarded_guest`) — no cloud.
class PacksOnboardingStore {
  PacksOnboardingStore._();

  static const _prefsPrefix = 'forja_packs_onboarded_';
  static const _guestPrefsKey = 'forja_packs_onboarded_guest';

  static Future<String?> _prefsKeyForProfile(String profileId) async {
    final userId = SyncService.instance.session?.user.id.trim();
    if (userId == null || userId.isEmpty) return null;
    final id = profileId.trim();
    if (id.isEmpty) return null;
    return '$_prefsPrefix$userId:$id';
  }

  static Future<String?> _prefsKeyForActiveProfile() async {
    try {
      final profile = await SyncService.instance.activeProfile();
      final profileId = profile?.id.trim();
      if (profileId == null || profileId.isEmpty) return null;
      return _prefsKeyForProfile(profileId);
    } on SyncProfileFetchException catch (e) {
      debugPrint('[PacksOnboarding] activeProfile: $e');
      return null;
    }
  }

  static Future<String> _prefsKey({String? profileId}) async {
    if (!SyncService.instance.isSignedIn) return _guestPrefsKey;
    if (profileId != null && profileId.trim().isNotEmpty) {
      final signed = await _prefsKeyForProfile(profileId);
      return signed ?? _guestPrefsKey;
    }
    final signed = await _prefsKeyForActiveProfile();
    return signed ?? _guestPrefsKey;
  }

  /// Device-local onboarded bit (profile or guest).
  static Future<bool> isOnboardedLocal({String? profileId}) async {
    final key = await _prefsKey(profileId: profileId);
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) == true;
  }

  static Future<void> setOnboardedLocal(bool value, {String? profileId}) async {
    final key = await _prefsKey(profileId: profileId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  static Future<void> clearLocalForActiveProfile() async {
    final key = await _prefsKeyForActiveProfile();
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// Apply cloud `onboarded` into local prefs during Forja import.
  static Future<void> applyFromCloud(bool? onboarded) async {
    if (onboarded == true) {
      await setOnboardedLocal(true);
    }
  }

  /// True when the packs wizard should appear (signed-in or guest + !onboarded).
  /// Pass [profileId] when the active profile is not bound yet (Who's watching).
  /// Signed-in + missing profile id → false (don't interrupt cold start).
  static Future<bool> shouldShow({String? profileId}) async {
    if (SyncService.instance.isSignedIn) {
      final key = profileId != null && profileId.trim().isNotEmpty
          ? await _prefsKeyForProfile(profileId)
          : await _prefsKeyForActiveProfile();
      if (key == null) return false;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) != true;
    }
    if (await isOnboardedLocal()) return false;
    return true;
  }

  /// Mark complete locally; push to cloud when signed in.
  static Future<void> markOnboarded({String? profileId}) async {
    await setOnboardedLocal(true, profileId: profileId);
    if (SyncService.instance.isSignedIn) {
      scheduleForjaOnboardedSyncPush();
    }
  }

  /// If any pack is already installed, mark onboarded without showing UI.
  static Future<bool> autoCompleteIfHasPacks({String? profileId}) async {
    if (!await shouldShow(profileId: profileId)) return false;
    final packs = await PluginRegistry.instance.listPacksRaw();
    final hasRemote = packs.any(
      (p) => !PluginRegistry.isLegacyAssetPack(p.sourceUrl),
    );
    if (!hasRemote) return false;
    await markOnboarded(profileId: profileId);
    return true;
  }
}
