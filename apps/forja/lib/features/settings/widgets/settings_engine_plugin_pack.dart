import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_engine_pack_update.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/features/settings/widgets/settings_plugin_install_progress.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

/// Groups [plugins] for Settings tab strips (movie Forja, live Forja, …).
({Map<String, List<EnginePlugin>> byGroup, List<String> orderedGroups})
groupEnginePluginsForSettings({
  required List<EnginePlugin> plugins,
  required String Function(EnginePlugin) groupKey,
  required List<String> groupOrder,
}) {
  final byGroup = <String, List<EnginePlugin>>{};
  for (final p in plugins) {
    byGroup.putIfAbsent(groupKey(p), () => []).add(p);
  }
  final orderedGroups = [
    for (final key in groupOrder)
      if (byGroup.containsKey(key)) key,
    for (final key in byGroup.keys)
      if (!groupOrder.contains(key)) key,
  ];
  return (byGroup: byGroup, orderedGroups: orderedGroups);
}

/// Groups installed packs by Providers / Live / Catalog / IPTV / Hubs / Other.
({Map<String, List<EnginePack>> byKind, List<String> orderedKinds})
groupEnginePacksByKind(List<EnginePack> packs) {
  final byKind = <String, List<EnginePack>>{};
  for (final pack in packs) {
    byKind.putIfAbsent(PluginRegistry.packKindKey(pack), () => []).add(pack);
  }
  final orderedKinds = [
    for (final key in PluginRegistry.packKindOrder)
      if (byKind.containsKey(key)) key,
    for (final key in byKind.keys)
      if (!PluginRegistry.packKindOrder.contains(key)) key,
  ];
  return (byKind: byKind, orderedKinds: orderedKinds);
}

/// Small muted uppercase label used for inline sub-sections (Forja pack lists).
class SettingsEngineMiniLabel extends StatelessWidget {
  const SettingsEngineMiniLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: ForjaShellColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

/// Built-in / installed pack row with grouped plugin toggles (Sources → Forja parity).
class SettingsEnginePackExpansion extends StatelessWidget {
  const SettingsEnginePackExpansion({
    super.key,
    required this.pack,
    required this.plugins,
    required this.groupKey,
    required this.groupLabel,
    required this.groupOrder,
    this.miniLabel = 'Forja plugins',
    this.tabRowId = 'engine-pack-tabs',
    this.trailing,
    this.showMiniLabel = false,
    this.installProgress,
    this.update,
  });

  final EnginePack pack;
  final List<EnginePlugin> plugins;
  final String Function(EnginePlugin) groupKey;
  final String Function(String) groupLabel;
  final List<String> groupOrder;
  final String miniLabel;
  final String tabRowId;
  final Widget? trailing;
  final bool showMiniLabel;
  final PluginInstallProgress? installProgress;
  final EnginePackUpdateInfo? update;

  @override
  Widget build(BuildContext context) {
    if (plugins.isEmpty) return const SizedBox.shrink();

    final grouped = groupEnginePluginsForSettings(
      plugins: plugins,
      groupKey: groupKey,
      groupOrder: groupOrder,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showMiniLabel) ...[
          SettingsEngineMiniLabel(miniLabel),
          const SizedBox(height: 4),
        ],
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: SettingsEnginePackUpdateFrame(
            hasUpdate: update != null,
            child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 2),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 2, 8),
            leading: Icon(
              update != null
                  ? Icons.system_update_rounded
                  : Icons.bolt_rounded,
              color: update != null
                  ? ForjaShellColors.brandGreen
                  : ForjaShellColors.iconActive,
            ),
            title: Text(
              pack.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: ForjaShellColors.textPrimary,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pack.sourceUrl,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: ForjaShellColors.textSecondary,
                  ),
                ),
                SettingsEnginePackVersionLine(
                  meta:
                      '${PluginRegistry.packKindInfo(pack)} · '
                      '${plugins.length} plugin${plugins.length == 1 ? '' : 's'} · '
                      'v${pack.version}',
                  update: update,
                ),
                SettingsEnginePackInstallStatus(
                  sourceUrl: pack.sourceUrl,
                  progress: installProgress,
                  update: update,
                ),
              ],
            ),
            trailing: settingsExpansionTrailing(context, trailing),
            children: settingsExpansionChildren(
              context,
              trailing: trailing,
              children: [
                SettingsEnginePluginGroupList(
                  sourceUrl: pack.sourceUrl,
                  byGroup: grouped.byGroup,
                  orderedGroups: grouped.orderedGroups,
                  groupLabel: groupLabel,
                  tabRowId: tabRowId,
                ),
              ],
            ),
          ),
          ),
        ),
      ],
    );
  }
}

