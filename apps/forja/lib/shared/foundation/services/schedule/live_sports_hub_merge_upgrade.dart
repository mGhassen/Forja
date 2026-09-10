import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/install/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/packs/registry/pack_hub_features.dart';
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:forja/shared/foundation/services/pack/pack_settings_store.dart';
import 'package:forja/shared/foundation/services/schedule/kit_schedule_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One-shot: cards-only Live Sports installs → merged hub prefs + list pack.
///
/// Writes style=cards + matchOpen=details, installs `live_sports` if missing,
/// removes `live_sports_cards`, activates the list hub.
abstract final class LiveSportsHubMergeUpgrade {
  LiveSportsHubMergeUpgrade._();

  static const cardsPackId = 'forjahq-live-sports-cards';
  static const livePackId = 'forjahq-live-sports';
  static const livePluginId = 'live-sports-hub';
  static const cardsPluginId = 'live-sports-cards-hub';
  static const matchOpenField = 'matchOpen';

  static Future<void> runOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(KitSchedulePrefs.mergeUpgradeDoneKey) == true) {
      return;
    }

    try {
      final packs = await PluginRegistry.instance.listPacks();
      EnginePack? cards;
      EnginePack? live;
      for (final p in packs) {
        if (_isCardsPack(p)) cards = p;
        if (_isLivePack(p)) live = p;
      }

      if (cards == null) {
        await prefs.setBool(KitSchedulePrefs.mergeUpgradeDoneKey, true);
        return;
      }

      await prefs.setString(
        KitSchedulePrefs.styleKey,
        KitSchedulePrefs.styleCards,
      );
      await PackSettingsStore.setString(
        livePluginId,
        matchOpenField,
        'details',
      );
      await PackSettingsStore.setString(
        cardsPluginId,
        matchOpenField,
        'details',
      );

      final liveUrl = _liveManifestUrlFromCards(cards.sourceUrl);
      if (live == null && liveUrl.isNotEmpty) {
        live = await PluginInstallCoordinator.instance.installManifest(liveUrl);
      }
      if (live != null) {
        await PackHubFeatures.activate(live);
      }

      final cardsUrl = cards.sourceUrl;
      await PluginRegistry.instance.removePack(cardsUrl);
      await PackHubFeatures.deactivate(cards);

      await prefs.setBool(KitSchedulePrefs.mergeUpgradeDoneKey, true);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[LiveSportsHubMergeUpgrade] failed: $e\n$st');
      }
    }
  }

  static bool _isCardsPack(EnginePack p) {
    if (p.packId == cardsPackId) return true;
    final url = p.sourceUrl;
    return url.contains('live_sports_cards') ||
        url.contains('live-sports-cards');
  }

  static bool _isLivePack(EnginePack p) {
    if (p.packId == livePackId) return true;
    final url = p.sourceUrl;
    if (url.contains('live_sports_cards') ||
        url.contains('live-sports-cards')) {
      return false;
    }
    return url.contains('live_sports') || url.contains('live-sports');
  }

  static String _liveManifestUrlFromCards(String cardsUrl) {
    return cardsUrl
        .replaceAll('live_sports_cards', 'live_sports')
        .replaceAll('live-sports-cards', 'live-sports');
  }
}
