import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/packs/settings/pack_green_play_config.dart';
import 'package:forja/shared/engine/packs/settings/pack_settings_store.dart';
import 'package:forja/shared/nuvio/nuvio_service.dart';
import 'package:forja/shared/playback/open/play_source_effective.dart';
import 'package:forja/shared/sync/bridge/sync_domain_bridge.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';
import 'package:rust/rust.dart';

/// Pack-declared green Play settings (RFC-118).
///
/// Shown when a hub plugin contributing to [addonId] (or listed in [plugins])
/// declares `settings.greenPlay`.
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

  Future<void> _save(_GreenPlayTarget target, PackGreenPlayConfig next) async {
    await PackGreenPlayConfig.save(target.plugin.id, next);
    if (!mounted) return;
    setState(() {
      final i = _targets.indexWhere((t) => t.plugin.id == target.plugin.id);
      if (i >= 0) _targets[i] = _GreenPlayTarget(plugin: target.plugin, config: next);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _targets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final target in _targets)
          _GreenPlayEditor(
            target: target,
            onChanged: (next) => unawaited(_save(target, next)),
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

class _GreenPlayEditor extends StatefulWidget {
  const _GreenPlayEditor({
    required this.target,
    required this.onChanged,
  });

  final _GreenPlayTarget target;
  final ValueChanged<PackGreenPlayConfig> onChanged;

  @override
  State<_GreenPlayEditor> createState() => _GreenPlayEditorState();
}

class _GreenPlayEditorState extends State<_GreenPlayEditor> {
  late PackGreenPlayConfig _config;
  Map<String, bool> _techGates = {};
  Map<String, List<_ProviderOption>> _providerOptions = {};
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _config = widget.target.config;
    unawaited(_loadOptions());
  }

  @override
  void didUpdateWidget(covariant _GreenPlayEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target.config != widget.target.config) {
      _config = widget.target.config;
    }
  }

  Future<void> _loadOptions() async {
    final gates = <String, bool>{
      PackGreenPlayTechs.engine: await PlaySourceEffective.engine(),
      PackGreenPlayTechs.stremio: await PlaySourceEffective.stremio(),
      PackGreenPlayTechs.nuvio: await PlaySourceEffective.nuvio(),
      PackGreenPlayTechs.torrent: await PlaySourceEffective.torrent(),
    };

    final options = <String, List<_ProviderOption>>{};

    final packs = await EngineService.instance.listSourcesPanelPacks();
    final enabled = enabledEnginePluginIds(packs);
    options[PackGreenPlayTechs.engine] = [
      for (final pack in packs)
        if (pack.enabled)
          for (final p in pack.plugins)
            if (p.enabled && p.isHttp && enabled.contains(p.id))
              _ProviderOption(
                id: p.id,
                label: p.name.trim().isNotEmpty ? p.name : p.id,
              ),
    ];

    final settings = SettingsService();
    final stremioAddons = await settings.getStremioAddons();
    options[PackGreenPlayTechs.stremio] = [
      for (final addon in stremioAddons)
        if (StremioAddonFeatures.isEnabled(addon))
          () {
            final base = SettingsService.normalizeStremioAddonBaseUrl(
              (addon['baseUrl'] ?? addon['url'] ?? '').toString(),
            );
            if (base.isEmpty) return null;
            final name =
                (addon['name'] ?? addon['manifestName'] ?? base).toString();
            return _ProviderOption(id: base, label: name);
          }(),
    ].whereType<_ProviderOption>().toList();

    final nuvioAddons = await NuvioService.instance.listAddons();
    options[PackGreenPlayTechs.nuvio] = [
      for (final addon in nuvioAddons)
        for (final s in addon.scrapers)
          if (s.enabled)
            _ProviderOption(
              id: s.id,
              label: s.name.trim().isNotEmpty ? s.name : s.id,
            ),
    ];

    options[PackGreenPlayTechs.torrent] = [
      for (final id in TorrentSearchProviders.all)
        _ProviderOption(id: id, label: TorrentSearchProviders.label(id)),
    ];

    if (!mounted) return;
    setState(() {
      _techGates = gates;
      _providerOptions = options;
      _ready = true;
    });
  }

  void _emit(PackGreenPlayConfig next) {
    setState(() => _config = next);
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
            'Technologies and providers for the green Play button on this hub. '
            'Preferred run first; order is start order. Empty provider list = all enabled.',
            style: TextStyle(color: muted, fontSize: 13, height: 1.35),
          ),
        ),
        _TechAllowlistEditor(
          config: _config,
          gates: _techGates,
          onChanged: _emit,
        ),
        for (final tech in PackGreenPlayTechs.all)
          if (_config.techAllowlist.isEmpty ||
              _config.techAllowlist.contains(tech))
            _ProviderAllowlistEditor(
              tech: tech,
              config: _config,
              options: _providerOptions[tech] ?? const [],
              gateOn: _techGates[tech] == true,
              onChanged: _emit,
            ),
      ],
    );
  }
}

