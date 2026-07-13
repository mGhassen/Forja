import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/settings/widgets/settings_expandable_section.dart';
import 'package:forja/features/settings/widgets/settings_focus_controls.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
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
    return SettingsExpandableSection(
      id: 'debrid',
      icon: Icons.cloud_download_rounded,
      title: 'Debrid',
      children: [
                  settingsFocusableToggle(context, 
                    'Use Debrid for Streams',
                    'Resolve torrents using your debrid account.',
                    _useDebrid,
                    (val) async {
                      await _settings.setUseDebridForStreams(val);
                      setState(() => _useDebrid = val);
                    },
                  ),
                  settingsFocusableDropdown(context, 
                    'Debrid Service',
                    'Select your preferred provider.',
                    _debridService,
                    [
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
  Widget _buildRDLogin() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isRDLoggedIn)
            ElevatedButton.icon(
              onPressed: _logoutRD,
              icon: const Icon(Icons.logout),
              label: const Text('Logout from Real-Debrid'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                foregroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          else ...[
            const Text(
              'API Key',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rdController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Enter Real-Debrid API Key',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isVerifyingRD ? null : _saveRDApiKey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isVerifyingRD
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final url = Uri.parse('https://real-debrid.com/apitoken');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text(
                'Get your API key at real-debrid.com/apitoken',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTorBoxConfig() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'API Key',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _torboxController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Enter TorBox API Key',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  await _debrid.saveTorBoxKey(_torboxController.text);
                  if (mounted) {
                    ForjaToast.success('TorBox API Key Saved!');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllDebridConfig() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'API Key',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _alldebridController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Enter AllDebrid API Key',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  await _debrid.saveAllDebridKey(_alldebridController.text);
                  if (mounted) {
                    ForjaToast.success('AllDebrid API Key Saved!');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final url = Uri.parse('https://alldebrid.com/apikeys');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text(
              'Get your API key at alldebrid.com/apikeys',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumizeConfig() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'API Key',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _premiumizeController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Enter Premiumize API Key',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  await _debrid.savePremiumizeKey(_premiumizeController.text);
                  if (mounted) {
                    ForjaToast.success('Premiumize API Key Saved!');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final url = Uri.parse('https://www.premiumize.me/account');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text(
              'Get your API key at premiumize.me/account',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebridLinkConfig() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'API Key',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _debridlinkController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Enter Debrid-Link API Key',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  await _debrid.saveDebridLinkKey(_debridlinkController.text);
                  if (mounted) {
                    ForjaToast.success('Debrid-Link API Key Saved!');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final url = Uri.parse('https://debrid-link.com/webapp/apikey');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text(
              'Get your API key at debrid-link.com/webapp/apikey',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
