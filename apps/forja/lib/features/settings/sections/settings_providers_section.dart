import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/sync/sync.dart';

/// Stremio addons, Nuvio scrapers, Jackett, and Prowlarr.
class SettingsProvidersSection extends StatefulWidget {
  const SettingsProvidersSection({super.key});

  @override
  State<SettingsProvidersSection> createState() =>
      _SettingsProvidersSectionState();
}

class _SettingsProvidersSectionState extends State<SettingsProvidersSection> {
  final SettingsService _settings = SettingsService();
  final StremioService _stremio = StremioService();
  final JackettService _jackett = JackettService();
  final ProwlarrService _prowlarr = ProwlarrService();

  List<Map<String, dynamic>> _installedAddons = [];
  bool _isInstalling = false;
  final TextEditingController _addonController = TextEditingController();
  final TextEditingController _nuvioController = TextEditingController();
  bool _nuvioInstalling = false;
  List<NuvioAddon> _nuvioAddons = [];

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

  @override
  void initState() {
    super.initState();
    _load();
    _loadNuvioAddons();
    NuvioService.changeNotifier.addListener(_loadNuvioAddons);
  }

  @override
  void dispose() {
    NuvioService.changeNotifier.removeListener(_loadNuvioAddons);
    _addonController.dispose();
    _nuvioController.dispose();
    _jackettUrlController.dispose();
    _jackettApiKeyController.dispose();
    _prowlarrUrlController.dispose();
    _prowlarrApiKeyController.dispose();
    _jackett.dispose();
    _prowlarr.dispose();
    super.dispose();
  }

  Future<void> _loadNuvioAddons() async {
    final list = await NuvioService.instance.listUserAddons();
    if (!mounted) return;
    setState(() => _nuvioAddons = list);
  }

  Future<void> _load() async {
    final addons = await _settings.getStremioAddons();
    final jackettUrl = await _settings.getJackettBaseUrl();
    final jackettKey = await _settings.getJackettApiKey();
    final prowlarrUrl = await _settings.getProwlarrBaseUrl();
    final prowlarrKey = await _settings.getProwlarrApiKey();
    final prowlarrTagIds = await _settings.getProwlarrTagIds();
    if (!mounted) return;
    setState(() {
      _installedAddons = addons;
      _jackettUrlController.text = jackettUrl ?? '';
      _jackettApiKeyController.text = jackettKey ?? '';
      _prowlarrUrlController.text = prowlarrUrl ?? '';
      _prowlarrApiKeyController.text = prowlarrKey ?? '';
      _prowlarrSelectedTagIds = prowlarrTagIds.toSet();
    });
    if ((prowlarrUrl?.isNotEmpty ?? false) && (prowlarrKey?.isNotEmpty ?? false)) {
      _tryLoadProwlarrTags();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: 'Stremio addons',
          children: [_buildAddonInput()],
        ),
        SettingsGroup(
          label: 'Nuvio addons',
          children: [_buildNuvioAddonSection()],
        ),
        if (PlatformPlayback.capabilities.builtinTorrentSearch) ...[
          SettingsGroup(
            label: 'Jackett',
            children: [_buildJackettConfig()],
          ),
          SettingsGroup(
            label: 'Prowlarr',
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
        await _load();
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

  void _removeAddon(String baseUrl) async {
    await _settings.removeStremioAddon(baseUrl);
    await _load();
    scheduleStremioSyncPush();
    if (mounted) ForjaToast.success('Addon removed');
  }
  Widget _buildAddonInput() {
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
          if (_installedAddons.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _MiniLabel('Installed addons'),
            const SizedBox(height: 4),
            ..._installedAddons.map(
              (addon) => _FlatListRow(
                leading: addon['icon'].toString().isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          addon['icon'],
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
                title: addon['name'].toString(),
                subtitle: addon['baseUrl'].toString(),
                onRemove: () => _removeAddon(addon['baseUrl']),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNuvioAddonSection() {
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
          if (_nuvioAddons.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _MiniLabel('Installed Nuvio addons'),
            const SizedBox(height: 4),
            ..._nuvioAddons.map(
              (addon) => Theme(
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
                    addon.name,
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
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFF87171),
                      size: 20,
                    ),
                    onPressed: () => _removeNuvioAddon(addon.manifestUrl),
                    tooltip: 'Remove addon',
                  ),
                  children: addon.scrapers.map((s) {
                    return SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      dense: true,
                      value: s.enabled,
                      onChanged: (val) async {
                        await NuvioService.instance.setScraperEnabled(
                          manifestUrl: addon.manifestUrl,
                          scraperId: s.id,
                          enabled: val,
                        );
                      },
                      title: Text(
                        s.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ForjaShellColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (s.description != null && s.description!.isNotEmpty)
                            s.description!,
                          if (s.supportedTypes.isNotEmpty)
                            s.supportedTypes.join(', '),
                        ].join(' \u00b7 '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: ForjaShellColors.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
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
      await _loadNuvioAddons();
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('Install failed: $e');
    } finally {
      if (mounted) setState(() => _nuvioInstalling = false);
    }
  }

  Future<void> _removeNuvioAddon(String manifestUrl) async {
    await NuvioService.instance.remove(manifestUrl);
    await _loadNuvioAddons();
    if (!mounted) return;
    ForjaToast.success('Nuvio addon removed');
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
          const _MiniLabel('Filter by tag'),
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
      // Non-fatal — tags section simply not shown until explicit test
    }
  }
}

/// Small muted uppercase label used for inline sub-sections.
class _MiniLabel extends StatelessWidget {
  const _MiniLabel(this.text);

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

/// Flat installed-item row with a leading widget and a remove button.
class _FlatListRow extends StatelessWidget {
  const _FlatListRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onRemove,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: ForjaShellColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: ForjaShellColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFF87171)),
            onPressed: onRemove,
          ),
        ],
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
