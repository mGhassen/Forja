import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/settings/widgets/settings_expandable_section.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/theme/app_theme.dart';

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
    return SettingsExpandableSection(
      id: 'providers',
      icon: Icons.extension_rounded,
      title: 'Providers & Addons',
      children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'STREMIO ADDONS',
                      style: TextStyle(
                        color: AppTheme.current.primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildAddonInput(),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'NUVIO ADDONS',
                      style: TextStyle(
                        color: AppTheme.current.primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildNuvioAddonSection(),
                  if (PlatformPlayback.capabilities.builtinTorrentSearch) ...[
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'JACKETT',
                        style: TextStyle(
                          color: AppTheme.current.primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildJackettConfig(),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'PROWLARR',
                        style: TextStyle(
                          color: AppTheme.current.primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildProwlarrConfig(),
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
    if (mounted) ForjaToast.success('Addon removed');
  }
  Widget _buildAddonInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Install Stremio Addon',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addonController,
                  decoration: InputDecoration(
                    hintText: 'stremio://... or https://...',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isInstalling ? null : _installAddon,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isInstalling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Install',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
          if (_installedAddons.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'INSTALLED ADDONS',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            ..._installedAddons.map(
              (addon) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListTile(
                  leading: addon['icon'].toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            addon['icon'],
                            width: 32,
                            height: 32,
                            errorBuilder: (c, e, s) =>
                                const Icon(Icons.extension),
                          ),
                        )
                      : const Icon(
                          Icons.extension,
                          color: AppTheme.primaryColor,
                        ),
                  title: Text(
                    addon['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    addon['baseUrl'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _removeAddon(addon['baseUrl']),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNuvioAddonSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Install Nuvio Addon',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Paste a Nuvio manifest URL (raw .../manifest.json)',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nuvioController,
                  decoration: InputDecoration(
                    hintText: 'https://.../manifest.json',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _nuvioInstalling ? null : _installNuvioAddon,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _nuvioInstalling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Install',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
          if (_nuvioAddons.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'INSTALLED NUVIO ADDONS',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            ..._nuvioAddons.map(
              (addon) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    leading: const Icon(
                      Icons.code_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(
                      addon.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '${addon.scrapers.length} scraper${addon.scrapers.length == 1 ? '' : 's'} \u00b7 v${addon.version}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      onPressed: () => _removeNuvioAddon(addon.manifestUrl),
                      tooltip: 'Remove addon',
                    ),
                    children: addon.scrapers.map((s) {
                      return SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        dense: true,
                        activeThumbColor: AppTheme.primaryColor,
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
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (s.description != null &&
                                s.description!.isNotEmpty)
                              s.description!,
                            if (s.supportedTypes.isNotEmpty)
                              s.supportedTypes.join(', '),
                          ].join(' \u00b7 '),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Base URL',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _jackettUrlController,
            decoration: InputDecoration(
              hintText: 'http://localhost:9117',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: (_) => setState(() => _jackettTestResult = null),
          ),
          const SizedBox(height: 16),
          const Text(
            'API Key',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _jackettApiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Enter Jackett API Key',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: (_) => setState(() => _jackettTestResult = null),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isTestingJackett ? null : _testJackettConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isTestingJackett
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Test Connection',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveJackettSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          if (_jackettTestResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _jackettTestResult!.startsWith('✅')
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _jackettTestResult!.startsWith('✅')
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _jackettTestResult!,
                style: TextStyle(
                  color: _jackettTestResult!.startsWith('✅')
                      ? Colors.green
                      : Colors.red,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProwlarrConfig() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Base URL',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _prowlarrUrlController,
            decoration: InputDecoration(
              hintText: 'http://localhost:9696',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: (_) => setState(() {
              _prowlarrTestResult = null;
              _prowlarrTagsLoaded = false;
              _prowlarrAvailableTags = [];
            }),
          ),
          const SizedBox(height: 16),
          const Text(
            'API Key',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _prowlarrApiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Enter Prowlarr API Key',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: (_) => setState(() {
              _prowlarrTestResult = null;
              _prowlarrTagsLoaded = false;
              _prowlarrAvailableTags = [];
            }),
          ),
          const SizedBox(height: 20),
          const Text(
            'Filter by Tag',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
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
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.25),
                  checkmarkColor: AppTheme.primaryColor,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : Colors.white70,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.white.withValues(alpha: 0.2),
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
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isTestingProwlarr
                      ? null
                      : _testProwlarrConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isTestingProwlarr
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Test Connection',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveProwlarrSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          if (_prowlarrTestResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _prowlarrTestResult!.startsWith('✅')
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _prowlarrTestResult!.startsWith('✅')
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _prowlarrTestResult!,
                style: TextStyle(
                  color: _prowlarrTestResult!.startsWith('✅')
                      ? Colors.green
                      : Colors.red,
                  fontSize: 13,
                ),
              ),
            ),
          ],
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
