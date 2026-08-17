import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/anime/catalog/anime_stream_providers.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/widgets/provider_priority_table.dart';
import 'package:forja/shared/sync/sync.dart';

/// Webstreaming extractor order / reliability (Movies, Series, Anime, Asian Drama).
class SettingsProviderScoringSection extends ConsumerWidget {
  const SettingsProviderScoringSection({super.key});

  Future<void> _toggleDisabled({
    required SettingsService settings,
    required SettingsPlaybackNotifier playback,
    required List<String> currentDisabled,
    required String id,
    required int minEnabled,
    required int enabledCount,
    required Future<void> Function(List<String> disabled) persistDisabled,
  }) async {
    final off = currentDisabled.toSet();
    if (off.contains(id)) {
      off.remove(id);
    } else {
      if (enabledCount <= minEnabled) return;
      off.add(id);
    }
    await persistDisabled(off.toList());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(settingsPlaybackProvider).valueOrNull;
    if (snap == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final settings = SettingsService();
    final playback = ref.read(settingsPlaybackProvider.notifier);

    final streamCatalog = <String, String>{
      for (final entry in StreamProviders.providers.entries)
        entry.key: (entry.value['name'] as String?) ?? entry.key,
    };
    final streamOrder = <String>[
      ...snap.streamProviderOrder.where(streamCatalog.containsKey),
      ...streamCatalog.keys
          .where((k) => !snap.streamProviderOrder.contains(k)),
    ];
    final disabledStream = snap.disabledStreamProviders.toSet();
    final streamEnabledCount =
        streamOrder.where((id) => !disabledStream.contains(id)).length;

    final animeCatalog = AnimeStreamProviders.catalog;
    final animeOrder = SettingsService.mergeProviderOrder(
      snap.animeProviderOrder,
      animeCatalog.keys,
    );
    final disabledAnime = snap.disabledAnimeProviders.toSet();
    final animeEnabledCount =
        animeOrder.where((id) => !disabledAnime.contains(id)).length;

    final asianDramaCatalog = KissKhService.settingsCatalog;
    final asianDramaOrder = SettingsService.mergeProviderOrder(
      snap.asianDramaProviderOrder,
      asianDramaCatalog.keys,
    );
    final disabledAsianDrama = snap.disabledAsianDramaProviders.toSet();
    final asianEnabledCount =
        asianDramaOrder.where((id) => !disabledAsianDrama.contains(id)).length;

    Future<void> persistAsianDramaActivation() async {
      final enabled = await settings.getEnabledAsianDramaProviderOrder();
      final host = KissKhService.activeHostFromOrder(enabled);
      await KissKhService.activateEndpoint(
        KissKhService.baseUrlForHost(host),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: ProviderScoringPanel(
        streamCatalog: streamCatalog,
        streamOrder: streamOrder,
        disabledStreamProviders: disabledStream,
        onStreamOrderChanged: (next) async {
          await playback.patch((s) => s.copyWith(streamProviderOrder: next));
          await settings.setStreamProviderOrder(next);
          scheduleProvidersSyncPush();
        },
        onStreamProviderToggle: (id) async {
          await _toggleDisabled(
            settings: settings,
            playback: playback,
            currentDisabled: snap.disabledStreamProviders,
            id: id,
            minEnabled: 0,
            enabledCount: streamEnabledCount,
            persistDisabled: (disabled) async {
              await playback.patch(
                (s) => s.copyWith(disabledStreamProviders: disabled),
              );
              await settings.setDisabledStreamProviders(disabled);
              scheduleProvidersSyncPush();
            },
          );
        },
        onStreamOrderReset: () async {
          final defaults = List<String>.from(
            SettingsService.defaultStreamProviderOrder,
          );
          await settings.setStreamProviderOrder(defaults);
          await settings.setDisabledStreamProviders(const []);
          await playback.patch(
            (s) => s.copyWith(
              streamProviderOrder: defaults,
              disabledStreamProviders: const [],
            ),
          );
          scheduleProvidersSyncPush();
        },
        animeCatalog: animeCatalog,
        animeOrder: animeOrder,
        disabledAnimeProviders: disabledAnime,
        onAnimeOrderChanged: (next) async {
          await playback.patch((s) => s.copyWith(animeProviderOrder: next));
          await settings.setAnimeProviderOrder(next);
          scheduleProvidersSyncPush();
        },
        onAnimeProviderToggle: (id) async {
          await _toggleDisabled(
            settings: settings,
            playback: playback,
            currentDisabled: snap.disabledAnimeProviders,
            id: id,
            minEnabled: 0,
            enabledCount: animeEnabledCount,
            persistDisabled: (disabled) async {
              await playback.patch(
                (s) => s.copyWith(disabledAnimeProviders: disabled),
              );
              await settings.setDisabledAnimeProviders(disabled);
              scheduleProvidersSyncPush();
            },
          );
        },
        onAnimeOrderReset: () async {
          final defaults = List<String>.from(
            SettingsService.defaultAnimeProviderOrder,
          );
          await settings.setAnimeProviderOrder(defaults);
          await settings.setDisabledAnimeProviders(const []);
          await playback.patch(
            (s) => s.copyWith(
              animeProviderOrder: defaults,
              disabledAnimeProviders: const [],
            ),
          );
          scheduleProvidersSyncPush();
        },
        asianDramaCatalog: asianDramaCatalog,
        asianDramaOrder: asianDramaOrder,
        disabledAsianDramaProviders: disabledAsianDrama,
        onAsianDramaOrderChanged: (next) async {
          await playback.patch(
            (s) => s.copyWith(asianDramaProviderOrder: next),
          );
          await settings.setAsianDramaProviderOrder(next);
          scheduleProvidersSyncPush();
        },
        onAsianDramaProviderToggle: (id) async {
          await _toggleDisabled(
            settings: settings,
            playback: playback,
            currentDisabled: snap.disabledAsianDramaProviders,
            id: id,
            minEnabled: 1,
            enabledCount: asianEnabledCount,
            persistDisabled: (disabled) async {
              await playback.patch(
                (s) => s.copyWith(disabledAsianDramaProviders: disabled),
              );
              await settings.setDisabledAsianDramaProviders(disabled);
              scheduleProvidersSyncPush();
              await persistAsianDramaActivation();
            },
          );
        },
        onAsianDramaOrderReset: () async {
          final defaults = List<String>.from(
            SettingsService.defaultAsianDramaProviderOrder,
          );
          final off = [
            for (final host in defaults)
              if (host != 'kisskh.co') host,
          ];
          await settings.setAsianDramaProviderOrder(defaults);
          await settings.setDisabledAsianDramaProviders(off);
          await playback.patch(
            (s) => s.copyWith(
              asianDramaProviderOrder: defaults,
              disabledAsianDramaProviders: off,
            ),
          );
          scheduleProvidersSyncPush();
          await persistAsianDramaActivation();
        },
      ),
    );
  }
}
