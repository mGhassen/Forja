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

/// Unified server + source picker — one panel, grouped by server.
class PlayerStreamMenu {
  static const _panelWidth = 360.0;
  static const _panelMaxHeight = 440.0;

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
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        shrinkWrap: true,
        children: [
          for (final entry in orderedProviders) ...[
            _buildServerSection(
              providerId: entry.key,
              provider: entry.value,
              state: state,
              probes: probes,
              statusController: statusController,
              cachedSources: cache[entry.key],
              providersEnabled: providersEnabled,
              onSelectProvider: onSelectProvider,
              onSelectSource: onSelectSource,
            ),
            const SizedBox(height: 6),
          ],
        ],
      );
    }

    await PlayerPopupPanel.show(
      context: context,
      title: 'Stream source',
      leadingIcon: Icons.swap_horiz_rounded,
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

  static Widget _buildServerSection({
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
    final subtitle = _providerSubtitle(
      status: status,
      sourceCount: sectionSources.length,
      providersEnabled: providersEnabled,
    );
    final flags = StreamProviderDisplay.countryFlags(
      providerId,
      contentLanguage: _contentLanguage(provider),
    );
    final label = PlayerProviderMenu.snackbarLabel(providerId, provider);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isCurrent
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFF22C55E).withValues(alpha: 0.28)
              : ForjaShellColors.cinematic.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              onTap: providersEnabled
                  ? () async {
                      PlayerPopupPanel.dismiss();
                      await onSelectProvider(providerId);
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Row(
                  children: [
                    if (flags.isNotEmpty) ...[
                      _ServerFlagBadge(flags: flags),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 13,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: status == PlayerSourceStatus.checking
                                    ? playerSourceStatusColor(status!)
                                    : status == PlayerSourceStatus.failed
                                    ? playerSourceStatusColor(status!)
                                    : Colors.white.withValues(alpha: 0.45),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (status != null) ...[
                      const SizedBox(width: 6),
                      _StatusDot(status: status),
                    ],
                    if (isCurrent && state.playbackConfirmed)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          'Active',
                          style: TextStyle(
                            color: const Color(
                              0xFF22C55E,
                            ).withValues(alpha: 0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (sectionSources.isNotEmpty) ...[
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
              child: _sourcesList(
                sources: sectionSources,
                state: state,
                useIndexedStatuses: isCurrent,
                onSelectSource: (source, index) async {
                  PlayerPopupPanel.dismiss();
                  if (!isCurrent) {
                    final loaded = await onSelectProvider(providerId);
                    final pool = loaded ?? sectionSources;
                    final targetIndex = pool.indexWhere(
                      (s) => s.url == source.url,
                    );
                    if (targetIndex >= 0) {
                      await onSelectSource(pool[targetIndex], targetIndex);
                      return;
                    }
                  }
                  await onSelectSource(source, index);
                },
                compact: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _sourcesList({
    required List<StreamSource> sources,
    required PlayerStreamMenuState state,
    required Future<void> Function(StreamSource source, int index)
    onSelectSource,
    bool compact = false,
    bool useIndexedStatuses = false,
  }) {
    final statuses = state.sourceStatuses;
    final ordered = _orderedSourceEntries(sources, state);
    return Column(
      children: [
        for (final entry in ordered)
          _StreamSourceTile(
            source: entry.value,
            index: entry.key,
            state: state,
            status: useIndexedStatuses && entry.key < statuses.length
                ? statuses[entry.key]
                : PlayerSourceStatus.ready,
            compact: compact,
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

  static bool _isCurrentSource(StreamSource source, PlayerStreamMenuState state) {
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
  }) {
    if (sourceCount > 0 &&
        status != PlayerSourceStatus.checking &&
        status != PlayerSourceStatus.failed) {
      return '$sourceCount source${sourceCount == 1 ? '' : 's'}';
    }
    return switch (status) {
      PlayerSourceStatus.checking => 'Checking…',
      PlayerSourceStatus.failed => 'Unavailable',
      PlayerSourceStatus.ready =>
        providersEnabled ? 'Tap to load' : 'Unavailable',
      PlayerSourceStatus.active =>
        sourceCount > 0
            ? '$sourceCount source${sourceCount == 1 ? '' : 's'}'
            : null,
      null => providersEnabled ? 'Tap to load' : 'Unavailable',
    };
  }
}

class _ServerFlagBadge extends StatelessWidget {
  const _ServerFlagBadge({required this.flags});

  final String flags;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(flags, style: const TextStyle(fontSize: 13)),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final PlayerSourceStatus status;

  @override
  Widget build(BuildContext context) {
    final color = playerSourceStatusColor(status);
    if (status == PlayerSourceStatus.checking) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StreamSourceTile extends StatelessWidget {
  const _StreamSourceTile({
    required this.source,
    required this.index,
    required this.state,
    required this.status,
    required this.onTap,
    this.compact = false,
  });

  final StreamSource source;
  final int index;
  final PlayerStreamMenuState state;
  final PlayerSourceStatus status;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isCurrent = state.is111477
        ? source.url == state.current111477FileUrl
        : source.url == state.currentUrl;
    final failed = status == PlayerSourceStatus.failed;
    final active = isCurrent || status == PlayerSourceStatus.active;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 4 : 6),
      child: Material(
        color: active
            ? const Color(0xFF22C55E).withValues(alpha: 0.1)
            : failed
            ? const Color(0xFFEF4444).withValues(alpha: 0.07)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: active
                  ? Border.all(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                    )
                  : null,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 12,
              vertical: compact ? 8 : 10,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: playerSourceBadgeColor(source.type),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    source.type.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.35,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: failed
                              ? Colors.white.withValues(alpha: 0.45)
                              : Colors.white.withValues(alpha: 0.92),
                          fontSize: compact ? 13 : 14,
                          fontWeight: isCurrent
                              ? FontWeight.w600
                              : FontWeight.w500,
                          decoration: failed
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: Colors.white38,
                        ),
                      ),
                      if (status != PlayerSourceStatus.ready)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            switch (status) {
                              PlayerSourceStatus.active => 'Playing',
                              PlayerSourceStatus.failed => 'Unavailable',
                              PlayerSourceStatus.checking => 'Checking…',
                              PlayerSourceStatus.ready => '',
                            },
                            style: TextStyle(
                              color: playerSourceStatusColor(status),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isCurrent)
                  const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                else if (status == PlayerSourceStatus.failed)
                  Icon(
                    Icons.cancel_rounded,
                    color: playerSourceStatusColor(status),
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
