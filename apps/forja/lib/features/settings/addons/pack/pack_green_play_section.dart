import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/packs/settings/pack_green_play_config.dart';
import 'package:forja/shared/engine/packs/settings/pack_settings_store.dart';
import 'package:forja/shared/sync/bridge/sync_domain_bridge.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';

/// Pack-declared green Play settings (RFC-118) — preferred Forja providers only.
///
/// Shown when a hub plugin declares `settings.greenPlay`.
class PackGreenPlaySection extends StatefulWidget {
  const PackGreenPlaySection({
    super.key,
    this.addonId,
    this.plugins,
  }) : assert(addonId != null || plugins != null);

  final String? addonId;
  final List<EnginePlugin>? plugins;

  @override
  State<PackGreenPlaySection> createState() => _PackGreenPlaySectionState();
}

class _PackGreenPlaySectionState extends State<PackGreenPlaySection> {
  final List<_GreenPlayTarget> _targets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    PackSettingsStore.onNonSecretUserWrite ??= schedulePackSettingsSyncPush;
    if (widget.plugins == null) {
      EngineService.changeNotifier.addListener(_onEngineChanged);
    }
    unawaited(_reload());
  }

  @override
  void didUpdateWidget(covariant PackGreenPlaySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.plugins != oldWidget.plugins ||
        widget.addonId != oldWidget.addonId) {
      unawaited(_reload());
    }
  }

  @override
  void dispose() {
    if (widget.plugins == null) {
      EngineService.changeNotifier.removeListener(_onEngineChanged);
    }
    super.dispose();
  }

  void _onEngineChanged() {
    if (!mounted) return;
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final plugins = widget.plugins ??
        activePluginsFromPacks(await EngineService.instance.listPacks());
    final wantAddon = widget.addonId?.trim();
    final targets = <_GreenPlayTarget>[];
    for (final p in plugins) {
      if (!p.enabled) continue;
      if (!PackGreenPlayConfig.isDeclared(p)) continue;
      if (wantAddon != null && wantAddon.isNotEmpty) {
        final addon = (p.settings?['addon'] ?? '').toString().trim();
        if (addon != wantAddon && p.id != wantAddon) continue;
      }
      final config = await PackGreenPlayConfig.resolve(p.id);
      targets.add(_GreenPlayTarget(plugin: p, config: config));
    }
    if (!mounted) return;
    setState(() {
      _targets
        ..clear()
        ..addAll(targets);
      _loading = false;
    });
  }

  Future<void> _savePreferred(
    _GreenPlayTarget target,
    List<String> preferred,
  ) async {
    final next = PackGreenPlayConfig.forjaPreferred(preferred);
    await PackGreenPlayConfig.save(target.plugin.id, next);
    if (!mounted) return;
    setState(() {
      final i = _targets.indexWhere((t) => t.plugin.id == target.plugin.id);
      if (i >= 0) {
        _targets[i] = _GreenPlayTarget(plugin: target.plugin, config: next);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _targets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final target in _targets)
          _PreferredForjaEditor(
            target: target,
            onChanged: (preferred) =>
                unawaited(_savePreferred(target, preferred)),
          ),
      ],
    );
  }
}

class _GreenPlayTarget {
  const _GreenPlayTarget({required this.plugin, required this.config});
  final EnginePlugin plugin;
  final PackGreenPlayConfig config;
}

class _ProviderOption {
  const _ProviderOption({required this.id, required this.label});
  final String id;
  final String label;
}

class _PreferredForjaEditor extends StatefulWidget {
  const _PreferredForjaEditor({
    required this.target,
    required this.onChanged,
  });

  final _GreenPlayTarget target;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_PreferredForjaEditor> createState() => _PreferredForjaEditorState();
}

