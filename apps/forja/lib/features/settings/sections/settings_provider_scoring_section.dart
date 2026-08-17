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
    final animeCatalog = AnimeStreamProviders.catalog;
    final animeOrder = SettingsService.mergeProviderOrder(
      snap.animeProviderOrder,
      animeCatalog.keys,
    );
    final asianDramaCatalog = KissKhService.settingsCatalog;
    final asianDramaOrder = KissKhService.mergeMirrorOrder(
      snap.asianDramaProviderOrder,
    );
    final disabledAsianDrama = asianDramaCatalog.keys
        .where((host) => !asianDramaOrder.contains(host))
        .toSet();

    Future<void> persistAsianDramaOrder(List<String> next) async {
      final merged = KissKhService.mergeMirrorOrder(next);
      await playback.patch(
        (s) => s.copyWith(asianDramaProviderOrder: merged),
      );
      await settings.setAsianDramaProviderOrder(merged);
      scheduleProvidersSyncPush();
      final host = KissKhService.activeHostFromOrder(merged);
      await KissKhService.activateEndpoint(
        KissKhService.baseUrlForHost(host),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: ProviderScoringPanel(
        streamCatalog: streamCatalog,
        streamOrder: streamOrder,
        onStreamOrderChanged: (next) async {
          await playback.patch((s) => s.copyWith(streamProviderOrder: next));
          await settings.setStreamProviderOrder(next);
          scheduleProvidersSyncPush();
        },
        onStreamOrderReset: () async {
          final defaults = List<String>.from(
            SettingsService.defaultStreamProviderOrder,
          );
          await settings.setStreamProviderOrder(defaults);
          await playback.patch(
            (s) => s.copyWith(streamProviderOrder: defaults),
          );
          scheduleProvidersSyncPush();
        },
        animeCatalog: animeCatalog,
        animeOrder: animeOrder,
        onAnimeOrderChanged: (next) async {
          await playback.patch((s) => s.copyWith(animeProviderOrder: next));
          await settings.setAnimeProviderOrder(next);
          scheduleProvidersSyncPush();
        },
        onAnimeOrderReset: () async {
          final defaults = List<String>.from(
            SettingsService.defaultAnimeProviderOrder,
          );
          await settings.setAnimeProviderOrder(defaults);
          await playback.patch(
            (s) => s.copyWith(animeProviderOrder: defaults),
          );
          scheduleProvidersSyncPush();
        },
        asianDramaCatalog: asianDramaCatalog,
        asianDramaOrder: asianDramaOrder,
        disabledAsianDramaProviders: disabledAsianDrama,
        onAsianDramaOrderChanged: persistAsianDramaOrder,
        onAsianDramaOrderReset: () => persistAsianDramaOrder(
          List<String>.from(SettingsService.defaultAsianDramaProviderOrder),
        ),
      ),
    );
  }
}