class _ProviderOption {
  const _ProviderOption({required this.id, required this.label});
  final String id;
  final String label;
}

class _TechAllowlistEditor extends StatelessWidget {
  const _TechAllowlistEditor({
    required this.config,
    required this.gates,
    required this.onChanged,
  });

  final PackGreenPlayConfig config;
  final Map<String, bool> gates;
  final ValueChanged<PackGreenPlayConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    final allow = config.techAllowlist.isEmpty
        ? List<String>.from(PackGreenPlayTechs.all)
        : List<String>.from(config.techAllowlist);
    final order = config.techOrder.isEmpty
        ? List<String>.from(allow)
        : [
            for (final t in config.techOrder)
              if (allow.contains(t)) t,
            for (final t in allow)
              if (!config.techOrder.contains(t)) t,
          ];
    final preferred = config.techPreferred.toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Technologies',
            style: TextStyle(
              color: ForjaShellColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: order.length,
          onReorder: (oldIndex, newIndex) {
            final working = List<String>.from(order);
            if (oldIndex < 0 || oldIndex >= working.length) return;
            var ni = newIndex;
            if (ni > oldIndex) ni--;
            if (ni < 0 || ni >= working.length) return;
            final item = working.removeAt(oldIndex);
            working.insert(ni, item);
            onChanged(
              PackGreenPlayConfig(
                techAllowlist: allow,
                techPreferred: [
                  for (final t in config.techPreferred)
                    if (working.contains(t)) t,
                ],
                techOrder: working,
                providers: config.providers,
              ),
            );
          },
          itemBuilder: (context, index) {
            // Only show allowlisted techs in drag order; others via checkbox below.
            final tech = order[index];
            final on = true;
            final gate = gates[tech] == true;
            final isPreferred = preferred.contains(tech);
            return ListTile(
              key: ValueKey('tech-$tech'),
              dense: true,
              title: Text(PackGreenPlayTechs.label(tech)),
              subtitle: Text(
                gate
                    ? (isPreferred ? 'Preferred · in race' : 'In race')
                    : 'Play source off — kept in settings, skipped at play',
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              leading: Checkbox(
                value: on,
                onChanged: (v) {
                  if (v == true) return;
                  final nextAllow = List<String>.from(allow)..remove(tech);
                  if (nextAllow.isEmpty) return;
                  onChanged(
                    PackGreenPlayConfig(
                      techAllowlist: nextAllow,
                      techPreferred: [
                        for (final t in config.techPreferred)
                          if (nextAllow.contains(t)) t,
                      ],
                      techOrder: [
                        for (final t in order)
                          if (nextAllow.contains(t)) t,
                      ],
                      providers: config.providers,
                    ),
                  );
                },
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ForjaShellChip(
                    label: 'Preferred',
                    selected: isPreferred,
                    onTap: () {
                      final nextPref = List<String>.from(
                        config.techPreferred,
                      );
                      if (isPreferred) {
                        nextPref.remove(tech);
                      } else if (!nextPref.contains(tech)) {
                        nextPref.add(tech);
                      }
                      onChanged(
                        PackGreenPlayConfig(
                          techAllowlist: allow,
                          techPreferred: nextPref,
                          techOrder: order,
                          providers: config.providers,
                        ),
                      );
                    },
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.drag_handle_rounded),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // Off techs — tap to add back into the race.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tech in PackGreenPlayTechs.all)
              if (!allow.contains(tech))
                ForjaShellChip(
                  label: '+ ${PackGreenPlayTechs.label(tech)}',
                  selected: false,
                  onTap: () {
                    final nextAllow = [...allow, tech];
                    onChanged(
                      PackGreenPlayConfig(
                        techAllowlist: nextAllow,
                        techPreferred: config.techPreferred,
                        techOrder: [...order, tech],
                        providers: config.providers,
                      ),
                    );
                  },
                ),
          ],
        ),
      ],
    );
  }
}

