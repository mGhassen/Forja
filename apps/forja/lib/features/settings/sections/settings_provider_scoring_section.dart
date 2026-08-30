import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/engine/hub_plugin_config.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/widgets/provider_priority_table.dart';
import 'package:forja/shared/sync/sync.dart';

Map<String, String> _animeSettingsCatalog() {
  final out = <String, String>{
    'megaplay': 'Megaplay',
    'anikoto': 'AniKoto',
    'vidlink': 'VidLink',
    'watchhentai': 'WatchHentai',
    'hentaini': 'Hentaini',
  };
  for (final p in miruroKnownProviders) {
    out['miruro:$p'] = miruroUpstreamLabel(p);
  }
  for (final p in allAnimeKnownProviders) {
    out['allanime:$p'] = p;
  }
  for (final p in vidnestKnownProviders) {
    out['vidnest:$p'] = vidnestUpstreamLabels[p] ?? p;
  }
  return out;
}

/// Forja engine provider order / reliability (Movies, Series, Anime, Asian Drama).
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

    final streamCatalog = const <String, String>{};
    const streamOrder = <String>[];
    const disabledStream = <String>{};
    const streamEnabledCount = 0;

    final animeCatalog = _animeSettingsCatalog();
    final animeOrder = SettingsService.mergeProviderOrder(
      snap.animeProviderOrder,
      animeCatalog.keys,
    );
    final disabledAnime = snap.disabledAnimeProviders.toSet();
    final animeEnabledCount =
        animeOrder.where((id) => !disabledAnime.contains(id)).length;

    final asianDramaCatalogAsync = ref.watch(asianDramaMirrorCatalogProvider);
    final asianDramaCatalog = asianDramaCatalogAsync.valueOrNull ??
        {
          for (final host in SettingsService.asianDramaMirrorHosts)
            host: HubPluginConfig.mirrorLabel(host),
        };
    final asianDramaOrder = SettingsService.mergeProviderOrder(
      snap.asianDramaProviderOrder,
      asianDramaCatalog.keys,
    );
    final disabledAsianDrama = snap.disabledAsianDramaProviders.toSet();
    final asianEnabledCount =
        asianDramaOrder.where((id) => !disabledAsianDrama.contains(id)).length;

    Future<void> persistAsianDramaActivation() async {
      final enabled = await settings.getEnabledAsianDramaProviderOrder();
      final host = HubPluginConfig.activeHostFromOrder(
        enabled,
        asianDramaCatalog.keys,
      );
      await HubPluginConfig.activateMirrorBaseUrl(
        HubPluginConfig.baseUrlForHost(host),
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
