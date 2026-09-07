import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/foundation/services/pack_addon_settings_spec.dart';
import 'package:forja/shared/foundation/services/pack_settings_store.dart';

/// Renders pack-declared Addon settings fields for [addonId] (RFC-089).
class PackAddonSettingsSection extends StatefulWidget {
  const PackAddonSettingsSection({super.key, required this.addonId});

  final String addonId;

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
    EngineService.changeNotifier.addListener(_onEngineChanged);
    unawaited(_reload());
  }

  @override
  void dispose() {
    EngineService.changeNotifier.removeListener(_onEngineChanged);
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
    final packs = await EngineService.instance.listPacks();
    final plugins = <EnginePlugin>[
      for (final pack in packs)
        if (pack.enabled)
          for (final p in pack.plugins) p,
    ];
    final specs = PackAddonSettingsSpec.listForAddon(
      plugins,
      addonId: widget.addonId,
    );
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
        if (field.type != PackAddonSettingsFieldType.text) continue;
        final k = _valueKey(spec.pluginId, field.id);
        keep.add(k);
        final text = (values[k] ?? field.defaultString).toString();
        final existing = _textControllers[k];
        if (existing == null) {
          final c = TextEditingController(text: text);
          c.addListener(() {
            unawaited(
              PackSettingsStore.setString(spec.pluginId, field.id, c.text),
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
        final controller = _textControllers[key];
        if (controller == null) return const SizedBox.shrink();
        return SettingsTextField(
          controller: controller,
          label: field.label,
          hint: field.subtitle.isEmpty ? null : field.subtitle,
        );
    }
  }
}
