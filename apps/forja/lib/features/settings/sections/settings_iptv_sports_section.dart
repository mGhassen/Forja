import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_engine_plugin_pack.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';

/// Addons → Live Sports — live catalog/provider capability toggles only.
///
/// Product Setup (Forja Live / Sports / merge / leagues) is declared on the
/// Live Sports hub pack `settings` block and rendered by
/// [PackAddonSettingsSection] (RFC-089).
class SettingsIptvSportsSection extends StatefulWidget {
  const SettingsIptvSportsSection({super.key});

  @override
  State<SettingsIptvSportsSection> createState() =>
      _SettingsIptvSportsSectionState();
}

class _SettingsIptvSportsSectionState extends State<SettingsIptvSportsSection> {
  bool _loading = true;
  List<({EnginePack pack, List<EnginePlugin> plugins})> _liveSportPacks =
      const [];

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
    unawaited(_reload());
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    await EngineService.instance.ensureOfficialInstalled();
    final packs = await EngineService.instance.listPacks();
    final liveSports = <({EnginePack pack, List<EnginePlugin> plugins})>[];
    for (final pack in packs) {
      final sportPlugins = [
        for (final p in pack.plugins)
          if (p.isLiveSportPlugin && p.isHttp) p,
      ]..sort((a, b) => a.name.compareTo(b.name));
      if (sportPlugins.isEmpty) continue;
      liveSports.add((pack: pack, plugins: sportPlugins));
    }
    if (!mounted) return;
    setState(() {
      _liveSportPacks = liveSports;
      _loading = false;
    });
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

    if (_liveSportPacks.isEmpty) {
      return SettingsGroup(
        label: 'Catalogs & providers',
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
            child: Text(
              'No live catalog packs installed. Install ForjaHQ Live (or other '
              'live packs) under Settings → Forja Packs. Setup toggles come '
              'from the Live Sports hub pack settings above.',
              style: TextStyle(
                color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
    }

    return SettingsGroup(
      label: 'Catalogs & providers',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
          child: Text(
            'Catalog = schedule feed · Provider = stream resolve. '
            'Manage packs under Settings → Forja Packs.',
            style: TextStyle(
              color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
        for (final entry in _liveSportPacks) ...[
          if (_liveSportPacks.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
              child: Text(
                '${entry.pack.name} · v${entry.pack.version}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: ForjaShellColors.textPrimary,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
            child: SettingsLiveSportCapabilityTabs(
              sourceUrl: entry.pack.sourceUrl,
              plugins: entry.plugins,
              tabRowId:
                  'forja-sports-live-tabs-${entry.pack.sourceUrl.hashCode}',
            ),
          ),
        ],
      ],
    );
  }
}
