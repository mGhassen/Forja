import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:rust/rust.dart';

/// Live stream menu state — read after async provider switches.
class PlayerStreamMenuState {
  const PlayerStreamMenuState({
    required this.currentProviderId,
    required this.sources,
    required this.currentUrl,
    required this.current111477FileUrl,
    required this.is111477,
    this.sourceStatuses = const [],
  });

  final String? currentProviderId;
  final List<StreamSource>? sources;
  final String? currentUrl;
  final String? current111477FileUrl;
  final bool is111477;
  final List<PlayerSourceStatus> sourceStatuses;
}

/// Servers → sources drill-down, same panel flow as seasons → episodes.
class PlayerStreamMenu {
  static Widget? reloadTrailing({
    required Future<void> Function()? onReload,
    ValueListenable<bool>? isReloading,
  }) {
    if (onReload == null) return null;
    Widget buildButton(bool loading) {
      if (loading) {
        return const Padding(
          padding: EdgeInsets.only(right: 4),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white38,
            ),
          ),
        );
      }
      return ForjaPlainIcon(
        icon: Icons.refresh_rounded,
        size: 20,
        color: Colors.white54,
        onTap: () => unawaited(onReload()),
      );
    }

    if (isReloading == null) return buildButton(false);
    return ValueListenableBuilder<bool>(
      valueListenable: isReloading,
      builder: (context, loading, _) => buildButton(loading),
    );
  }

  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? providers,
    ValueListenable<List<StreamProviderProbe>>? providerProbesNotifier,
    required PlayerStreamMenuState Function() readState,
    required Future<List<StreamSource>?> Function(String providerId)
        onSelectProvider,
    required Future<void> Function(StreamSource source, int index) onSelectSource,
    bool providersEnabled = true,
    bool sourcesOnly = false,
    BuildContext? anchorContext,
    EdgeInsets margin = const EdgeInsets.only(left: 16, bottom: 88),
    Listenable? refreshListenable,
    Future<void> Function()? onReload,
    ValueListenable<bool>? isReloading,
  }) async {
    final initial = readState();
    final hasProviders = providers != null && providers.isNotEmpty;
    final hasSources =
        initial.sources != null && initial.sources!.isNotEmpty;

    if (!hasProviders && !hasSources) {
      ForjaToast.warning('No streams available', duration: const Duration(seconds: 1));
      return;
    }

    if (sourcesOnly && hasSources) {
      await _openSources(
        context,
        readState: readState,
        onSelectSource: onSelectSource,
        margin: margin,
        anchorContext: anchorContext,
        onBack: null,
        refreshListenable: refreshListenable,
        onReload: onReload,
        isReloading: isReloading,
      );
      return;
    }

    if (hasProviders) {
      await _openServers(
        context,
        providers: providers,
        providerProbesNotifier: providerProbesNotifier,
        readState: readState,
        onSelectProvider: onSelectProvider,
        onSelectSource: onSelectSource,
        providersEnabled: providersEnabled,
        margin: margin,
        anchorContext: anchorContext,
        refreshListenable: refreshListenable,
        onReload: onReload,
        isReloading: isReloading,
      );
    } else {
      await _openSources(
        context,
        readState: readState,
        onSelectSource: onSelectSource,
        margin: margin,
        anchorContext: anchorContext,
        onBack: null,
        refreshListenable: refreshListenable,
        onReload: onReload,
        isReloading: isReloading,
      );
    }
  }

  static Future<void> _openServers(
    BuildContext context, {
    required Map<String, dynamic> providers,
    ValueListenable<List<StreamProviderProbe>>? providerProbesNotifier,
    required PlayerStreamMenuState Function() readState,
    required Future<List<StreamSource>?> Function(String providerId)
        onSelectProvider,
    required Future<void> Function(StreamSource source, int index) onSelectSource,
    required bool providersEnabled,
    required EdgeInsets margin,
    BuildContext? anchorContext,
    Listenable? refreshListenable,
    Future<void> Function()? onReload,
    ValueListenable<bool>? isReloading,
  }) async {
    Widget buildList() {
      final state = readState();
      final probes = providerProbesNotifier?.value ?? const [];
      return ListView(
        padding: const EdgeInsets.all(8),
        shrinkWrap: true,
        children: [
          ...providers.entries.map((entry) {
            final key = entry.key;
            final provider = entry.value;
            final isCurrent = key == state.currentProviderId;
            final fallbackName = provider['name']?.toString();
            final contentLanguage = _contentLanguage(provider);
            final flags = StreamProviderDisplay.countryFlags(
              key,
              contentLanguage: contentLanguage,
            );
            final status = _providerStatus(
              key,
              probes,
              isCurrent: isCurrent,
            );
            return PlayerPopupListTile(
              badge: flags.isEmpty ? null : flags,
              label: StreamProviderDisplay.playerLabel(
                key,
                fallbackName: fallbackName,
                contentLanguage: contentLanguage,
              ),
              selected: isCurrent,
              status: status,
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white24,
                size: 18,
              ),
              onTap: () async {
                PlayerPopupPanel.dismiss();
                List<StreamSource>? serverSources;
                if (isCurrent) {
                  serverSources = readState().sources;
                } else if (providersEnabled) {
                  serverSources = await onSelectProvider(key);
                }
                serverSources ??= readState().sources;
                if (serverSources == null || serverSources.isEmpty) {
                  if (context.mounted) {
                    ForjaToast.info('No sources for this server', duration: const Duration(seconds: 1));
                  }
                  return;
                }
                if (!context.mounted) return;
                await _openSources(
                  context,
                  readState: readState,
                  onSelectSource: onSelectSource,
                  margin: margin,
                  anchorContext: anchorContext,
                  refreshListenable: refreshListenable,
                  onReload: onReload,
                  isReloading: isReloading,
                  onBack: () => _openServers(
                    context,
                    providers: providers,
                    providerProbesNotifier: providerProbesNotifier,
                    readState: readState,
                    onSelectProvider: onSelectProvider,
                    onSelectSource: onSelectSource,
                    providersEnabled: providersEnabled,
                    margin: margin,
                    anchorContext: anchorContext,
                    refreshListenable: refreshListenable,
                    onReload: onReload,
                    isReloading: isReloading,
                  ),
                );
              },
            );
          }),
        ],
      );
    }

    await PlayerPopupPanel.show(
      context: context,
      title: 'Servers',
      leadingIcon: Icons.cloud_outlined,
      alignment: Alignment.bottomLeft,
      margin: margin,
      anchorContext: anchorContext,
      trailing: reloadTrailing(onReload: onReload, isReloading: isReloading),
      child: refreshListenable == null
          ? buildList()
          : ListenableBuilder(
              listenable: refreshListenable,
              builder: (context, _) => buildList(),
            ),
    );
  }

  static Future<void> _openSources(
    BuildContext context, {
    required PlayerStreamMenuState Function() readState,
    required Future<void> Function(StreamSource source, int index) onSelectSource,
    required EdgeInsets margin,
    BuildContext? anchorContext,
    required VoidCallback? onBack,
    Listenable? refreshListenable,
    Future<void> Function()? onReload,
    ValueListenable<bool>? isReloading,
  }) async {
    Widget buildList() {
      final state = readState();
      final sources = state.sources ?? const <StreamSource>[];
      final statuses = state.sourceStatuses;

      return ListView(
        padding: const EdgeInsets.all(8),
        shrinkWrap: true,
        children: [
          ...sources.asMap().entries.map((entry) {
            final index = entry.key;
            final source = entry.value;
            final isCurrent = state.is111477
                ? source.url == state.current111477FileUrl
                : source.url == state.currentUrl;
            final status = index < statuses.length
                ? statuses[index]
                : PlayerSourceStatus.ready;
            return PlayerPopupListTile(
              badge: source.type.toUpperCase(),
              badgeColor: playerSourceBadgeColor(source.type),
              label: source.title,
              selected: isCurrent,
              status: status,
              onTap: () async {
                PlayerPopupPanel.dismiss();
                if (!isCurrent) await onSelectSource(source, index);
              },
            );
          }),
        ],
      );
    }

    await PlayerPopupPanel.show(
      context: context,
      title: 'Sources',
      leadingIcon: Icons.dns_outlined,
      alignment: Alignment.bottomLeft,
      margin: margin,
      anchorContext: anchorContext,
      onBack: onBack,
      trailing: reloadTrailing(onReload: onReload, isReloading: isReloading),
      child: refreshListenable == null
          ? buildList()
          : ListenableBuilder(
              listenable: refreshListenable,
              builder: (context, _) => buildList(),
            ),
    );
  }

  static List<String>? _contentLanguage(Map<String, dynamic> provider) {
    final raw = provider['contentLanguage'];
    if (raw is! List) return null;
    return raw.map((e) => e.toString()).toList();
  }

  static PlayerSourceStatus? _providerStatus(
    String providerId,
    List<StreamProviderProbe> probes, {
    required bool isCurrent,
  }) {
    if (isCurrent) return PlayerSourceStatus.active;
    for (final probe in probes) {
      if (probe.id != providerId) continue;
      return switch (probe.status) {
        StreamProviderProbeStatus.pending => null,
        StreamProviderProbeStatus.trying => PlayerSourceStatus.checking,
        StreamProviderProbeStatus.failed => PlayerSourceStatus.failed,
        StreamProviderProbeStatus.success => PlayerSourceStatus.ready,
      };
    }
    return null;
  }
}
