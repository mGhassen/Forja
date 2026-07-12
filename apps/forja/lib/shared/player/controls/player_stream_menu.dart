import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_provider_menu.dart';
import 'package:forja/shared/player/controls/player_status_roulette.dart';
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
    this.playbackConfirmed = false,
  });

  final String? currentProviderId;
  final List<StreamSource>? sources;
  final String? currentUrl;
  final String? current111477FileUrl;
  final bool is111477;
  final List<PlayerSourceStatus> sourceStatuses;
  final bool playbackConfirmed;
}

/// Unified server + source picker — flat grouped list, no cards.
class PlayerStreamMenu {
  static const _panelWidth = 320.0;
  static const _panelMaxHeight = 420.0;

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
    ValueListenable<Map<String, List<StreamSource>>>? providerSourcesCache,
    ValueListenable<List<StreamProviderProbe>>? providerProbesNotifier,
    PlayerStatusController? statusController,
    required PlayerStreamMenuState Function() readState,
    required Future<List<StreamSource>?> Function(String providerId)
        onSelectProvider,
    required Future<void> Function(StreamSource source, int index)
        onSelectSource,
    bool providersEnabled = true,
    BuildContext? anchorContext,
    EdgeInsets margin = const EdgeInsets.only(left: 16, bottom: 88),
    Listenable? refreshListenable,
    Future<void> Function()? onReload,
    ValueListenable<bool>? isReloading,
  }) async {
    final initial = readState();
    final hasProviders = providers != null && providers.isNotEmpty;
    final hasSources = initial.sources != null && initial.sources!.isNotEmpty;

    if (!hasProviders && !hasSources) {
      ForjaToast.warning(
        'No streams available',
        duration: const Duration(seconds: 1),
      );
      return;
    }

    Widget buildList() {
      final state = readState();
      final probes = providerProbesNotifier?.value ?? const [];
      final cache = providerSourcesCache?.value ?? const {};

      if (!hasProviders) {
        return _sourcesList(
          sources: state.sources ?? const [],
          state: state,
          onSelectSource: onSelectSource,
          useIndexedStatuses: true,
        );
      }

      final orderedProviders =
          _orderedProviderEntries(providers, state.currentProviderId);

      return ListView(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
        shrinkWrap: true,
        children: [
          for (var i = 0; i < orderedProviders.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            _buildServerGroup(
              providerId: orderedProviders[i].key,
              provider: orderedProviders[i].value,
              state: state,
              probes: probes,
              statusController: statusController,
              cachedSources: cache[orderedProviders[i].key],
              providersEnabled: providersEnabled,
              onSelectProvider: onSelectProvider,
              onSelectSource: onSelectSource,
            ),
          ],
        ],
      );
    }

    await PlayerPopupPanel.show(
      context: context,
      title: 'Source',
      leadingIcon: Icons.layers_outlined,
      alignment: Alignment.bottomLeft,
      margin: margin,
      anchorContext: anchorContext,
      width: _panelWidth,
      maxHeight: _panelMaxHeight,
      trailing: reloadTrailing(onReload: onReload, isReloading: isReloading),
      child: refreshListenable == null
          ? buildList()
          : ListenableBuilder(
              listenable: refreshListenable,
              builder: (context, _) => buildList(),
            ),
    );
  }

  static Widget _buildServerGroup({
    required String providerId,
    required dynamic provider,
    required PlayerStreamMenuState state,
    required List<StreamProviderProbe> probes,
    PlayerStatusController? statusController,
    required List<StreamSource>? cachedSources,
    required bool providersEnabled,
    required Future<List<StreamSource>?> Function(String providerId)
        onSelectProvider,
    required Future<void> Function(StreamSource source, int index)
        onSelectSource,
  }) {
    final isCurrent = providerId == state.currentProviderId;
    final sectionSources = isCurrent
        ? (state.sources ?? const <StreamSource>[])
        : (cachedSources ?? const <StreamSource>[]);
    final status = _providerStatus(
      providerId,
      probes,
      isCurrent: isCurrent,
      statusController: statusController,
      playbackConfirmed: state.playbackConfirmed,
    );
    final flags = StreamProviderDisplay.countryFlags(
      providerId,
      contentLanguage: _contentLanguage(provider),
    );
    final label = PlayerProviderMenu.snackbarLabel(providerId, provider);
    final subtitle = _providerSubtitle(
      status: status,
      sourceCount: sectionSources.length,
      providersEnabled: providersEnabled,
      isCurrent: isCurrent,
      playbackConfirmed: state.playbackConfirmed,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          label: flags.isEmpty ? label : '$flags  $label',
          subtitle: subtitle,
          status: status,
          isCurrent: isCurrent && state.playbackConfirmed,
        ),
        if (sectionSources.isEmpty)
          _FlatMenuRow(
            label: providersEnabled ? 'Load streams' : 'Unavailable',
            selected: false,
            status: status ?? PlayerSourceStatus.ready,
            onTap: providersEnabled
                ? () async {
                    PlayerPopupPanel.dismiss();
                    await onSelectProvider(providerId);
                  }
                : null,
          )
        else
          _sourcesList(
            sources: sectionSources,
            state: state,
            useIndexedStatuses: isCurrent,
            onSelectSource: (source, index) async {
              PlayerPopupPanel.dismiss();
              if (!isCurrent) {
                final loaded = await onSelectProvider(providerId);
                final pool = loaded ?? sectionSources;
                final targetIndex =
                    pool.indexWhere((s) => s.url == source.url);
                if (targetIndex >= 0) {
                  await onSelectSource(pool[targetIndex], targetIndex);
                  return;
                }
              }
              await onSelectSource(source, index);
            },
          ),
      ],
    );
  }

  static Widget _sourcesList({
    required List<StreamSource> sources,
    required PlayerStreamMenuState state,
    required Future<void> Function(StreamSource source, int index)
        onSelectSource,
    bool useIndexedStatuses = false,
  }) {
    final statuses = state.sourceStatuses;
    final ordered = _orderedSourceEntries(sources, state);
    return Column(
      children: [
        for (final entry in ordered)
          _FlatMenuRow(
            label: entry.value.title,
            meta: entry.value.type.toUpperCase(),
            selected: _isCurrentSource(entry.value, state),
            status: useIndexedStatuses && entry.key < statuses.length
                ? statuses[entry.key]
                : PlayerSourceStatus.ready,
            onTap: () => onSelectSource(entry.value, entry.key),
          ),
      ],
    );
  }

  static List<MapEntry<String, dynamic>> _orderedProviderEntries(
    Map<String, dynamic> providers,
    String? currentProviderId,
  ) {
    final entries = providers.entries.toList();
    if (currentProviderId == null ||
        !providers.containsKey(currentProviderId)) {
      return entries;
    }
    entries.sort((a, b) {
      if (a.key == currentProviderId) return -1;
      if (b.key == currentProviderId) return 1;
      return 0;
    });
    return entries;
  }

  static List<MapEntry<int, StreamSource>> _orderedSourceEntries(
    List<StreamSource> sources,
    PlayerStreamMenuState state,
  ) {
    final entries = sources.asMap().entries.toList();
    entries.sort((a, b) {
      final aCurrent = _isCurrentSource(a.value, state);
      final bCurrent = _isCurrentSource(b.value, state);
      if (aCurrent != bCurrent) return aCurrent ? -1 : 1;
      return a.key.compareTo(b.key);
    });
    return entries;
  }

  static bool _isCurrentSource(
    StreamSource source,
    PlayerStreamMenuState state,
  ) {
    return state.is111477
        ? source.url == state.current111477FileUrl
        : source.url == state.currentUrl;
  }

  static List<String>? _contentLanguage(dynamic provider) {
    if (provider is! Map) return null;
    final raw = provider['contentLanguage'];
    if (raw is! List) return null;
    return raw.map((e) => e.toString()).toList();
  }

  static PlayerSourceStatus? _providerStatus(
    String providerId,
    List<StreamProviderProbe> probes, {
    required bool isCurrent,
    PlayerStatusController? statusController,
    bool playbackConfirmed = false,
  }) {
    if (isCurrent && playbackConfirmed) return PlayerSourceStatus.active;

    final fromController = _providerStatusFromController(
      providerId,
      statusController,
    );
    if (fromController != null) return fromController;

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

  static PlayerSourceStatus? _providerStatusFromController(
    String providerId,
    PlayerStatusController? statusController,
  ) {
    if (statusController == null) return null;
    for (final entry in statusController.entries) {
      if (entry.id != 'provider-$providerId') continue;
      return switch (entry.kind) {
        StatusRouletteKind.loading => PlayerSourceStatus.checking,
        StatusRouletteKind.success => PlayerSourceStatus.ready,
        StatusRouletteKind.failed => PlayerSourceStatus.failed,
        StatusRouletteKind.info => null,
      };
    }
    return null;
  }

  static String? _providerSubtitle({
    required PlayerSourceStatus? status,
    required int sourceCount,
    required bool providersEnabled,
    required bool isCurrent,
    required bool playbackConfirmed,
  }) {
    if (isCurrent && playbackConfirmed) return 'Playing now';
    if (sourceCount > 0 &&
        status != PlayerSourceStatus.checking &&
        status != PlayerSourceStatus.failed) {
      return '$sourceCount stream${sourceCount == 1 ? '' : 's'}';
    }
    return switch (status) {
      PlayerSourceStatus.checking => 'Checking…',
      PlayerSourceStatus.failed => 'Unavailable',
      PlayerSourceStatus.ready =>
        providersEnabled ? 'Not loaded' : 'Unavailable',
      PlayerSourceStatus.active => 'Playing now',
      null => providersEnabled ? 'Not loaded' : 'Unavailable',
    };
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    this.subtitle,
    this.status,
    this.isCurrent = false,
  });

  final String label;
  final String? subtitle;
  final PlayerSourceStatus? status;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isCurrent
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.88),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        color: _subtitleColor(status),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (status == PlayerSourceStatus.checking)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: playerSourceStatusColor(status!),
              ),
            )
          else if (isCurrent)
            Icon(
              Icons.play_arrow_rounded,
              size: 18,
              color: playerSourceStatusColor(PlayerSourceStatus.active),
            ),
        ],
      ),
    );
  }

  Color _subtitleColor(PlayerSourceStatus? status) {
    if (status == PlayerSourceStatus.checking ||
        status == PlayerSourceStatus.failed) {
      return playerSourceStatusColor(status!);
    }
    return Colors.white.withValues(alpha: 0.42);
  }
}

class _FlatMenuRow extends StatelessWidget {
  const _FlatMenuRow({
    required this.label,
    this.meta,
    this.selected = false,
    this.status = PlayerSourceStatus.ready,
    this.onTap,
  });

  final String label;
  final String? meta;
  final bool selected;
  final PlayerSourceStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final failed = status == PlayerSourceStatus.failed;
    final disabled = onTap == null;

    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: ForjaShellColors.inkHover,
        splashColor: ForjaShellColors.inkSplash,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Row(
            children: [
              if (meta != null) ...[
                SizedBox(
                  width: 34,
                  child: Text(
                    meta!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ] else
                const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: failed
                        ? Colors.white.withValues(alpha: 0.38)
                        : selected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    decoration: failed ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white38,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, color: Colors.white, size: 17)
              else if (status == PlayerSourceStatus.checking)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: playerSourceStatusColor(status),
                  ),
                )
              else if (status == PlayerSourceStatus.failed)
                Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: playerSourceStatusColor(status),
                )
              else if (disabled)
                Icon(
                  Icons.block_rounded,
                  size: 15,
                  color: Colors.white.withValues(alpha: 0.24),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
