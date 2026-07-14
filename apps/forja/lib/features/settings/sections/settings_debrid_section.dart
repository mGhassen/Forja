import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/settings/widgets/settings_focus_controls.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:url_launcher/url_launcher.dart';

/// Debrid service selection and API key configuration.
class SettingsDebridSection extends StatefulWidget {
  const SettingsDebridSection({super.key});

  @override
  State<SettingsDebridSection> createState() => _SettingsDebridSectionState();
}

class _SettingsDebridSectionState extends State<SettingsDebridSection> {
  final SettingsService _settings = SettingsService();
  final DebridApi _debrid = DebridApi();

  bool _useDebrid = false;
  String _debridService = 'None';
  final TextEditingController _torboxController = TextEditingController();
  final TextEditingController _alldebridController = TextEditingController();
  final TextEditingController _premiumizeController = TextEditingController();
  final TextEditingController _debridlinkController = TextEditingController();
  bool _isRDLoggedIn = false;
  final TextEditingController _rdController = TextEditingController();
  bool _isVerifyingRD = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _torboxController.dispose();
    _alldebridController.dispose();
    _premiumizeController.dispose();
    _debridlinkController.dispose();
    _rdController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final useDebrid = await _settings.useDebridForStreams();
    final service = await _settings.getDebridService();
    final torboxKey = await _debrid.getTorBoxKey();
    final alldebridKey = await _debrid.getAllDebridKey();
    final premiumizeKey = await _debrid.getPremiumizeKey();
    final debridlinkKey = await _debrid.getDebridLinkKey();
    final rdToken = await _debrid.getRDAccessToken();
    if (!mounted) return;
    setState(() {
      _useDebrid = useDebrid;
      _debridService = service;
      _torboxController.text = torboxKey ?? '';
      _alldebridController.text = alldebridKey ?? '';
      _premiumizeController.text = premiumizeKey ?? '';
      _debridlinkController.text = debridlinkKey ?? '';
      _isRDLoggedIn = rdToken != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: 'Debrid',
          children: [
            settingsFocusableToggle(
              context,
              'Use Debrid for Streams',
              'Resolve torrents using your debrid account.',
              _useDebrid,
              (val) async {
                await _settings.setUseDebridForStreams(val);
                setState(() => _useDebrid = val);
              },
            ),
            settingsFocusableDropdown(
              context,
              'Debrid Service',
              'Select your preferred provider.',
              _debridService,
              const [
                'None',
                'Real-Debrid',
                'TorBox',
                'AllDebrid',
                'Premiumize',
                'Debrid-Link',
              ],
              (val) async {
                if (val != null) {
                  await _settings.setDebridService(val);
                  setState(() => _debridService = val);
                }
              },
            ),
          ],
        ),
        if (_debridService == 'Real-Debrid') _buildRDLogin(),
        if (_debridService == 'TorBox') _buildTorBoxConfig(),
        if (_debridService == 'AllDebrid') _buildAllDebridConfig(),
        if (_debridService == 'Premiumize') _buildPremiumizeConfig(),
        if (_debridService == 'Debrid-Link') _buildDebridLinkConfig(),
      ],
    );
  }
  Future<void> _saveRDApiKey() async {
    final key = _rdController.text.trim();
    if (key.isEmpty) {
      if (mounted) {
        ForjaToast.warning('Please enter an API key');
      }
      return;
    }

    // Just save the key — no verify round-trip. The verify call hangs forever
    // on macOS for some users, leaving the spinner stuck. If the key is wrong
    // they'll find out the first time they try to stream.
    await _debrid.saveRDApiKey(key);
    if (!mounted) return;
    setState(() {
      _isRDLoggedIn = true;
      _isVerifyingRD = false;
      _rdController.clear();
    });
    ForjaToast.success('Real-Debrid API key saved');
  }

  void _logoutRD() async {
    await _debrid.logoutRD();
    setState(() {
      _isRDLoggedIn = false;
      _rdController.clear();
    });
    if (mounted) {
      ForjaToast.success('Logged out of Real-Debrid');
    }
  }
  Widget _apiKeyConfig({
    required TextEditingController controller,
    required String hint,
    required Future<void> Function() onSave,
    bool busy = false,
    String? linkLabel,
    String? linkUrl,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsTextField(
            controller: controller,
            label: 'API Key',
            hint: hint,
            obscureText: true,
            onSubmitted: (_) => onSave(),
          ),
          const SizedBox(height: 14),
          SettingsFilledButton(
            label: 'Save',
            icon: Icons.save,
            busy: busy,
            onPressed: onSave,
          ),
          if (linkLabel != null && linkUrl != null) ...[
            const SizedBox(height: 10),
            _apiKeyLink(linkLabel, linkUrl),
          ],
        ],
      ),
    );
  }

  Widget _apiKeyLink(String label, String url) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Text(
        label,
        style: const TextStyle(
          color: ForjaShellColors.brandGreen,
          fontSize: 12,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildRDLogin() {
    if (_isRDLoggedIn) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: SettingsFilledButton(
          label: 'Logout from Real-Debrid',
          icon: Icons.logout,
          secondary: true,
          onPressed: _logoutRD,
        ),
      );
    }
    return _apiKeyConfig(
      controller: _rdController,
      hint: 'Enter Real-Debrid API Key',
      busy: _isVerifyingRD,
      onSave: _saveRDApiKey,
      linkLabel: 'Get your API key at real-debrid.com/apitoken',
      linkUrl: 'https://real-debrid.com/apitoken',
    );
  }

  Widget _buildTorBoxConfig() {
    return _apiKeyConfig(
      controller: _torboxController,
      hint: 'Enter TorBox API Key',
      onSave: () async {
        await _debrid.saveTorBoxKey(_torboxController.text);
        if (mounted) ForjaToast.success('TorBox API Key Saved!');
      },
    );
  }

  Widget _buildAllDebridConfig() {
    return _apiKeyConfig(
      controller: _alldebridController,
      hint: 'Enter AllDebrid API Key',
      onSave: () async {
        await _debrid.saveAllDebridKey(_alldebridController.text);
        if (mounted) ForjaToast.success('AllDebrid API Key Saved!');
      },
      linkLabel: 'Get your API key at alldebrid.com/apikeys',
      linkUrl: 'https://alldebrid.com/apikeys',
    );
  }

  Widget _buildPremiumizeConfig() {
    return _apiKeyConfig(
      controller: _premiumizeController,
      hint: 'Enter Premiumize API Key',
      onSave: () async {
        await _debrid.savePremiumizeKey(_premiumizeController.text);
        if (mounted) ForjaToast.success('Premiumize API Key Saved!');
      },
      linkLabel: 'Get your API key at premiumize.me/account',
      linkUrl: 'https://www.premiumize.me/account',
    );
  }

  Widget _buildDebridLinkConfig() {
    return _apiKeyConfig(
      controller: _debridlinkController,
      hint: 'Enter Debrid-Link API Key',
      onSave: () async {
        await _debrid.saveDebridLinkKey(_debridlinkController.text);
        if (mounted) ForjaToast.success('Debrid-Link API Key Saved!');
      },
      linkLabel: 'Get your API key at debrid-link.com/webapp/apikey',
      linkUrl: 'https://debrid-link.com/webapp/apikey',
    );
  }
}
