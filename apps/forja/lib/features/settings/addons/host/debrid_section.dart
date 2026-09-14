import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/ui/focus_controls.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/shared/playback/sources/debrid_js_resolve.dart';
import 'package:rust/rust.dart';

/// Magnet-resolve plugin picker (pack settings render above via RFC-089).
class SettingsDebridSection extends ConsumerStatefulWidget {
  const SettingsDebridSection({super.key});

  @override
  ConsumerState<SettingsDebridSection> createState() =>
      _SettingsDebridSectionState();
}

class _SettingsDebridSectionState extends ConsumerState<SettingsDebridSection> {
  final SettingsService _settings = SettingsService();
  bool _migrated = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await migrateLegacyDebridSecretsToPackStore();
    await syncDebridResolveCatalog();
    if (!mounted) return;
    setState(() => _migrated = true);
    await ref.read(settingsDebridProvider.notifier).reload();
  }

  String _labelFor(SettingsDebridSnapshot snap, String id) {
    for (final p in snap.plugins) {
      if (p.id == id) return p.name;
    }
    return id;
  }

  Future<void> _setEnabled(bool enabled, SettingsDebridSnapshot snap) async {
    if (!enabled) {
      await _settings.setMagnetResolvePluginId('');
      ref.read(settingsDebridProvider.notifier).patch(
            (s) => s.copyWith(enabled: false, pluginId: '', pluginLabel: ''),
          );
      return;
    }
    var id = snap.pluginId.trim();
    if (id.isEmpty) {
      await syncDebridResolveCatalog();
      final list = installedDebridPlugins();
      if (list.isEmpty) {
        await _settings.setMagnetResolvePluginId('');
        ref.read(settingsDebridProvider.notifier).patch(
              (s) => s.copyWith(enabled: false, pluginId: '', pluginLabel: ''),
            );
        return;
      }
      id = list.first.id;
    }
    await _settings.setMagnetResolvePluginId(id);
    ref.read(settingsDebridProvider.notifier).patch(
          (s) => s.copyWith(
            enabled: true,
            pluginId: id,
            pluginLabel: _labelFor(snap, id),
          ),
        );
  }

  Future<void> _setPluginByLabel(
    String? selection,
    SettingsDebridSnapshot snap,
  ) async {
    if (selection == null || selection == 'None') {
      await _setEnabled(false, snap);
      return;
    }
    String? id;
    for (final p in snap.plugins) {
      if (p.name == selection || p.id == selection) {
        id = p.id;
        break;
      }
    }
    if (id == null) {
      await _setEnabled(false, snap);
      return;
    }
    await _settings.setMagnetResolvePluginId(id);
    ref.read(settingsDebridProvider.notifier).patch(
          (s) => s.copyWith(
            enabled: true,
            pluginId: id!,
            pluginLabel: selection,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(settingsDebridProvider).valueOrNull;
    if (snap == null || !_migrated) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final dropdownValue = snap.enabled && snap.pluginId.isNotEmpty
        ? (snap.pluginLabel.isNotEmpty
            ? snap.pluginLabel
            : _labelFor(snap, snap.pluginId))
        : 'None';
    final options = <String>[
      'None',
      ...snap.plugins.map((p) => p.name),
    ];

    return SettingsGroup(
      label: 'Debrid',
      adminOnly: true,
      children: [
        settingsFocusableToggle(
          context,
          'Resolve magnets with debrid',
          'Use an installed debrid pack plugin for torrent magnets.',
          snap.enabled,
          (val) => _setEnabled(val, snap),
        ),
        settingsFocusableDropdown(
          context,
          'Magnet resolve plugin',
          'Only one debrid plugin can be active.',
          dropdownValue,
          options,
          (val) => _setPluginByLabel(val, snap),
        ),
      ],
    );
  }
}
