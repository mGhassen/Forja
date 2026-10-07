import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/shared/engine/engine.dart';

import 'package:forja/shared/engine/packs/settings/pack_addon_settings_spec.dart';
import 'package:forja/shared/engine/runtime/meta/plugin_actions.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shared/engine/packs/settings/pack_hub_select_options.dart';
import 'package:forja/shared/engine/packs/settings/pack_settings_store.dart';
import 'package:forja/shared/engine/store/list_open_prefs.dart';
import 'package:forja/shared/sync/bridge/sync_domain_bridge.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
/// Renders pack-declared settings fields (RFC-089 / RFC-093).
///
/// Pass [addonId] for host Addon detail pages, or [plugins] for Forja Packs
/// expand rows. Prefer [plugins] when embedding under a pack.
class PackAddonSettingsSection extends StatefulWidget {
  const PackAddonSettingsSection({
    super.key,
    this.addonId,
    this.plugins,
  }) : assert(addonId != null || plugins != null);

  /// Host Addon id — loads enabled plugins contributing `settings.addon`.
  final String? addonId;

  /// Pack plugins — shows any with `settings.fields` (addon id optional).
  final List<EnginePlugin>? plugins;

  @override
  State<PackAddonSettingsSection> createState() =>
      _PackAddonSettingsSectionState();
}

