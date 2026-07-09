import 'package:flutter/material.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:rust/rust.dart';

/// Servers → sources drill-down, same panel flow as seasons → episodes.
class PlayerStreamMenu {
  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? providers,
    String? currentProviderId,
    required Future<void> Function(String providerId) onSelectProvider,
    List<StreamSource>? sources,
    required String? currentUrl,
    required String? current111477FileUrl,
    required bool is111477,
    required Future<void> Function(StreamSource source, int index) onSelectSource,
    bool providersEnabled = true,
    EdgeInsets margin = const EdgeInsets.only(left: 16, bottom: 88),
  }) async {
    final hasProviders = providers != null && providers.isNotEmpty;
    final hasSources = sources != null && sources.isNotEmpty;

    if (!hasProviders && !hasSources) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No streams available'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    if (hasProviders) {
      await _openServers(
        context,
        providers: providers,
        currentProviderId: currentProviderId,
        onSelectProvider: onSelectProvider,
        sources: sources,
        currentUrl: currentUrl,
        current111477FileUrl: current111477FileUrl,
        is111477: is111477,
        onSelectSource: onSelectSource,
        providersEnabled: providersEnabled,
        margin: margin,
      );
    } else {
      await _openSources(
        context,
        sources: sources!,
        currentUrl: currentUrl,
        current111477FileUrl: current111477FileUrl,
        is111477: is111477,
        onSelectSource: onSelectSource,
        margin: margin,
        onBack: null,
      );
    }
  }

  static Future<void> _openServers(
    BuildContext context, {
    required Map<String, dynamic> providers,
    required String? currentProviderId,
    required Future<void> Function(String providerId) onSelectProvider,
    required List<StreamSource>? sources,
    required String? currentUrl,
    required String? current111477FileUrl,
    required bool is111477,
    required Future<void> Function(StreamSource source, int index) onSelectSource,
    required bool providersEnabled,
    required EdgeInsets margin,
  }) async {
    final currentSources = sources ?? const <StreamSource>[];

    await PlayerPopupPanel.show(
      context: context,
      title: 'Servers',
      leadingIcon: Icons.cloud_outlined,
      alignment: Alignment.bottomLeft,
      margin: margin,
      child: ListView(
        padding: const EdgeInsets.all(8),
        shrinkWrap: true,
        children: providers.entries.map((entry) {
          final key = entry.key;
          final provider = entry.value;
          final isCurrent = key == currentProviderId;
          final fallbackName = provider['name']?.toString();
          final contentLanguage = _contentLanguage(provider);
          final flags = StreamProviderDisplay.countryFlags(
            key,
            contentLanguage: contentLanguage,
          );
          final canDrillSources = isCurrent && currentSources.isNotEmpty;
          return PlayerPopupListTile(
            badge: flags.isEmpty ? null : flags,
            label: StreamProviderDisplay.playerLabel(
              key,
              fallbackName: fallbackName,
              contentLanguage: contentLanguage,
            ),
            selected: isCurrent,
            trailing: canDrillSources
                ? const Icon(Icons.chevron_right_rounded,
                    color: Colors.white24, size: 18)
                : null,
            onTap: () async {
              PlayerPopupPanel.dismiss();
              if (!isCurrent) {
                if (providersEnabled) await onSelectProvider(key);
                return;
              }
              if (canDrillSources) {
                await _openSources(
                  context,
                  sources: currentSources,
                  currentUrl: currentUrl,
                  current111477FileUrl: current111477FileUrl,
                  is111477: is111477,
                  onSelectSource: onSelectSource,
                  margin: margin,
                  onBack: () => _openServers(
                    context,
                    providers: providers,
                    currentProviderId: currentProviderId,
                    onSelectProvider: onSelectProvider,
                    sources: sources,
                    currentUrl: currentUrl,
                    current111477FileUrl: current111477FileUrl,
                    is111477: is111477,
                    onSelectSource: onSelectSource,
                    providersEnabled: providersEnabled,
                    margin: margin,
                  ),
                );
              }
            },
          );
        }).toList(),
      ),
    );
  }

  static Future<void> _openSources(
    BuildContext context, {
    required List<StreamSource> sources,
    required String? currentUrl,
    required String? current111477FileUrl,
    required bool is111477,
    required Future<void> Function(StreamSource source, int index) onSelectSource,
    required EdgeInsets margin,
    required VoidCallback? onBack,
  }) async {
    await PlayerPopupPanel.show(
      context: context,
      title: 'Sources',
      leadingIcon: Icons.dns_outlined,
      alignment: Alignment.bottomLeft,
      margin: margin,
      onBack: onBack,
      child: ListView(
        padding: const EdgeInsets.all(8),
        shrinkWrap: true,
        children: sources.asMap().entries.map((entry) {
          final index = entry.key;
          final source = entry.value;
          final isCurrent = is111477
              ? source.url == current111477FileUrl
              : source.url == currentUrl;
          return PlayerPopupListTile(
            badge: source.type.toUpperCase(),
            label: source.title,
            selected: isCurrent,
            onTap: () async {
              PlayerPopupPanel.dismiss();
              if (!isCurrent) await onSelectSource(source, index);
            },
          );
        }).toList(),
      ),
    );
  }

  static List<String>? _contentLanguage(Map<String, dynamic> provider) {
    final raw = provider['contentLanguage'];
    if (raw is! List) return null;
    return raw.map((e) => e.toString()).toList();
  }
}
