import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/providers/stremio_addons_provider.dart';
import 'package:forja/features/settings/settings_visibility.dart';
import 'package:forja/features/settings/widgets/settings_engine_plugin_pack.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// Stremio addons, Nuvio scrapers, Jackett, and Prowlarr.
class SettingsProvidersSection extends ConsumerStatefulWidget {
  const SettingsProvidersSection({super.key, required this.visibility});

  final SettingsVisibility visibility;

  @override
  ConsumerState<SettingsProvidersSection> createState() =>
      _SettingsProvidersSectionState();
}

class _SettingsProvidersSectionState
    extends ConsumerState<SettingsProvidersSection> {
  final SettingsService _settings = SettingsService();
  final StremioService _stremio = StremioService();
  final JackettService _jackett = JackettService();
  final ProwlarrService _prowlarr = ProwlarrService();

  bool _isInstalling = false;
  final TextEditingController _addonController = TextEditingController();
  final TextEditingController _nuvioController = TextEditingController();
  bool _nuvioInstalling = false;
  final TextEditingController _engineController = TextEditingController();
  bool _engineInstalling = false;

  final TextEditingController _jackettUrlController = TextEditingController();
  final TextEditingController _jackettApiKeyController = TextEditingController();
  bool _isTestingJackett = false;
  String? _jackettTestResult;

  final TextEditingController _prowlarrUrlController = TextEditingController();
  final TextEditingController _prowlarrApiKeyController = TextEditingController();
  bool _isTestingProwlarr = false;
  String? _prowlarrTestResult;
  List<ProwlarrTag> _prowlarrAvailableTags = [];
  Set<int> _prowlarrSelectedTagIds = {};
  bool _prowlarrTagsLoaded = false;
  bool _indexersHydrated = false;

  @override
  void dispose() {
    _addonController.dispose();
    _nuvioController.dispose();
    _engineController.dispose();
    _jackettUrlController.dispose();
    _jackettApiKeyController.dispose();
    _prowlarrUrlController.dispose();
    _prowlarrApiKeyController.dispose();
    _jackett.dispose();
    _prowlarr.dispose();
    super.dispose();
  }

  void _hydrateIndexers(SettingsIndexerSnapshot snap) {
    _jackettUrlController.text = snap.jackettUrl;
    _jackettApiKeyController.text = snap.jackettApiKey;
    _prowlarrUrlController.text = snap.prowlarrUrl;
    _prowlarrApiKeyController.text = snap.prowlarrApiKey;
    _prowlarrSelectedTagIds = Set.of(snap.prowlarrSelectedTagIds);
    _indexersHydrated = true;
    if (snap.prowlarrUrl.isNotEmpty && snap.prowlarrApiKey.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _tryLoadProwlarrTags(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final addonsAsync = ref.watch(stremioAddonsProvider);
    final installedAddons = addonsAsync.valueOrNull ?? const [];
    final nuvioAddons = ref.watch(nuvioAddonsProvider).valueOrNull ?? const [];
    final enginePacks = ref.watch(enginePacksProvider).valueOrNull ?? const [];
    final indexerSnap = ref.watch(settingsIndexerProvider).valueOrNull;
    if (indexerSnap != null && !_indexersHydrated) {
      _hydrateIndexers(indexerSnap);
    }
    final v = widget.visibility;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (v.showEngine)
          SettingsGroup(
            label: 'Forja plugins',
            children: [
              _buildEnginePackSection(enginePacks),
            ],
          ),
        if (v.showStremioAddons)
          SettingsGroup(
            label: 'Stremio addons',
            children: [
              if (addonsAsync.isLoading && installedAddons.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                _buildAddonInput(installedAddons),
            ],
          ),
        if (v.showNuvio)
          SettingsGroup(
            label: 'Nuvio addons',
            children: [
              _buildNuvioAddonSection(nuvioAddons),
            ],
          ),
        if (v.showJackettProwlarr) ...[
          SettingsGroup(
            label: 'Jackett',
            adminOnly: true,
            children: [_buildJackettConfig()],
          ),
          SettingsGroup(
            label: 'Prowlarr',
            adminOnly: true,
            children: [_buildProwlarrConfig()],
          ),
        ],
      ],
    );
  }
  Future<void> _installAddon() async {
    final url = _addonController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isInstalling = true);

    try {
      final addonData = await _stremio.fetchManifest(url);
      if (addonData != null) {
        await _settings.saveStremioAddon(addonData);
        _addonController.clear();
        // saveStremioAddon bumps addonChangeNotifier → stremioAddonsProvider.
        scheduleStremioSyncPush();
        if (mounted) ForjaToast.success('Addon installed successfully!');
      } else {
        if (mounted) ForjaToast.error('Failed to install addon. Check URL.');
      }
    } catch (e) {
      if (mounted) ForjaToast.error('Error: $e');
    } finally {
      if (mounted) setState(() => _isInstalling = false);
    }
  }

  Future<void> _removeAddon(String baseUrl) async {
    await _settings.removeStremioAddon(baseUrl);
    scheduleStremioSyncPush();
    if (mounted) ForjaToast.success('Addon removed');
  }

  Future<void> _setAddonEnabled(Map<String, dynamic> addon, bool enabled) async {
    final baseUrl = addon['baseUrl']?.toString() ?? '';
    if (baseUrl.isEmpty) return;
    if (StremioAddonFeatures.isEnabled(addon) == enabled) return;
    final updated = Map<String, dynamic>.from(addon);
    updated['enabled'] = enabled;
    await _settings.saveStremioAddon(updated);
    scheduleStremioSyncPush();
  }

  Future<void> _setAddonFeatures(
    Map<String, dynamic> addon,
    String feature,
  ) async {
    final baseUrl = addon['baseUrl']?.toString() ?? '';
    if (baseUrl.isEmpty) return;
    final current = StremioAddonFeatures.read(addon);
    final next = StremioAddonFeatures.toggle(current, feature);
    if (next.length == current.length &&
        next.every(current.contains)) {
      return;
    }
    final updated = Map<String, dynamic>.from(addon);
    updated['features'] = next;
    await _settings.saveStremioAddon(updated);
    scheduleStremioSyncPush();
  }

  Widget _buildAddonInput(List<Map<String, dynamic>> installedAddons) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsTextField(
            controller: _addonController,
            label: 'Install Stremio Addon',
            hint: 'stremio://... or https://...',
            onSubmitted: (_) => _installAddon(),
          ),
          const SizedBox(height: 14),
          SettingsFilledButton(
            label: 'Install',
            icon: Icons.add_rounded,
            busy: _isInstalling,
            onPressed: _installAddon,
          ),
          if (installedAddons.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SettingsEngineMiniLabel('Installed addons'),
            const SizedBox(height: 4),
            ...installedAddons.map((addon) {
              final icon = addon['icon']?.toString().trim() ?? '';
              final name = addon['name']?.toString().trim();
              final baseUrl = addon['baseUrl']?.toString().trim() ?? '';
              final features = StremioAddonFeatures.read(addon);
              final enabled = StremioAddonFeatures.isEnabled(addon);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AddonRemoveRow(
                      leading: icon.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                icon,
                                width: 28,
                                height: 28,
                                errorBuilder: (c, e, s) => const Icon(
                                  Icons.extension,
                                  color: ForjaShellColors.iconActive,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.extension,
                              color: ForjaShellColors.iconActive,
                            ),
                      title: (name == null || name.isEmpty)
                          ? 'Untitled addon'
                          : name,
                      subtitle: baseUrl,
                      enabled: enabled,
                      onEnabledChanged: (v) => unawaited(
                        _setAddonEnabled(addon, v),
                      ),
                      onRemove: () => _removeAddon(baseUrl),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _AddonFeatureChip(
                            label: 'Sources',
                            selected: features.contains(
                              StremioAddonFeatures.vod,
                            ),
                            onTap: () => unawaited(
                              _setAddonFeatures(
                                addon,
                                StremioAddonFeatures.vod,
                              ),
                            ),
                          ),
                          _AddonFeatureChip(
                            label: 'Live Matches',
                            selected: features.contains(
                              StremioAddonFeatures.live,
                            ),
                            onTap: () => unawaited(
                              _setAddonFeatures(
                                addon,
                                StremioAddonFeatures.live,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildNuvioAddonSection(List<NuvioAddon> nuvioAddons) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsTextField(
            controller: _nuvioController,
            label: 'Install Nuvio Addon',
            hint: 'https://.../manifest.json',
            onSubmitted: (_) => _installNuvioAddon(),
          ),
          const SizedBox(height: 14),
          SettingsFilledButton(
            label: 'Install',
            icon: Icons.add_rounded,
            busy: _nuvioInstalling,
            onPressed: _installNuvioAddon,
          ),
          if (nuvioAddons.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SettingsEngineMiniLabel('Nuvio addons'),
            const SizedBox(height: 4),
            ...nuvioAddons.map(
              (addon) {
                final builtIn = NuvioService.isBundled(addon.manifestUrl);
                final allOn = addon.scrapers.isNotEmpty &&
                    addon.scrapers.every((s) => s.enabled);
                return Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 2),
                    childrenPadding: const EdgeInsets.fromLTRB(8, 0, 2, 8),
                    leading: const Icon(
                      Icons.code_rounded,
                      color: ForjaShellColors.iconActive,
                    ),
                    title: Text(
                      builtIn ? '${addon.name} (Built-in)' : addon.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: ForjaShellColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${addon.scrapers.length} scraper${addon.scrapers.length == 1 ? '' : 's'} \u00b7 v${addon.version}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: ForjaShellColors.textSecondary,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ForjaSwitch(
                          value: allOn,
                          scale: ForjaSwitch.settingsScale,
                          onChanged: addon.scrapers.isEmpty
                              ? null
                              : (val) async {
                                  await NuvioService.instance
                                      .setAllScrapersEnabled(
                                    manifestUrl: addon.manifestUrl,
                                    enabled: val,
                                  );
                                },
                        ),
                        if (!builtIn)
                          _AddonRemoveActions(
                            onRemove: () =>
                                _removeNuvioAddon(addon.manifestUrl),
                          ),
                      ],
                    ),
                    children: addon.scrapers.map((s) {
                      final subtitle = [
                        if (s.description != null && s.description!.isNotEmpty)
                          s.description!,
                        if (s.supportedTypes.isNotEmpty)
                          s.supportedTypes.join(', '),
                      ].join(' \u00b7 ');
                      return SettingsToggleRow(
                        title: s.name,
                        subtitle: subtitle.isEmpty ? 'Scraper' : subtitle,
                        value: s.enabled,
                        onChanged: (val) async {
                          await NuvioService.instance.setScraperEnabled(
                            manifestUrl: addon.manifestUrl,
                            scraperId: s.id,
                            enabled: val,
                          );
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _installNuvioAddon() async {
    final url = _nuvioController.text.trim();
    if (url.isEmpty) return;
    setState(() => _nuvioInstalling = true);
    try {
      final addon = await NuvioService.instance.install(url);
      if (!mounted) return;
      _nuvioController.clear();
      ForjaToast.success(
        'Installed ${addon.name} (${addon.scrapers.length} scrapers)',
      );
      scheduleNuvioSyncPush();
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('Install failed: $e');
    } finally {
      if (mounted) setState(() => _nuvioInstalling = false);
    }
  }

  Future<void> _removeNuvioAddon(String manifestUrl) async {
    if (NuvioService.isBundled(manifestUrl)) {
      if (!mounted) return;
      ForjaToast.error('Built-in Nuvio addon cannot be removed');
      return;
    }
    try {
      await NuvioService.instance.remove(manifestUrl);
      scheduleNuvioSyncPush();
      if (!mounted) return;
      ForjaToast.success('Nuvio addon removed');
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('$e');
    }
  }

  Widget _buildEnginePackSection(List<EnginePack> packs) {
    final installError = EngineService.officialInstallError.value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (packs.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
              child: Text(
                installError == null
                    ? 'No plugins installed. Paste a manifest URL below, or sign in to sync packs from your profile.'
                    : 'Plugin install failed: $installError',
                style: TextStyle(
                  color: installError == null
                      ? ForjaShellColors.textSecondary.withValues(alpha: 0.9)
                      : const Color(0xFFF87171),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            if (installError != null) ...[
              SettingsFilledButton(
                label: 'Retry install',
                icon: Icons.refresh_rounded,
                busy: _engineInstalling,
                onPressed: _retryOfficialEnginePack,
              ),
              const SizedBox(height: 12),
            ],
          ],
          SettingsTextField(
            controller: _engineController,
            label: 'Add plugin',
            hint: 'https://.../manifest.json',
            onSubmitted: (_) => _installEnginePack(),
          ),
          const SizedBox(height: 14),
          SettingsFilledButton(
            label: 'Install',
            icon: Icons.add_rounded,
            busy: _engineInstalling,
            onPressed: _installEnginePack,
          ),
          if (packs.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SettingsEngineMiniLabel('Installed plugins'),
            ..._buildEnginePacksByKind(packs),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildEnginePacksByKind(List<EnginePack> packs) {
    final grouped = groupEnginePacksByKind(packs);
    final out = <Widget>[];
    for (final kind in grouped.orderedKinds) {
      final kindPacks = grouped.byKind[kind] ?? const <EnginePack>[];
      final rows = <Widget>[];
      for (final pack in kindPacks) {
        // HTTP (VOD + Live + schedule Catalog) + hub `kind: catalog`.
        // Hops stay internal.
        final panelPlugins = [
          for (final p in pack.plugins)
            if (p.isHttp || p.isHubCatalog) p,
        ];
        if (panelPlugins.isEmpty) continue;
        rows.add(
          SettingsEnginePackExpansion(
            pack: pack,
            plugins: panelPlugins,
            groupKey: EngineCategories.groupKey,
            groupLabel: EngineCategories.groupLabel,
            groupOrder: EngineCategories.groupOrderFor(panelPlugins),
            trailing: _EnginePackActions(
              packEnabled: pack.enabled,
              onTogglePack: (val) => EngineService.instance.setPackEnabled(
                sourceUrl: pack.sourceUrl,
                enabled: val,
              ),
              onRefresh: () => _refreshEnginePack(pack.sourceUrl),
              onRemove: () => _removeEnginePack(pack.sourceUrl),
              showOfficialBadge: false,
            ),
          ),
        );
      }
      if (rows.isEmpty) continue;
      out.add(const SizedBox(height: 12));
      out.add(SettingsEngineMiniLabel(PluginRegistry.packKindLabel(kind)));
      out.add(const SizedBox(height: 4));
      out.addAll(rows);
    }
    return out;
  }

  Future<void> _retryOfficialEnginePack() async {
    setState(() => _engineInstalling = true);
    try {
      await EngineService.instance.retryOfficialInstall();
      if (!mounted) return;
      ForjaToast.success('Plugins refreshed');
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('Plugin install failed: $e');
    } finally {
      if (mounted) setState(() => _engineInstalling = false);
    }
  }

  Future<void> _refreshEnginePack(String sourceUrl) async {
    setState(() => _engineInstalling = true);
    try {
      final pack = await EngineService.instance.refresh(sourceUrl);
      if (!mounted) return;
      ForjaToast.success(
        'Refreshed ${pack.name} v${pack.version}',
      );
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('Refresh failed: $e');
    } finally {
      if (mounted) setState(() => _engineInstalling = false);
    }
  }

  Future<void> _installEnginePack() async {
    final url = _engineController.text.trim();
    if (url.isEmpty) return;
    setState(() => _engineInstalling = true);
    try {
      final pack = await EngineService.instance.install(url);
      if (!mounted) return;
      _engineController.clear();
      scheduleForjaSyncPush();
      ForjaToast.success(
        'Installed ${pack.name} (${pack.plugins.length} plugins)',
      );
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('Install failed: $e');
    } finally {
      if (mounted) setState(() => _engineInstalling = false);
    }
  }

  Future<void> _removeEnginePack(String sourceUrl) async {
    try {
      await EngineService.instance.removePack(sourceUrl);
      if (!mounted) return;
      scheduleForjaSyncPush();
      ForjaToast.success('Plugin pack removed');
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('$e');
    }
  }

  Widget _buildJackettConfig() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsTextField(
            controller: _jackettUrlController,
            label: 'Base URL',
            hint: 'http://localhost:9117',
            onSubmitted: (_) => setState(() => _jackettTestResult = null),
          ),
          const SizedBox(height: 16),
          SettingsTextField(
            controller: _jackettApiKeyController,
            label: 'API Key',
            hint: 'Enter Jackett API Key',
            obscureText: true,
            onSubmitted: (_) => setState(() => _jackettTestResult = null),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SettingsFilledButton(
                label: 'Test Connection',
                secondary: true,
                busy: _isTestingJackett,
                onPressed: _testJackettConnection,
              ),
              const SizedBox(width: 12),
              SettingsFilledButton(
                label: 'Save',
                onPressed: _saveJackettSettings,
              ),
            ],
          ),
          if (_jackettTestResult != null)
            _TestResult(message: _jackettTestResult!),
        ],
      ),
    );
  }

  Widget _buildProwlarrConfig() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsTextField(
            controller: _prowlarrUrlController,
            label: 'Base URL',
            hint: 'http://localhost:9696',
            onSubmitted: (_) => setState(() {
              _prowlarrTestResult = null;
              _prowlarrTagsLoaded = false;
              _prowlarrAvailableTags = [];
            }),
          ),
          const SizedBox(height: 16),
          SettingsTextField(
            controller: _prowlarrApiKeyController,
            label: 'API Key',
            hint: 'Enter Prowlarr API Key',
            obscureText: true,
            onSubmitted: (_) => setState(() {
              _prowlarrTestResult = null;
              _prowlarrTagsLoaded = false;
              _prowlarrAvailableTags = [];
            }),
          ),
          const SizedBox(height: 20),
          const SettingsEngineMiniLabel('Filter by tag'),
          const SizedBox(height: 8),
          if (!_prowlarrTagsLoaded) ...[
            Text(
              'Use the Test Connection button to load available tags.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ] else if (_prowlarrAvailableTags.isEmpty) ...[
            Text(
              'No tags found in Prowlarr. Add tags to your indexers to use this filter.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ] else ...[
            Text(
              'Limit searches to indexers with the selected tags. Leave all unselected to search all indexers.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _prowlarrAvailableTags.map((tag) {
                final isSelected = _prowlarrSelectedTagIds.contains(tag.id);
                return FilterChip(
                  label: Text(tag.label),
                  selected: isSelected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _prowlarrSelectedTagIds.add(tag.id);
                      } else {
                        _prowlarrSelectedTagIds.remove(tag.id);
                      }
                    });
                  },
                  selectedColor: ForjaShellColors.brandGreen.withValues(
                    alpha: 0.22,
                  ),
                  checkmarkColor: ForjaShellColors.brandGreen,
                  backgroundColor: Colors.transparent,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? ForjaShellColors.brandGreen
                        : ForjaShellColors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? ForjaShellColors.brandGreen
                        : ForjaShellColors.borderSubtle,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }).toList(),
            ),
            if (_prowlarrSelectedTagIds.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'All indexers will be searched.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SettingsFilledButton(
                label: 'Test Connection',
                secondary: true,
                busy: _isTestingProwlarr,
                onPressed: _testProwlarrConnection,
              ),
              const SizedBox(width: 12),
              SettingsFilledButton(
                label: 'Save',
                onPressed: _saveProwlarrSettings,
              ),
            ],
          ),
          if (_prowlarrTestResult != null)
            _TestResult(message: _prowlarrTestResult!),
        ],
      ),
    );
  }

  Future<void> _testJackettConnection() async {
    final url = _jackettUrlController.text.trim();
    final apiKey = _jackettApiKeyController.text.trim();

    if (url.isEmpty || apiKey.isEmpty) {
      setState(
        () => _jackettTestResult = '❌ Please enter both Base URL and API Key',
      );
      return;
    }

    setState(() {
      _isTestingJackett = true;
      _jackettTestResult = null;
    });

    try {
      final result = await _jackett.testConnection(url, apiKey);
      if (mounted) {
        setState(() {
          _jackettTestResult = result.message;
          _isTestingJackett = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _jackettTestResult = '❌ Error: $e';
          _isTestingJackett = false;
        });
      }
    }
  }

  Future<void> _saveJackettSettings() async {
    final url = _jackettUrlController.text.trim();
    final apiKey = _jackettApiKeyController.text.trim();

    await _settings.setJackettBaseUrl(url);
    await _settings.setJackettApiKey(apiKey);
    ref
        .read(settingsIndexerProvider.notifier)
        .reload();

    if (mounted) {
      ForjaToast.success('Jackett settings saved!');
    }
  }

  Future<void> _testProwlarrConnection() async {
    final url = _prowlarrUrlController.text.trim();
    final apiKey = _prowlarrApiKeyController.text.trim();

    if (url.isEmpty || apiKey.isEmpty) {
      setState(
        () => _prowlarrTestResult = '❌ Please enter both Base URL and API Key',
      );
      return;
    }

    setState(() {
      _isTestingProwlarr = true;
      _prowlarrTestResult = null;
    });

    try {
      final result = await _prowlarr.testConnection(url, apiKey);
      if (result.success) {
        _tryLoadProwlarrTags();
      }
      if (mounted) {
        setState(() {
          _prowlarrTestResult = result.message;
          _isTestingProwlarr = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _prowlarrTestResult = '❌ Error: $e';
          _isTestingProwlarr = false;
        });
      }
    }
  }

  Future<void> _saveProwlarrSettings() async {
    final url = _prowlarrUrlController.text.trim();
    final apiKey = _prowlarrApiKeyController.text.trim();

    await _settings.setProwlarrBaseUrl(url);
    await _settings.setProwlarrApiKey(apiKey);
    await _settings.setProwlarrTagIds(_prowlarrSelectedTagIds.toList());
    ref
        .read(settingsIndexerProvider.notifier)
        .reload();

    if (mounted) {
      ForjaToast.success('Prowlarr settings saved!');
    }
  }

  /// Silently fetch Prowlarr tags; used on init and after a successful test.
  Future<void> _tryLoadProwlarrTags() async {
    final url = _prowlarrUrlController.text.trim();
    final apiKey = _prowlarrApiKeyController.text.trim();
    if (url.isEmpty || apiKey.isEmpty) return;
    try {
      final tags = await _prowlarr.fetchTags(url, apiKey);
      if (mounted) {
        setState(() {
          _prowlarrAvailableTags = tags;
          _prowlarrTagsLoaded = true;
        });
      }
    } catch (_) {
      // Non-fatal - tags section simply not shown until explicit test
    }
  }
}

/// Installed addon row — enable switch + trash (Yes/No confirm).
class _AddonRemoveRow extends StatefulWidget {
  const _AddonRemoveRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onEnabledChanged,
    required this.onRemove,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final Future<void> Function() onRemove;

  @override
  State<_AddonRemoveRow> createState() => _AddonRemoveRowState();
}

class _AddonRemoveRowState extends State<_AddonRemoveRow> {
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
      child: Row(
        children: [
          widget.leading,
          const SizedBox(width: 12),
          Expanded(
            child: _confirming
                ? const Text(
                    'Remove this addon?',
                    style: TextStyle(
                      color: Color(0xFFF87171),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: widget.enabled
                              ? ForjaShellColors.textPrimary
                              : ForjaShellColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          color: ForjaShellColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
          ),
          if (!_confirming)
            ForjaSwitch(
              value: widget.enabled,
              scale: ForjaSwitch.settingsScale,
              onChanged: widget.onEnabledChanged,
            ),
          _AddonRemoveActions(
            confirming: _confirming,
            onConfirmingChanged: (v) => setState(() => _confirming = v),
            onRemove: widget.onRemove,
          ),
        ],
      ),
    );
  }
}

/// IconButton on touch/desktop; [shellFocusableTap] on TV so D-pad owns focus.
Widget _settingsTvIconButton(
  BuildContext context, {
  required String tooltip,
  required IconData icon,
  required VoidCallback? onPressed,
  Color color = ForjaShellColors.textPrimary,
}) {
  final child = Icon(icon, color: color, size: 20);
  final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
  if (tv) {
    return shellFocusableTap(
      context: context,
      onTap: onPressed,
      borderRadius: 8,
      scaleOnFocus: 1.0,
      showFocusRail: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      child: SizedBox(width: 40, height: 40, child: Center(child: child)),
    );
  }
  return IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: child,
  );
}

/// Pack master switch + refresh + remove for an installed engine plugin pack.
class _EnginePackActions extends StatelessWidget {
  const _EnginePackActions({
    required this.packEnabled,
    required this.onTogglePack,
    required this.onRefresh,
    required this.onRemove,
    this.showOfficialBadge = false,
  });

  final bool packEnabled;
  final ValueChanged<bool> onTogglePack;
  final VoidCallback onRefresh;
  final Future<void> Function() onRemove;
  final bool showOfficialBadge;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ForjaSwitch(
          value: packEnabled,
          scale: ForjaSwitch.settingsScale,
          onChanged: onTogglePack,
        ),
        if (showOfficialBadge)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              'Official',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: ForjaShellColors.brandGreen.withValues(alpha: 0.9),
              ),
            ),
          ),
        _settingsTvIconButton(
          context,
          tooltip: 'Refresh',
          icon: Icons.refresh_rounded,
          onPressed: onRefresh,
        ),
        _AddonRemoveActions(onRemove: onRemove),
      ],
    );
  }
}

