import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/widgets/settings_focus_controls.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:url_launcher/url_launcher.dart';

/// Debrid service selection and API key configuration.
class SettingsDebridSection extends ConsumerStatefulWidget {
  const SettingsDebridSection({super.key});

  @override
  ConsumerState<SettingsDebridSection> createState() =>
      _SettingsDebridSectionState();
}

class _SettingsDebridSectionState
    extends ConsumerState<SettingsDebridSection> {
  final SettingsService _settings = SettingsService();
  final DebridApi _debrid = DebridApi();

  final TextEditingController _torboxController = TextEditingController();
  final TextEditingController _alldebridController = TextEditingController();
  final TextEditingController _premiumizeController = TextEditingController();
  final TextEditingController _debridlinkController = TextEditingController();
  final TextEditingController _rdController = TextEditingController();
  bool _isVerifyingRD = false;
  bool _hydrated = false;

  @override
  void dispose() {
    _torboxController.dispose();
    _alldebridController.dispose();
    _premiumizeController.dispose();
    _debridlinkController.dispose();
    _rdController.dispose();
    super.dispose();
  }

  void _hydrate(SettingsDebridSnapshot snap) {
    _torboxController.text = snap.torboxKey;
    _alldebridController.text = snap.alldebridKey;
    _premiumizeController.text = snap.premiumizeKey;
    _debridlinkController.text = snap.debridlinkKey;
    _hydrated = true;
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(settingsDebridProvider).valueOrNull;
    if (snap == null) {
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
    if (!_hydrated) _hydrate(snap);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: 'Debrid',
          adminOnly: true,
          children: [
            settingsFocusableToggle(
              context,
              'Use Debrid for Streams',
              'Resolve torrents using your debrid account.',
              snap.useDebrid,
              (val) async {
                await _settings.setUseDebridForStreams(val);
                ref
                    .read(settingsDebridProvider.notifier)
                    .patch((s) => s.copyWith(useDebrid: val));
              },
            ),
            settingsFocusableDropdown(
              context,
              'Debrid Service',
              'Select your preferred provider.',
              snap.service,
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
                  ref
                      .read(settingsDebridProvider.notifier)
                      .patch((s) => s.copyWith(service: val));
                }
              },
            ),
          ],
        ),
        if (snap.service == 'Real-Debrid') _buildRDLogin(snap),
        if (snap.service == 'TorBox') _buildTorBoxConfig(),
        if (snap.service == 'AllDebrid') _buildAllDebridConfig(),
        if (snap.service == 'Premiumize') _buildPremiumizeConfig(),
        if (snap.service == 'Debrid-Link') _buildDebridLinkConfig(),
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

    // Just save the key - no verify round-trip. The verify call hangs forever
    // on macOS for some users, leaving the spinner stuck. If the key is wrong
    // they'll find out the first time they try to stream.
    await _debrid.saveRDApiKey(key);
    if (!mounted) return;
    _rdController.clear();
    setState(() => _isVerifyingRD = false);
    await ref.read(settingsDebridProvider.notifier).reload();
    if (!mounted) return;
    ForjaToast.success('Real-Debrid API key saved');
  }

  void _logoutRD() async {
    await _debrid.logoutRD();
    _rdController.clear();
    await ref.read(settingsDebridProvider.notifier).reload();
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
    return shellFocusableTap(
      context: context,
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: 6,
      scaleOnFocus: 1.0,
      showFocusRail: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: ForjaShellColors.brandGreen,
            fontSize: 12,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  Widget _buildRDLogin(SettingsDebridSnapshot snap) {
    if (snap.isRDLoggedIn) {
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