class _PackAddonSettingsSectionState extends State<PackAddonSettingsSection> {
  List<PackAddonSettingsSpec> _specs = const [];
  final Map<String, dynamic> _values = {};
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, Timer> _hubDebounce = {};
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
  void didUpdateWidget(covariant PackAddonSettingsSection oldWidget) {
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
    for (final t in _hubDebounce.values) {
      t.cancel();
    }
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onEngineChanged() {
    if (!mounted) return;
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final List<PackAddonSettingsSpec> specs;
    final plugins = widget.plugins;
    if (plugins != null) {
      // Caller owns the pack gate (Forja Packs expand only when pack.enabled).
      specs = PackAddonSettingsSpec.listForPlugins(plugins);
    } else {
      final packs = await EngineService.instance.listPacks();
      specs = PackAddonSettingsSpec.listForAddon(
        activePluginsFromPacks(packs),
        addonId: widget.addonId!,
      );
    }
    final values = <String, dynamic>{};
    for (final spec in specs) {
      for (final field in spec.fields) {
        final k = _valueKey(spec.pluginId, field.id);
        values[k] = switch (field.type) {
          PackAddonSettingsFieldType.toggle => await PackSettingsStore.getBool(
              spec.pluginId,
              field.id,
              defaultValue: field.defaultBool,
            ),
          PackAddonSettingsFieldType.select ||
          PackAddonSettingsFieldType.hubSelect ||
          PackAddonSettingsFieldType.text =>
            await _loadString(spec, field),
          PackAddonSettingsFieldType.password =>
            await PackSettingsStore.getSecret(
              spec.pluginId,
              field.id,
              defaultValue: field.defaultString,
            ),
          PackAddonSettingsFieldType.multiSelect =>
            await PackSettingsStore.getStringList(
              spec.pluginId,
              field.id,
              defaultValue: field.defaultStringList,
            ),
          PackAddonSettingsFieldType.actionList => null,
        };
      }
    }
    if (!mounted) return;
    setState(() {
      _specs = specs;
      _values
        ..clear()
        ..addAll(values);
      _syncTextControllers(values, specs);
      _loading = false;
    });
  }

  void _syncTextControllers(
    Map<String, dynamic> values,
    List<PackAddonSettingsSpec> specs,
  ) {
    final keep = <String>{};
    for (final spec in specs) {
      for (final field in spec.fields) {
        if (field.type != PackAddonSettingsFieldType.text &&
            field.type != PackAddonSettingsFieldType.password) {
          continue;
        }
        final k = _valueKey(spec.pluginId, field.id);
        keep.add(k);
        final text = (values[k] ?? field.defaultString).toString();
        final existing = _textControllers[k];
        if (existing == null) {
          final c = TextEditingController(text: text);
          final isSecret = field.type == PackAddonSettingsFieldType.password;
          final pluginId = spec.pluginId;
          final fieldId = field.id;
          c.addListener(() {
            // Persist every keystroke; debounce hub reload (not Settings remount).
            unawaited(
              isSecret
                  ? PackSettingsStore.setSecret(
                      pluginId,
                      fieldId,
                      c.text,
                      reloadHub: false,
                    )
                  : PackSettingsStore.setString(
                      pluginId,
                      fieldId,
                      c.text,
                      reloadHub: false,
                    ),
            );
            final debounceKey = _valueKey(pluginId, fieldId);
            _hubDebounce[debounceKey]?.cancel();
            _hubDebounce[debounceKey] = Timer(
              const Duration(milliseconds: 400),
              () => PluginRegistry.bumpHubFeedEpoch(
                pluginIds: [pluginId],
                forceNetwork: false,
              ),
            );
          });
          _textControllers[k] = c;
        } else if (existing.text != text) {
          existing.text = text;
        }
      }
    }
    final drop = _textControllers.keys.where((k) => !keep.contains(k)).toList();
    for (final k in drop) {
      _textControllers.remove(k)?.dispose();
    }
  }

  static String _valueKey(String pluginId, String fieldId) =>
      '$pluginId::$fieldId';

  Future<String> _loadString(
    PackAddonSettingsSpec spec,
    PackAddonSettingsField field,
  ) async {
    if (field.type == PackAddonSettingsFieldType.hubSelect &&
        field.listOpenDefault &&
        field.hubTypes.isNotEmpty) {
      final fromPrefs =
          await ListOpenPrefs.defaultPluginId(field.hubTypes.first);
      if (fromPrefs != null && fromPrefs.isNotEmpty) return fromPrefs;
    }
    return PackSettingsStore.getString(
      spec.pluginId,
      field.id,
      defaultValue: field.defaultString,
    );
  }

  Future<void> _setBool(
    PackAddonSettingsSpec spec,
    PackAddonSettingsField field,
    bool value,
  ) async {
    await PackSettingsStore.setBool(
      spec.pluginId,
      field.id,
      value,
      reloadHub: field.reloadHub,
    );
    if (!mounted) return;
    setState(() => _values[_valueKey(spec.pluginId, field.id)] = value);
  }

  Future<void> _setString(
    PackAddonSettingsSpec spec,
    PackAddonSettingsField field,
    String value,
  ) async {
    await PackSettingsStore.setString(
      spec.pluginId,
      field.id,
      value,
      reloadHub: field.reloadHub,
    );
    if (field.type == PackAddonSettingsFieldType.hubSelect &&
        field.listOpenDefault) {
      final id = value.trim();
      for (final t in field.hubTypes) {
        await ListOpenPrefs.setDefaultPluginId(
          t,
          id.isEmpty ? null : id,
        );
      }
    }
    if (!mounted) return;
    setState(() => _values[_valueKey(spec.pluginId, field.id)] = value);
  }

  Future<void> _setStringList(
    PackAddonSettingsSpec spec,
    PackAddonSettingsField field,
    List<String> value,
  ) async {
    await PackSettingsStore.setStringList(
      spec.pluginId,
      field.id,
      value,
      reloadHub: field.reloadHub,
    );
    if (!mounted) return;
    setState(() => _values[_valueKey(spec.pluginId, field.id)] = value);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _specs.isEmpty) return const SizedBox.shrink();

    final groups = <Widget>[
      for (final spec in _specs)
        if (spec.fields.isNotEmpty)
          SettingsGroup(
            label: spec.group,
            children: [
              for (final field in spec.fields) _fieldRow(spec, field),
            ],
          ),
    ];
    if (groups.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: groups,
    );
  }