/// Trash → Yes/No in place (same pattern as IPTV portal delete).
class _AddonRemoveActions extends StatefulWidget {
  const _AddonRemoveActions({
    required this.onRemove,
    this.confirming,
    this.onConfirmingChanged,
  });

  final Future<void> Function() onRemove;
  final bool? confirming;
  final ValueChanged<bool>? onConfirmingChanged;

  @override
  State<_AddonRemoveActions> createState() => _AddonRemoveActionsState();
}

class _AddonRemoveActionsState extends State<_AddonRemoveActions> {
  bool _localConfirming = false;

  bool get _confirming => widget.confirming ?? _localConfirming;

  void _setConfirming(bool value) {
    if (widget.onConfirmingChanged != null) {
      widget.onConfirmingChanged!(value);
    } else {
      setState(() => _localConfirming = value);
    }
  }

  Future<void> _confirm() async {
    _setConfirming(false);
    await widget.onRemove();
  }

  Widget _action({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return _settingsTvIconButton(
      context,
      tooltip: tooltip,
      icon: icon,
      color: color,
      onPressed: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_confirming) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _action(
            tooltip: 'Yes',
            icon: Icons.check_rounded,
            color: const Color(0xFFEF4444),
            onTap: () => unawaited(_confirm()),
          ),
          _action(
            tooltip: 'No',
            icon: Icons.close_rounded,
            color: ForjaShellColors.iconMuted,
            onTap: () => _setConfirming(false),
          ),
        ],
      );
    }
    return _action(
      tooltip: 'Remove addon',
      icon: Icons.delete_outline,
      color: const Color(0xFFF87171),
      onTap: () => _setConfirming(true),
    );
  }
}

class _AddonFeatureChip extends StatelessWidget {
  const _AddonFeatureChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? ForjaShellColors.chipSelectedBg
          : ForjaShellColors.surfaceElevated,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? ForjaShellColors.chipSelectedBorder
                  : ForjaShellColors.borderSubtle,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected
                  ? ForjaShellColors.textPrimary
                  : ForjaShellColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Flat connection test-result line (success / failure), no boxed card.
class _TestResult extends StatelessWidget {
  const _TestResult({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ok = message.startsWith('\u2705');
    final color = ok ? ForjaShellColors.brandGreen : const Color(0xFFF87171);
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 2),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_rounded,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