class _PreferredForjaEditorState extends State<_PreferredForjaEditor> {
  List<_ProviderOption> _catalog = const [];
  late List<String> _preferred;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _preferred = List<String>.from(
      widget.target.config.providerPrefs(PackGreenPlayTechs.engine).preferred,
    );
    unawaited(_loadCatalog());
  }

  @override
  void didUpdateWidget(covariant _PreferredForjaEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.target.config
        .providerPrefs(PackGreenPlayTechs.engine)
        .preferred;
    if (!_listEq(_preferred, next)) {
      _preferred = List<String>.from(next);
    }
  }

  Future<void> _loadCatalog() async {
    final packs = await EngineService.instance.listSourcesPanelPacks();
    final enabled = enabledEnginePluginIds(packs);
    final out = <_ProviderOption>[];
    final seen = <String>{};
    for (final pack in packs) {
      if (!pack.enabled) continue;
      for (final p in pack.plugins) {
        if (!p.enabled || !p.isHttp || !enabled.contains(p.id)) continue;
        if (!seen.add(p.id)) continue;
        out.add(
          _ProviderOption(
            id: p.id,
            label: p.name.trim().isNotEmpty ? p.name : p.id,
          ),
        );
      }
    }
    out.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    if (!mounted) return;
    setState(() {
      _catalog = out;
      _ready = true;
    });
  }

  String _labelFor(String id) {
    for (final o in _catalog) {
      if (o.id == id) return o.label;
    }
    return id;
  }

  Future<void> _openAddDialog() async {
    final picked = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (ctx) => ShellScope.rehost(
        context,
        _PreferredProviderSearchDialog(
          catalog: [
            for (final o in _catalog)
              if (!_preferred.contains(o.id)) o,
          ],
        ),
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    if (_preferred.contains(picked)) return;
    final next = [..._preferred, picked];
    setState(() => _preferred = next);
    widget.onChanged(next);
  }

  void _remove(String id) {
    final next = [for (final p in _preferred) if (p != id) p];
    setState(() => _preferred = next);
    widget.onChanged(next);
  }

  void _reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _preferred.length) return;
    var ni = newIndex;
    if (ni > oldIndex) ni--;
    if (ni < 0 || ni >= _preferred.length) return;
    final next = List<String>.from(_preferred);
    final item = next.removeAt(oldIndex);
    next.insert(ni, item);
    setState(() => _preferred = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    final muted = ForjaShellColors.textSecondary;

    return SettingsGroup(
      label: 'Green Play',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'Preferred Forja providers for the green Play button. '
            'They are tried first; empty list races all enabled Forja providers.',
            style: TextStyle(color: muted, fontSize: 13, height: 1.35),
          ),
        ),
        if (_preferred.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'No preferred providers — green Play races every enabled Forja plugin.',
              style: TextStyle(color: muted, fontSize: 13),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _preferred.length,
            onReorder: _reorder,
            itemBuilder: (context, index) {
              final id = _preferred[index];
              return ListTile(
                key: ValueKey('pref-$id'),
                dense: true,
                title: Text(_labelFor(id)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => _remove(id),
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.drag_handle_rounded),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ForjaShellChip(
              label: 'Add preferred',
              selected: false,
              icon: Icons.add_rounded,
              onTap: _catalog.length <= _preferred.length
                  ? null
                  : () => unawaited(_openAddDialog()),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreferredProviderSearchDialog extends StatefulWidget {
  const _PreferredProviderSearchDialog({required this.catalog});

  final List<_ProviderOption> catalog;

  @override
  State<_PreferredProviderSearchDialog> createState() =>
      _PreferredProviderSearchDialogState();
}

class _PreferredProviderSearchDialogState
    extends State<_PreferredProviderSearchDialog> {
  final _query = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<_ProviderOption> get _filtered {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return widget.catalog;
    return [
      for (final o in widget.catalog)
        if (o.label.toLowerCase().contains(q) ||
            o.id.toLowerCase().contains(q))
          o,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxH = SettingsTokens.dialogMaxHeightOf(context, size.height);
    final maxW = SettingsTokens.dialogMaxWidthOf(context, size.width);
    final filtered = _filtered;

    return AlertDialog(
      backgroundColor: ForjaShellColors.surfaceElevated,
      title: const Text('Add preferred provider'),
      content: SizedBox(
        width: maxW,
        height: maxH * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsTextField(
              controller: _query,
              label: 'Search',
              hint: 'Provider name',
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        widget.catalog.isEmpty
                            ? 'No Forja providers enabled'
                            : 'No matches',
                        style: TextStyle(
                          color: ForjaShellColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final o = filtered[index];
                        return ListTile(
                          dense: true,
                          title: Text(o.label),
                          subtitle: Text(
                            o.id,
                            style: TextStyle(
                              color: ForjaShellColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () => Navigator.of(context).pop(o.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