  Widget _fieldRow(
    PackAddonSettingsSpec spec,
    PackAddonSettingsField field,
  ) {
    final key = _valueKey(spec.pluginId, field.id);
    switch (field.type) {
      case PackAddonSettingsFieldType.toggle:
        final value = _values[key] == true;
        return SettingsToggleRow(
          title: field.label,
          subtitle: field.subtitle,
          value: value,
          onChanged: (v) => unawaited(_setBool(spec, field, v)),
        );
      case PackAddonSettingsFieldType.select:
        final id = (_values[key] ?? field.defaultString).toString();
        final labels = [for (final o in field.options) o.label];
        final labelById = {for (final o in field.options) o.id: o.label};
        final idByLabel = {for (final o in field.options) o.label: o.id};
        final shown = labelById[id] ?? id;
        return SettingsSelectRow(
          title: field.label,
          subtitle: field.subtitle,
          value: shown,
          options: labels,
          onChanged: (picked) {
            if (picked == null) return;
            final next = idByLabel[picked] ?? picked;
            unawaited(_setString(spec, field, next));
          },
        );
      case PackAddonSettingsFieldType.hubSelect:
        return _HubSelectField(
          field: field,
          value: (_values[key] ?? field.defaultString).toString(),
          onChanged: (next) => unawaited(_setString(spec, field, next)),
        );
      case PackAddonSettingsFieldType.text:
      case PackAddonSettingsFieldType.password:
        final controller = _textControllers[key];
        if (controller == null) return const SizedBox.shrink();
        return SettingsTextField(
          controller: controller,
          label: field.label,
          hint: field.subtitle.isEmpty ? null : field.subtitle,
          obscureText: field.type == PackAddonSettingsFieldType.password,
        );
      case PackAddonSettingsFieldType.multiSelect:
        final selected = <String>{
          ...((_values[key] as List?)?.map((e) => e.toString()) ??
              field.defaultStringList),
        };
        return _MultiSelectChipsField(
          field: field,
          selected: selected,
          onChanged: (next) => unawaited(_setStringList(spec, field, next)),
        );
      case PackAddonSettingsFieldType.actionList:
        return _ActionListField(
          key: ValueKey(key),
          pluginId: spec.pluginId,
          field: field,
        );
    }
  }
}

/// One pack-returned row of an `action_list` field.
class _ActionListRow {
  const _ActionListRow({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.actionId,
    required this.actionIcon,
    required this.destructive,
  });

  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final bool accent;
  final String actionId;
  final String actionIcon;
  final bool destructive;

  static _ActionListRow? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = (m['id'] ?? '').toString().trim();
    final title = (m['title'] ?? '').toString().trim();
    if (id.isEmpty || title.isEmpty) return null;
    final action = m['action'];
    var actionId = '';
    var actionIcon = '';
    var destructive = m['destructive'] == true;
    if (action is Map) {
      actionId = (action['id'] ?? '').toString().trim();
      actionIcon = (action['icon'] ?? '').toString().trim();
      destructive = destructive || action['destructive'] == true;
    } else if (action is String) {
      actionId = action.trim();
    }
    return _ActionListRow(
      id: id,
      title: title,
      subtitle: (m['subtitle'] ?? '').toString(),
      icon: (m['icon'] ?? '').toString().trim(),
      accent: (m['tone'] ?? '').toString().trim() == 'accent',
      actionId: actionId,
      actionIcon: actionIcon,
      destructive: destructive,
    );
  }
}

/// Paints rows a pack returns from its list action; taps run its item action.
///
/// The host knows nothing about what the rows are — titles, copy, icons and
/// the action vocabulary come from the pack envelope.
class _ActionListField extends StatefulWidget {
  const _ActionListField({
    super.key,
    required this.pluginId,
    required this.field,
  });

  final String pluginId;
  final PackAddonSettingsField field;

  @override
  State<_ActionListField> createState() => _ActionListFieldState();
}

