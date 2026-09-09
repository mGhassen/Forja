import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/foundation/services/pack/pack_addon_settings_spec.dart';
import 'package:forja/shared/foundation/services/pack/pack_settings_store.dart';
import 'package:forja/shared/foundation/tv/shell_tv_coordinator.dart';

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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
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
      specs = PackAddonSettingsSpec.listForPlugins(plugins);
    } else {
      final packs = await EngineService.instance.listPacks();
      final all = <EnginePlugin>[
        for (final pack in packs)
          if (pack.enabled)
            for (final p in pack.plugins) p,
      ];
      specs = PackAddonSettingsSpec.listForAddon(
        all,
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
          PackAddonSettingsFieldType.text =>
            await PackSettingsStore.getString(
              spec.pluginId,
              field.id,
              defaultValue: field.defaultString,
            ),
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
          c.addListener(() {
            unawaited(
              isSecret
                  ? PackSettingsStore.setSecret(spec.pluginId, field.id, c.text)
                  : PackSettingsStore.setString(spec.pluginId, field.id, c.text),
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

  Future<void> _setBool(
    PackAddonSettingsSpec spec,
    PackAddonSettingsField field,
    bool value,
  ) async {
    await PackSettingsStore.setBool(spec.pluginId, field.id, value);
    if (!mounted) return;
    setState(() => _values[_valueKey(spec.pluginId, field.id)] = value);
  }

  Future<void> _setString(
    PackAddonSettingsSpec spec,
    PackAddonSettingsField field,
    String value,
  ) async {
    await PackSettingsStore.setString(spec.pluginId, field.id, value);
    if (!mounted) return;
    setState(() => _values[_valueKey(spec.pluginId, field.id)] = value);
  }

  Future<void> _setStringList(
    PackAddonSettingsSpec spec,
    PackAddonSettingsField field,
    List<String> value,
  ) async {
    await PackSettingsStore.setStringList(spec.pluginId, field.id, value);
    if (!mounted) return;
    setState(() => _values[_valueKey(spec.pluginId, field.id)] = value);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _specs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final spec in _specs)
          SettingsGroup(
            label: spec.group,
            children: [
              for (final field in spec.fields) _fieldRow(spec, field),
            ],
          ),
      ],
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
    }
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
              fontSize: 13,
            ),
          ),
          if (field.subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              field.subtitle,
              style: TextStyle(
                color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
                fontSize: 12,
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < options.length; i++)
                ForjaShellChip(
                  label: options[i].label,
                  selected: selected.contains(options[i].id),
                  listIndex: i,
                  fontSize: 12,
                  accentHover: true,
                  tvTabId: tv ? 'settings' : null,
                  tvRowId: tv ? 'pack-settings-${field.id}' : null,
                  ensureVisibleMode: ShellTvEnsureVisibleMode.item,
                  onTap: () {
                    final next = Set<String>.from(selected);
                    if (!next.add(options[i].id)) next.remove(options[i].id);
                    onChanged(next.toList()..sort());
                  },
                ),
            ],
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
}