/// Category tabs + per-plugin toggles inside a pack ExpansionTile.
class SettingsEnginePluginGroupList extends StatefulWidget {
  const SettingsEnginePluginGroupList({
    super.key,
    required this.sourceUrl,
    required this.byGroup,
    required this.orderedGroups,
    required this.groupLabel,
    this.tabRowId = 'engine-pack-tabs',
  });

  final String sourceUrl;
  final Map<String, List<EnginePlugin>> byGroup;
  final List<String> orderedGroups;
  final String Function(String) groupLabel;
  final String tabRowId;

  @override
  State<SettingsEnginePluginGroupList> createState() =>
      _SettingsEnginePluginGroupListState();
}

class _SettingsEnginePluginGroupListState
    extends State<SettingsEnginePluginGroupList> {
  late String _group;

  @override
  void initState() {
    super.initState();
    _group = widget.orderedGroups.first;
  }

  @override
  void didUpdateWidget(covariant SettingsEnginePluginGroupList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.orderedGroups.contains(_group)) {
      _group = widget.orderedGroups.isEmpty
          ? 'other'
          : widget.orderedGroups.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final plugins = widget.byGroup[_group] ?? const <EnginePlugin>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.orderedGroups.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: _SettingsEngineCategoryTabStrip(
              groups: widget.orderedGroups,
              selected: _group,
              groupLabel: widget.groupLabel,
              tabRowId: widget.tabRowId,
              onChanged: (g) => setState(() => _group = g),
            ),
          ),
        SettingsEnginePluginToggleList(
          sourceUrl: widget.sourceUrl,
          plugins: plugins,
        ),
      ],
    );
  }
}

/// Flat per-plugin toggles (no category tabs).
class SettingsEnginePluginToggleList extends StatelessWidget {
  const SettingsEnginePluginToggleList({
    super.key,
    required this.sourceUrl,
    required this.plugins,
  });

  final String sourceUrl;
  final List<EnginePlugin> plugins;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in plugins)
          SettingsToggleRow(
            key: ValueKey('engine-plugin-${sourceUrl.hashCode}-${p.id}'),
            title: p.name,
            subtitle: [
              if (p.description != null && p.description!.isNotEmpty)
                p.description!,
              if (p.types.isNotEmpty) p.types.join(', '),
              p.kind,
            ].join(' · '),
            value: p.enabled,
            onChanged: (val) async {
              await EngineService.instance.setPluginEnabled(
                sourceUrl: sourceUrl,
                pluginId: p.id,
                enabled: val,
              );
            },
          ),
      ],
    );
  }
}

/// Live sport pack row — **Catalog** / **Provider** tabs with per-site toggles.
class SettingsLiveSportPackExpansion extends StatelessWidget {
  const SettingsLiveSportPackExpansion({
    super.key,
    required this.pack,
    required this.plugins,
    this.trailing,
    this.update,
  });

  final EnginePack pack;
  final List<EnginePlugin> plugins;
  final Widget? trailing;
  final EnginePackUpdateInfo? update;