class _ActionListFieldState extends State<_ActionListField> {
  List<_ActionListRow> _rows = const [];
  _ActionListRow? _footer;
  String _empty = '';
  bool _loading = true;
  String? _busyRowId;
  Timer? _poll;
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    final every = widget.field.refreshSeconds;
    if (every > 0) {
      // TabBarView / offstage keep this State alive — only hit the pack when
      // the list is actually painted on screen.
      _poll = Timer.periodic(Duration(seconds: every), (_) {
        if (!mounted || !_isPaintedOnScreen()) return;
        unawaited(_load());
      });
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// False when this field is off-screen (other Downloads tab, scrolled away,
  /// or Settings body torn down but a neighbor PageView page still mounted).
  bool _isPaintedOnScreen() {
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize || ro.size.isEmpty) {
      return false;
    }
    final rect = MatrixUtils.transformRect(
      ro.getTransformTo(null),
      Offset.zero & ro.size,
    );
    return rect.overlaps(Offset.zero & MediaQuery.sizeOf(context));
  }

  Future<void> _load() async {
    final gen = ++_loadGen;
    final env = await MetaRuntime.instance.run(
      pluginId: widget.pluginId,
      action: widget.field.action,
      forceRefresh: true,
    );
    if (!mounted || gen != _loadGen) return;
    final data = env.data ?? const <String, dynamic>{};
    final rawRows = data['rows'];
    final rows = <_ActionListRow>[
      if (rawRows is List)
        for (final e in rawRows) ?_ActionListRow.fromJson(e),
    ];
    setState(() {
      _rows = rows;
      _footer = _ActionListRow.fromJson(data['footer']);
      _empty = (data['empty'] ?? '').toString();
      _loading = false;
    });
  }

  Future<void> _tap(_ActionListRow row) async {
    final itemAction = widget.field.itemAction;
    if (itemAction.isEmpty || row.actionId.isEmpty || _busyRowId != null) {
      return;
    }
    setState(() => _busyRowId = row.id);
    try {
      final env = await MetaRuntime.instance.run(
        pluginId: widget.pluginId,
        action: itemAction,
        params: {'row': row.id, 'action': row.actionId},
        forceRefresh: true,
      );
      if (!mounted) return;
      final message = (env.data?['message'] ?? '').toString().trim();
      if (env.ok) {
        if (message.isNotEmpty) ForjaToast.success(message);
      } else {
        final err = env.error?.message.trim() ?? '';
        ForjaToast.error(
          message.isNotEmpty
              ? message
              : err.isNotEmpty
                  ? err
                  : 'Could not ${row.actionId} ${row.title}',
        );
      }
    } finally {
      if (mounted) setState(() => _busyRowId = null);
      await _load();
    }
  }

  static IconData _iconFor(String name, IconData fallback) {
    return switch (name) {
      'play' => Icons.play_circle_rounded,
      'download' => Icons.downloading_rounded,
      'pause' => Icons.pause_circle_rounded,
      'stop' => Icons.stop_circle_rounded,
      'delete' => Icons.delete_outline_rounded,
      'delete_all' => Icons.delete_sweep_rounded,
      'check' => Icons.check_circle_rounded,
      'error' => Icons.error_outline_rounded,
      'folder' => Icons.folder_outlined,
      'link' => Icons.link_rounded,
      _ => fallback,
    };
  }

  Widget _row(_ActionListRow row) {
    return SettingsActionRow(
      title: row.title,
      subtitle: row.subtitle.isEmpty ? null : row.subtitle,
      leading: row.icon.isEmpty
          ? null
          : Icon(
              _iconFor(row.icon, Icons.circle_outlined),
              color: row.accent
                  ? ForjaShellColors.brandGreen
                  : ForjaShellColors.iconMuted,
            ),
      trailing: row.actionId.isEmpty
          ? const SizedBox.shrink()
          : Icon(
              _iconFor(row.actionIcon, Icons.chevron_right_rounded),
              color: ForjaShellColors.textSecondary,
            ),
      destructive: row.destructive,
      busy: _busyRowId == row.id,
      onTap: row.actionId.isEmpty ? null : () => unawaited(_tap(row)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      final copy = _empty.isNotEmpty
          ? _empty
          : widget.field.emptyText.isNotEmpty
              ? widget.field.emptyText
              : widget.field.subtitle;
      if (copy.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 12),
        child: Text(
          copy,
          style: TextStyle(
            color: ForjaShellColors.textSecondary,
            fontSize: SettingsTokens.rowSubtitleSizeOf(context),
            height: 1.35,
          ),
        ),
      );
    }
    final footer = _footer;
    final footerRow = footer == null ? null : _row(footer);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in _rows) _row(row),
        ?footerRow,
      ],
    );
  }
}

