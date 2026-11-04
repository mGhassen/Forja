import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/l10n/l10n.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:rust/rust.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';

class SettingsMdblistPanel extends ConsumerStatefulWidget {
  const SettingsMdblistPanel({super.key});

  @override
  ConsumerState<SettingsMdblistPanel> createState() =>
      _SettingsMdblistPanelState();
}

class _SettingsMdblistPanelState extends ConsumerState<SettingsMdblistPanel> {
  final MdblistService _service = MdblistService();
  final TextEditingController _apiKeyController = TextEditingController();
  bool _hydrated = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _hydrate(TrackerAccountStatus status) {
    _apiKeyController.text = status.apiKey ?? '';
    _hydrated = true;
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      if (mounted) {
        ForjaToast.warning(context.l10n.addonsHostMdblistEnterKeyWarning);
      }
      return;
    }

    await _service.setApiKey(key);

    // Validate by fetching user info
    final info = await _service.getUserInfo();
    if (info != null) {
      ref.invalidate(mdblistStatusProvider);
      if (mounted) {
        final username = info['name']?.toString();
        ForjaToast.success(
          username != null
              ? context.l10n.addonsHostMdblistConnectedAsToast(username)
              : context.l10n.addonsHostMdblistConnectedToast,
        );
      }
    } else {
      await _service.logout();
      ref.invalidate(mdblistStatusProvider);
      if (mounted) {
        ForjaToast.error(context.l10n.addonsHostMdblistInvalidKeyError);
      }
    }
  }

  void _logout() async {
    await _service.logout();
    _apiKeyController.clear();
    ref.invalidate(mdblistStatusProvider);
    if (mounted) {
      ForjaToast.success(context.l10n.addonsHostMdblistKeyRemovedToast);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(mdblistStatusProvider).valueOrNull;
    final isConfigured = status?.loggedIn ?? false;
    final username = status?.username;
    if (status != null && !_hydrated) _hydrate(status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.addonsHostMdblistIntro,
            style: TextStyle(
              fontSize: SettingsTokens.typeSizeOf(context, 13),
              color: ForjaShellColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          if (isConfigured) ...[
            SettingsStatusRow(
              title: username != null
                  ? context.l10n.addonsHostMdblistConnectedAsStatus(username)
                  : context.l10n.addonsHostMdblistConnectedStatus,
              subtitle: 'MDBlist',
            ),
            const SizedBox(height: 12),
            SettingsFilledButton(
              label: context.l10n.addonsHostMdblistRemoveKeyButton,
              icon: Icons.logout,
              secondary: true,
              onPressed: _logout,
            ),
          ] else ...[
            SettingsTextField(
              controller: _apiKeyController,
              label: context.l10n.addonsHostMdblistKeyLabel,
              hint: context.l10n.addonsHostMdblistKeyHint,
              obscureText: true,
              onSubmitted: (_) => _saveApiKey(),
            ),
            const SizedBox(height: 14),
            SettingsFilledButton(
              label: context.l10n.addonsHostMdblistSaveKeyButton,
              icon: Icons.save,
              onPressed: _saveApiKey,
            ),
          ],
        ],
      ),
    );
  }

}
