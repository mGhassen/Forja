import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/engine.dart';
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

/// Groups installed packs by Providers / Live / Catalog / Hubs / Other.
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

  @override
  Widget build(BuildContext context) {
    if (plugins.isEmpty) return const SizedBox.shrink();

    final grouped = groupEnginePluginsForSettings(
      plugins: plugins,
      groupKey: groupKey,
      groupOrder: groupOrder,
    );
    final official = EngineService.isOfficialPack(pack.sourceUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showMiniLabel) ...[
          SettingsEngineMiniLabel(miniLabel),
          const SizedBox(height: 4),
        ],
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 2),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 2, 8),
            leading: const Icon(
              Icons.bolt_rounded,
              color: ForjaShellColors.iconActive,
            ),
            title: Text(
              official ? '${pack.name} (ForjaHQ)' : pack.name,
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
                Text(
                  '${PluginRegistry.packKindInfo(pack)} · '
                  '${plugins.length} plugin${plugins.length == 1 ? '' : 's'} · '
                  'v${pack.version}',
                  style: TextStyle(
                    fontSize: 11,
                    color: ForjaShellColors.textSecondary.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
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
