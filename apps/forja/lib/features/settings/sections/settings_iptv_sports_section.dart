import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/live_matches/live_matches_iptv_sports_settings.dart';
import 'package:forja/features/settings/widgets/settings_engine_plugin_pack.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// Settings → Forja Sports — Xtream matcher (RFC-062) + live engine plugins (RFC-065).
class SettingsIptvSportsSection extends StatefulWidget {
  const SettingsIptvSportsSection({super.key});

  @override
  State<SettingsIptvSportsSection> createState() =>
      _SettingsIptvSportsSectionState();
}

class _SettingsIptvSportsSectionState extends State<SettingsIptvSportsSection> {
  LiveMatchesIptvSportsConfig _config = const LiveMatchesIptvSportsConfig();
  bool _loading = true;
  String? _error;
  EnginePack? _bundledPack;
  List<EnginePlugin> _liveSourcePlugins = const [];
  List<EnginePlugin> _liveCatalogPlugins = const [];

  @override
  void initState() {
    super.initState();
    EngineService.changeNotifier.addListener(_onEngineChanged);
    unawaited(_reload());
  }

  @override
  void dispose() {
    EngineService.changeNotifier.removeListener(_onEngineChanged);
    super.dispose();
  }

  void _onEngineChanged() {
    if (!mounted) return;
    unawaited(_loadLivePlugins());
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await LiveMatchesIptvSportsConfig.load();
      await _loadLivePlugins();
      if (!mounted) return;
      setState(() {
        _config = config;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _loadLivePlugins() async {
    await EngineService.instance.ensureOfficialInstalled();
    final packs = await EngineService.instance.listPacks();
    final live = <EnginePlugin>[
      for (final pack in packs)
        for (final p in pack.plugins)
          if (p.isLive && p.isHttp) p,
    ];
    live.sort((a, b) => a.name.compareTo(b.name));
    final primary = packs.isEmpty
        ? null
        : packs.firstWhere(
            (p) => EngineService.isOfficialPack(p.sourceUrl),
            orElse: () => packs.first,
          );
    if (!mounted) return;
    setState(() {
      _bundledPack = primary;
      _liveSourcePlugins = [
        for (final p in live)
          if (!p.isLiveCatalog) p,
      ];
      _liveCatalogPlugins = [
        for (final p in live)
          if (p.isLiveCatalog) p,
      ];
    });
  }

  Future<void> _persist(LiveMatchesIptvSportsConfig next) async {
    setState(() => _config = next);
    await LiveMatchesIptvSportsConfig.save(next);
  }

  Future<void> _toggleLeague(String league) async {
    final next = List<String>.from(_config.leagues);
    if (next.contains(league)) {
      next.remove(league);
    } else {
      next.add(league);
    }
    await _persist(_config.copyWith(leagues: next));
  }

  Widget _leagueActionButton(
    BuildContext context, {
    required String label,
    required VoidCallback onPressed,
  }) {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    if (!tv) {
      return TextButton(onPressed: onPressed, child: Text(label));
    }
    return shellFocusableTap(
      context: context,
      onTap: onPressed,
      scaleOnFocus: 1.0,
      showFocusRail: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            color: ForjaShellColors.brandGreen,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  static const _leagueChipRowId = 'iptv-sports-leagues';

  Widget _leagueChip(
    BuildContext context,
    String league,
    int index, {
    TvChipEdges? edges,
  }) {
    final selected = _config.leagues.contains(league);
    final label =
        LiveMatchesIptvSportsConfig.leagueLabels[league] ?? league;
    return ForjaShellChip(
      label: label,
      selected: selected,
      listIndex: index,
      fontSize: 12,
      accentHover: true,
      tvTabId: edges != null ? 'settings' : null,
      tvRowId: edges != null ? _leagueChipRowId : null,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      onTap: () => _toggleLeague(league),
      onLeftEdge: edges?.onLeft,
      onRightEdge: edges?.onRight,
      onDownEdge: edges?.onDown,
      onUpEdge: edges?.onUp,
    );
  }

  Widget _leagueChipWrap(BuildContext context) {
    final leagues = LiveMatchesIptvSportsConfig.allLeagues;
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    if (!tv) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < leagues.length; i++)
            _leagueChip(context, leagues[i], i),
        ],
      );
    }
    return TvChipStrip(
      tabId: 'settings',
      rowId: _leagueChipRowId,
      sortOrder: 80,
      itemCount: leagues.length,
      resultsRowId: 'iptv-sports-leagues-end',
      builder: (context, edgesFor) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < leagues.length; i++)
              _leagueChip(context, leagues[i], i, edges: edgesFor(i)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SettingsGroup(
        label: 'Loading',
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_bundledPack != null && _liveSourcePlugins.isNotEmpty)
          SettingsGroup(
            label: 'Live plugins',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
                child: Text(
                  'Stream resolve and schedule sources for Forja Live and All. '
                  'Movie Sources → Forja is unchanged.',
                  style: TextStyle(
                    color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: SettingsEnginePackExpansion(
                  pack: _bundledPack!,
                  plugins: _liveSourcePlugins,
                  groupKey: EngineCategories.liveSourceGroupKey,
                  groupLabel: EngineCategories.liveSourceGroupLabel,
                  groupOrder: EngineCategories.liveSourceGroupOrder,
                  tabRowId: 'live-engine-pack-tabs',
                ),
              ),
            ],
          ),
        if (_bundledPack != null && _liveCatalogPlugins.isNotEmpty)
          SettingsGroup(
            label: 'Catalog',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
                child: Text(
                  'Schedule feeds for Forja Live, All, and Forja Sports (Xtream match).',
                  style: TextStyle(
                    color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 2, 8),
                child: SettingsEnginePluginToggleList(
                  sourceUrl: _bundledPack!.sourceUrl,
                  plugins: _liveCatalogPlugins,
                ),
              ),
            ],
          ),
        SettingsGroup(
          label: 'Setup',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 12, 2, 4),
              child: Text(
                'Pick the portal in Live Matches → Forja Sports (top-right Portals). '
                'Here: enable and which leagues to match.',
                style: TextStyle(
                  color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFF87171),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            SettingsToggleRow(
              title: 'Enable Forja Sports',
              subtitle: 'Show the Forja Sports server in Live Matches',
              value: _config.enabled,
              onChanged: (v) async {
                var next = _config.copyWith(enabled: v);
                if (v && next.leagues.isEmpty) {
                  next = next.copyWith(
                    leagues: List<String>.from(
                      LiveMatchesIptvSportsConfig.allLeagues,
                    ),
                  );
                }
                if (v && next.portalKey.isEmpty) {
                  final fromIptv =
                      await LiveMatchesIptvSportsConfig.resolvePortalKey(next);
                  if (fromIptv.isNotEmpty) {
                    next = next.copyWith(portalKey: fromIptv);
                  }
                }
                await _persist(next);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Leagues',
                      style: TextStyle(
                        color: ForjaShellColors.textPrimary.withValues(
                          alpha: 0.9,
                        ),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  _leagueActionButton(
                    context,
                    label: 'All',
                    onPressed: () => _persist(
                      _config.copyWith(
                        leagues: List<String>.from(
                          LiveMatchesIptvSportsConfig.allLeagues,
                        ),
                      ),
                    ),
                  ),
                  _leagueActionButton(
                    context,
                    label: 'None',
                    onPressed: () =>
                        _persist(_config.copyWith(leagues: const [])),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
              child: _leagueChipWrap(context),
            ),
          ],
        ),
      ],
    );
  }
}
