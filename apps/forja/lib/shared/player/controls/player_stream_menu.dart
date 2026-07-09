import 'package:flutter/material.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:rust/rust.dart';

/// Live stream menu state — read after async provider switches.
class PlayerStreamMenuState {
  const PlayerStreamMenuState({
    required this.currentProviderId,
    required this.sources,
    required this.currentUrl,
    required this.current111477FileUrl,
    required this.is111477,
    required this.providerAuto,
    required this.sourceAuto,
    this.activeProviderLabel,
    this.activeSourceTitle,
    this.sourceStatuses = const [],
  });

  final String? currentProviderId;
  final List<StreamSource>? sources;
  final String? currentUrl;
  final String? current111477FileUrl;
  final bool is111477;
  final bool providerAuto;
  final bool sourceAuto;
  final String? activeProviderLabel;
  final String? activeSourceTitle;
  final List<PlayerSourceStatus> sourceStatuses;
}

/// Servers → sources drill-down, same panel flow as seasons → episodes.
class PlayerStreamMenu {
  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? providers,
    required PlayerStreamMenuState Function() readState,
    required Future<List<StreamSource>?> Function(String providerId)
        onSelectProvider,
    required Future<void> Function() onSelectAutoProvider,
    required Future<void> Function() onSelectAutoSource,
    required Future<void> Function(StreamSource source, int index) onSelectSource,
    bool providersEnabled = true,
    bool sourcesOnly = false,
    BuildContext? anchorContext,
    EdgeInsets margin = const EdgeInsets.only(left: 16, bottom: 88),
    Listenable? refreshListenable,
  }) async {
    final initial = readState();
    final hasProviders = providers != null && providers.isNotEmpty;
    final hasSources =
        initial.sources != null && initial.sources!.isNotEmpty;

    if (!hasProviders && !hasSources) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No streams available'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    if (sourcesOnly && hasSources) {
      await _openSources(
        context,
        readState: readState,
        onSelectAutoSource: onSelectAutoSource,
        onSelectSource: onSelectSource,
        margin: margin,
        anchorContext: anchorContext,
        onBack: null,
        refreshListenable: refreshListenable,
      );
      return;
    }

    if (hasProviders) {
      await _openServers(
        context,
        providers: providers,
        readState: readState,
        onSelectProvider: onSelectProvider,
        onSelectAutoProvider: onSelectAutoProvider,
        onSelectAutoSource: onSelectAutoSource,
        onSelectSource: onSelectSource,
        providersEnabled: providersEnabled,
        margin: margin,
        anchorContext: anchorContext,
        refreshListenable: refreshListenable,
      );
    } else {
      await _openSources(
        context,
        readState: readState,
        onSelectAutoSource: onSelectAutoSource,
        onSelectSource: onSelectSource,
        margin: margin,
        anchorContext: anchorContext,
        onBack: null,
        refreshListenable: refreshListenable,
      );
    }
  }

  static Future<void> _openServers(
    BuildContext context, {
    required Map<String, dynamic> providers,
    required PlayerStreamMenuState Function() readState,
    required Future<List<StreamSource>?> Function(String providerId)
        onSelectProvider,
    required Future<void> Function() onSelectAutoProvider,
    required Future<void> Function() onSelectAutoSource,
    required Future<void> Function(StreamSource source, int index) onSelectSource,
    required bool providersEnabled,
    required EdgeInsets margin,
    BuildContext? anchorContext,
    Listenable? refreshListenable,
  }) async {
    final state = readState();

    await PlayerPopupPanel.show(
      context: context,
      title: 'Servers',
      leadingIcon: Icons.cloud_outlined,
      alignment: Alignment.bottomLeft,
      margin: margin,
      anchorContext: anchorContext,
      child: ListView(
        padding: const EdgeInsets.all(8),
        shrinkWrap: true,
        children: [
          PlayerPopupListTile(
            badge: 'AUTO',
            label: 'Auto',
            subtitle: state.providerAuto ? state.activeProviderLabel : null,
            selected: state.providerAuto,
            onTap: () async {
              PlayerPopupPanel.dismiss();
              await onSelectAutoProvider();
            },
          ),
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
            return PlayerPopupListTile(
              badge: flags.isEmpty ? null : flags,
              label: StreamProviderDisplay.playerLabel(
                key,
                fallbackName: fallbackName,
                contentLanguage: contentLanguage,
              ),
              selected: !state.providerAuto && isCurrent,
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No sources for this server'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                  return;
                }
                if (!context.mounted) return;
                await _openSources(
                  context,
                  readState: readState,
                  onSelectAutoSource: onSelectAutoSource,
                  onSelectSource: onSelectSource,
                  margin: margin,
                  anchorContext: anchorContext,
                  refreshListenable: refreshListenable,
                  onBack: () => _openServers(
                    context,
                    providers: providers,
                    readState: readState,
                    onSelectProvider: onSelectProvider,
                    onSelectAutoProvider: onSelectAutoProvider,
                    onSelectAutoSource: onSelectAutoSource,
                    onSelectSource: onSelectSource,
                    providersEnabled: providersEnabled,
                    margin: margin,
                    anchorContext: anchorContext,
                    refreshListenable: refreshListenable,
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  static Future<void> _openSources(
    BuildContext context, {
    required PlayerStreamMenuState Function() readState,
    required Future<void> Function() onSelectAutoSource,
    required Future<void> Function(StreamSource source, int index) onSelectSource,
    required EdgeInsets margin,
    BuildContext? anchorContext,
    required VoidCallback? onBack,
    Listenable? refreshListenable,
  }) async {
    Widget buildList() {
      final state = readState();
      final sources = state.sources ?? const <StreamSource>[];
      final statuses = state.sourceStatuses;

      return ListView(
        padding: const EdgeInsets.all(8),
        shrinkWrap: true,
        children: [
          PlayerPopupListTile(
            badge: 'AUTO',
            badgeColor: playerSourceBadgeColor('AUTO'),
            label: 'Auto',
            subtitle: state.sourceAuto ? state.activeSourceTitle : null,
            selected: state.sourceAuto,
            onTap: () async {
              PlayerPopupPanel.dismiss();
              await onSelectAutoSource();
            },
          ),
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
              selected: !state.sourceAuto && isCurrent,
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
}