class _ProviderAllowlistEditor extends StatelessWidget {
  const _ProviderAllowlistEditor({
    required this.tech,
    required this.config,
    required this.options,
    required this.gateOn,
    required this.onChanged,
  });

  final String tech;
  final PackGreenPlayConfig config;
  final List<_ProviderOption> options;
  final bool gateOn;
  final ValueChanged<PackGreenPlayConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    final prefs = config.providerPrefs(tech);
    final allIds = [for (final o in options) o.id];
    // Empty allowlist = all enabled.
    final allowAll = prefs.allowlist.isEmpty;
    final allow = allowAll ? allIds : [
      for (final id in prefs.allowlist)
        if (allIds.contains(id)) id,
    ];
    final order = [
      for (final id in prefs.order)
        if (allow.contains(id)) id,
      for (final id in allow)
        if (!prefs.order.contains(id)) id,
    ];
    final preferred = prefs.preferred.toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '${PackGreenPlayTechs.label(tech)} providers'
            '${gateOn ? '' : ' (play source off)'}',
            style: TextStyle(
              color: ForjaShellColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: options.length,
          onReorder: (oldIndex, newIndex) {
            final working = List<String>.from(order);
            if (oldIndex < 0 || oldIndex >= working.length) return;
            var ni = newIndex;
            if (ni > oldIndex) ni--;
            if (ni < 0 || ni > working.length) return;
            // Map visual index (all options) to allow-order — only reorder allowlisted.
            final visualOrdered = [
              for (final id in order) id,
              for (final o in options)
                if (!order.contains(o.id)) o.id,
            ];
            if (oldIndex >= visualOrdered.length) return;
            if (ni > visualOrdered.length) ni = visualOrdered.length;
            final item = visualOrdered.removeAt(oldIndex);
            visualOrdered.insert(ni.clamp(0, visualOrdered.length), item);
            final nextOrder = [
              for (final id in visualOrdered)
                if (allow.contains(id)) id,
            ];
            _emit(
              allowlist: allowAll ? const [] : allow,
              preferred: prefs.preferred,
              order: nextOrder,
            );
          },
          itemBuilder: (context, index) {
            final opt = options[index];
            final on = allow.contains(opt.id);
            final isPreferred = preferred.contains(opt.id);
            return ListTile(
              key: ValueKey('$tech-${opt.id}'),
              dense: true,
              title: Text(opt.label),
              subtitle: isPreferred
                  ? const Text('Preferred', style: TextStyle(fontSize: 12))
                  : null,
              leading: Checkbox(
                value: on,
                onChanged: (v) {
                  var nextAllow = List<String>.from(allow);
                  if (v == true) {
                    if (!nextAllow.contains(opt.id)) nextAllow.add(opt.id);
                  } else {
                    nextAllow.remove(opt.id);
                  }
                  final nextIsAll = nextAllow.length == allIds.length &&
                      allIds.every(nextAllow.contains);
                  _emit(
                    allowlist: nextIsAll ? const [] : nextAllow,
                    preferred: [
                      for (final id in prefs.preferred)
                        if (nextAllow.contains(id)) id,
                    ],
                    order: [
                      for (final id in order)
                        if (nextAllow.contains(id)) id,
                      for (final id in nextAllow)
                        if (!order.contains(id)) id,
                    ],
                  );
                },
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ForjaShellChip(
                    label: 'Preferred',
                    selected: isPreferred,
                    onTap: !on
                        ? null
                        : () {
                            final nextPref = List<String>.from(prefs.preferred);
                            if (isPreferred) {
                              nextPref.remove(opt.id);
                            } else if (!nextPref.contains(opt.id)) {
                              nextPref.add(opt.id);
                            }
                            _emit(
                              allowlist: allowAll ? const [] : allow,
                              preferred: nextPref,
                              order: order,
                            );
                          },
                  ),
                  if (on)
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.drag_handle_rounded),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _emit({
    required List<String> allowlist,
    required List<String> preferred,
    required List<String> order,
  }) {
    final providers = Map<String, PackGreenPlayProviderPrefs>.from(
      config.providers,
    );
    providers[tech] = PackGreenPlayProviderPrefs(
      allowlist: allowlist,
      preferred: preferred,
      order: order,
    );
    onChanged(
      PackGreenPlayConfig(
        techAllowlist: config.techAllowlist,
        techPreferred: config.techPreferred,
        techOrder: config.techOrder,
        providers: providers,
      ),
    );
  }
}