  @override
  Widget build(BuildContext context) {
    if (plugins.isEmpty) return const SizedBox.shrink();

    return SettingsEnginePackUpdateFrame(
      hasUpdate: update != null,
      child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 2),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 2, 8),
        leading: Icon(
          update != null
              ? Icons.system_update_rounded
              : Icons.bolt_rounded,
          color: update != null
              ? ForjaShellColors.brandGreen
              : ForjaShellColors.iconActive,
        ),
        title: Text(
          pack.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: ForjaShellColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pack.sourceUrl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: ForjaShellColors.textSecondary,
              ),
            ),
            SettingsEnginePackVersionLine(
              meta:
                  '${PluginRegistry.packKindInfo(pack)} · '
                  '${plugins.length} plugin${plugins.length == 1 ? '' : 's'} · '
                  'v${pack.version}',
              update: update,
            ),
            if (update != null)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  'Update available',
                  style: TextStyle(
                    fontSize: 11,
                    color: ForjaShellColors.brandGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        trailing: settingsExpansionTrailing(context, trailing),
        children: settingsExpansionChildren(
          context,
          trailing: trailing,
          children: [
            SettingsLiveSportCapabilityTabs(
              sourceUrl: pack.sourceUrl,
              plugins: plugins,
              tabRowId: 'live-sport-pack-tabs-${pack.sourceUrl.hashCode}',
            ),
          ],
        ),
      ),
    ),
    );
  }
}

/// Catalog | Provider tabs — one toggle per site in each tab.
class SettingsLiveSportCapabilityTabs extends StatefulWidget {
  const SettingsLiveSportCapabilityTabs({
    super.key,
    required this.sourceUrl,
    required this.plugins,
    this.tabRowId = 'live-sport-cap-tabs',
  });

  final String sourceUrl;
  final List<EnginePlugin> plugins;
  final String tabRowId;

  @override
  State<SettingsLiveSportCapabilityTabs> createState() =>
      _SettingsLiveSportCapabilityTabsState();
}