class _MultiSelectChipsField extends StatelessWidget {
  const _MultiSelectChipsField({
    required this.field,
    required this.selected,
    required this.onChanged,
  });

  final PackAddonSettingsField field;
  final Set<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = field.options;
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            field.label,
            style: TextStyle(
              color: ForjaShellColors.textPrimary.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
              fontSize: SettingsTokens.typeSizeOf(context, 13),
            ),
          ),
          if (field.subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              field.subtitle,
              style: TextStyle(
                color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
                fontSize: SettingsTokens.typeSizeOf(context, 12),
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _allNoneButton(
                context,
                label: 'All',
                onPressed: () =>
                    onChanged([for (final o in options) o.id]),
              ),
              _allNoneButton(
                context,
                label: 'None',
                onPressed: () => onChanged(const []),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              Widget chips = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < options.length; i++)
                    ForjaShellChip(
                      label: options[i].label,
                      selected: selected.contains(options[i].id),
                      listIndex: i,
                      fontSize: SettingsTokens.typeSizeOf(context, 12),
                      accentHover: true,
                      ensureVisibleMode: ShellPaintEnsureVisible.item,
                      onTap: () {
                        final next = Set<String>.from(selected);
                        if (!next.add(options[i].id)) {
                          next.remove(options[i].id);
                        }
                        onChanged(next.toList()..sort());
                      },
                    ),
                ],
              );
              if (!tv) return chips;
              return ShellPaintTvRowScope(
                tabId: 'settings',
                rowId: 'pack-settings-${field.id}',
                child: chips,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _allNoneButton(
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
      borderRadius: SettingsTokens.categoryTileRadius,
      scaleOnFocus: 1.0,
      showFocusRail: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      ensureVisibleMode: ShellPaintEnsureVisible.item,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: ForjaShellColors.brandGreen,
            fontWeight: FontWeight.w600,
            fontSize: SettingsTokens.typeSizeOf(context, 13),
          ),
        ),
      ),
    );
  }
}

class _HubSelectField extends StatefulWidget {
  const _HubSelectField({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final PackAddonSettingsField field;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_HubSelectField> createState() => _HubSelectFieldState();
}

class _HubSelectFieldState extends State<_HubSelectField> {
  List<PackAddonSettingsOption> _options = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _HubSelectField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.field.hubTypes.join() != widget.field.hubTypes.join()) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final opts = await PackHubSelectOptions.optionsFor(widget.field);
    if (!mounted) return;
    setState(() {
      _options = opts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SettingsSelectRow(
        title: widget.field.label,
        subtitle: widget.field.subtitle,
        value: '…',
        options: const ['…'],
        onChanged: (_) {},
      );
    }
    final id = widget.value;
    final labelById = {for (final o in _options) o.id: o.label};
    final idByLabel = {for (final o in _options) o.label: o.id};
    final shown = labelById[id] ?? (id.isEmpty ? 'Auto' : id);
    return SettingsSelectRow(
      title: widget.field.label,
      subtitle: widget.field.subtitle,
      value: shown,
      options: [for (final o in _options) o.label],
      onChanged: (picked) {
        if (picked == null) return;
        final next = idByLabel[picked] ?? '';
        widget.onChanged(next);
      },
    );
  }
}