class _SettingsLiveSportCapabilityTabsState
    extends State<SettingsLiveSportCapabilityTabs> {
  static const _tabCatalog = 'catalog';
  static const _tabProvider = 'provider';

  late String _tab;
  Map<String, ({bool catalog, bool resolve})> _caps = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = _defaultTab();
    EngineService.changeNotifier.addListener(_onEngineChanged);
    unawaited(_reloadCaps());
  }

  @override
  void dispose() {
    EngineService.changeNotifier.removeListener(_onEngineChanged);
    super.dispose();
  }

  String _defaultTab() {
    final hasCatalog = widget.plugins.any((p) => p.supportsLiveCatalog);
    return hasCatalog ? _tabCatalog : _tabProvider;
  }

  void _onEngineChanged() {
    if (!mounted) return;
    unawaited(_reloadCaps());
  }

  @override
  void didUpdateWidget(covariant SettingsLiveSportCapabilityTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceUrl != widget.sourceUrl ||
        oldWidget.plugins != widget.plugins) {
      if (!_tabs.contains(_tab)) {
        _tab = _defaultTab();
      }
      unawaited(_reloadCaps());
    }
  }

  List<String> get _tabs {
    final out = <String>[];
    if (widget.plugins.any((p) => p.supportsLiveCatalog)) {
      out.add(_tabCatalog);
    }
    if (widget.plugins.any((p) => p.supportsLiveResolve)) {
      out.add(_tabProvider);
    }
    return out;
  }

  Future<void> _reloadCaps() async {
    final next = <String, ({bool catalog, bool resolve})>{};
    for (final p in widget.plugins) {
      if (!p.isLiveSportPlugin) continue;
      final catalog = p.supportsLiveCatalog
          ? await EngineService.instance.liveCapabilityEnabled(
              sourceUrl: widget.sourceUrl,
              plugin: p,
              capability: LiveSportCapabilities.catalog,
            )
          : false;
      final resolve = p.supportsLiveResolve
          ? await EngineService.instance.liveCapabilityEnabled(
              sourceUrl: widget.sourceUrl,
              plugin: p,
              capability: LiveSportCapabilities.resolve,
            )
          : false;
      next[p.id] = (catalog: catalog, resolve: resolve);
    }
    if (!mounted) return;
    setState(() {
      _caps = next;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final tabs = _tabs;
    if (tabs.isEmpty) return const SizedBox.shrink();

    final showTabs = tabs.length > 1;
    final catalogPlugins = [
      for (final p in widget.plugins)
        if (p.isLiveSportPlugin && p.supportsLiveCatalog) p,
    ];
    final providerPlugins = [
      for (final p in widget.plugins)
        if (p.isLiveSportPlugin && p.supportsLiveResolve) p,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTabs)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: _SettingsEngineCategoryTabStrip(
              groups: tabs,
              selected: _tab,
              groupLabel: (key) => switch (key) {
                _tabCatalog => 'Catalog',
                _tabProvider => 'Provider',
                _ => key,
              },
              tabRowId: widget.tabRowId,
              onChanged: (g) => setState(() => _tab = g),
            ),
          ),
        if (_tab == _tabCatalog)
          ..._capabilityRows(
            catalogPlugins,
            capability: LiveSportCapabilities.catalog,
            subtitle: 'Schedule feed for Live Matches',
            valueFor: (id) => _caps[id]?.catalog ?? false,
          )
        else
          ..._capabilityRows(
            providerPlugins,
            capability: LiveSportCapabilities.resolve,
            subtitle: 'Stream resolve for Forja Live',
            valueFor: (id) => _caps[id]?.resolve ?? false,
          ),
      ],
    );
  }

  List<Widget> _capabilityRows(
    List<EnginePlugin> plugins, {
    required String capability,
    required String subtitle,
    required bool Function(String id) valueFor,
  }) {
    return [
      for (final p in plugins)
        SettingsToggleRow(
          key: ValueKey('live-cap-${widget.sourceUrl.hashCode}-${p.id}-$capability'),
          title: p.name,
          subtitle: [
            if (p.description != null && p.description!.isNotEmpty) p.description!,
            subtitle,
          ].join(' · '),
          value: valueFor(p.id),
          onChanged: (val) async {
            await EngineService.instance.setLiveCapabilityEnabled(
              sourceUrl: widget.sourceUrl,
              pluginId: p.id,
              capability: capability,
              enabled: val,
            );
          },
        ),
    ];
  }
}
class _SettingsEngineCategoryTabStrip extends StatelessWidget {
  const _SettingsEngineCategoryTabStrip({
    required this.groups,
    required this.selected,
    required this.groupLabel,
    required this.tabRowId,
    required this.onChanged,
  });

  final List<String> groups;
  final String selected;
  final String Function(String) groupLabel;
  final String tabRowId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    if (!tv) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < groups.length; i++)
            ForjaShellChip(
              label: groupLabel(groups[i]),
              selected: selected == groups[i],
              listIndex: i,
              onTap: () => onChanged(groups[i]),
            ),
        ],
      );
    }

    return TvChipStrip(
      tabId: 'settings',
      rowId: tabRowId,
      sortOrder: 0,
      itemCount: groups.length,
      resultsRowId: 'engine-pack-row',
      builder: (context, edgesFor) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < groups.length; i++)
              ForjaShellChip(
                label: groupLabel(groups[i]),
                selected: selected == groups[i],
                listIndex: i,
                tvTabId: 'settings',
                tvRowId: tabRowId,
                onTap: () => onChanged(groups[i]),
                onLeftEdge: edgesFor(i).onLeft,
                onRightEdge: edgesFor(i).onRight,
                onDownEdge: edgesFor(i).onDown,
                onUpEdge: edgesFor(i).onUp,
              ),
          ],
        );
      },
    );
  }
}
