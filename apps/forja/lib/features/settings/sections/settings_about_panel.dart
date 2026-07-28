import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/app_updater_service.dart';
import 'package:forja/shared/telemetry/product_analytics.dart';
import 'package:forja/shared/telemetry/telemetry.dart';
import 'package:forja/shared/widgets/macos_keychain_consent_screen.dart';
import 'package:forja/shared/widgets/update_dialog.dart';
import 'package:rust/rust.dart';

class SettingsAboutPanel extends StatefulWidget {
  const SettingsAboutPanel({super.key});

  @override
  State<SettingsAboutPanel> createState() => _SettingsAboutPanelState();
}

class _SettingsAboutPanelState extends State<SettingsAboutPanel> {
  bool _isChecking = false;
  final AppUpdaterService _updater = AppUpdaterService();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Check for new versions of Forja',
            style: TextStyle(
              fontSize: 13,
              color: ForjaShellColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SettingsFilledButton(
            label: _isChecking ? 'Checking...' : 'Check for Updates',
            icon: Icons.system_update_rounded,
            busy: _isChecking,
            onPressed: _isChecking ? null : _checkForUpdates,
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdates() async {
    setState(() => _isChecking = true);

    try {
      final result = await _updater.checkForUpdates();

      if (mounted) {
        setState(() => _isChecking = false);

        if (result.isAvailable && result.info != null) {
          unawaited(UpdateDialog.show(context, result.info!));
        } else if (result.isFailed) {
          ForjaToast.error(
            result.failureMessage ?? 'Could not check for updates.',
          );
        } else {
          ForjaToast.success("You're running the latest version!");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isChecking = false);
        ForjaToast.error('Failed to check for updates: $e');
      }
    }
  }
}

/// Opt-in Sentry crash reporting (RFC-043).
class SettingsCrashReportingRow extends ConsumerStatefulWidget {
  const SettingsCrashReportingRow({super.key});

  @override
  ConsumerState<SettingsCrashReportingRow> createState() =>
      _SettingsCrashReportingRowState();
}

class _SettingsCrashReportingRowState
    extends ConsumerState<SettingsCrashReportingRow> {
  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(crashReportingEnabledProvider).valueOrNull;
    if (enabled == null) return const SizedBox.shrink();
    return SettingsToggleRow(
      title: 'Crash reporting',
      subtitle: Telemetry.isConfigured
          ? 'Send anonymized crash reports to help fix bugs. Off by default.'
          : 'Unavailable in this build (no Sentry DSN). Preference still saved.',
      value: enabled,
      onChanged: _setCrashReporting,
    );
  }

  Future<void> _setCrashReporting(bool value) async {
    await Telemetry.setEnabled(value);
    ref.invalidate(crashReportingEnabledProvider);
    if (!mounted) return;
    if (value && !Telemetry.isConfigured) {
      ForjaToast.info(
        'Crash reporting will activate once this build includes a Sentry DSN.',
      );
    } else if (value && Telemetry.isActive) {
      ForjaToast.success('Crash reporting on');
    } else if (!value) {
      ForjaToast.success('Crash reporting off');
    }
  }
}

/// Opt-in PostHog product analytics (RFC-043).
class SettingsProductAnalyticsRow extends ConsumerStatefulWidget {
  const SettingsProductAnalyticsRow({super.key});

  @override
  ConsumerState<SettingsProductAnalyticsRow> createState() =>
      _SettingsProductAnalyticsRowState();
}

class _SettingsProductAnalyticsRowState
    extends ConsumerState<SettingsProductAnalyticsRow> {
  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(productAnalyticsEnabledProvider).valueOrNull;
    if (enabled == null) return const SizedBox.shrink();
    return SettingsToggleRow(
      title: 'Product analytics',
      subtitle: ProductAnalytics.isConfigured
          ? 'Anonymous usage events + session replay (text/images masked). Off by default.'
          : 'Unavailable in this build (no PostHog API key). Preference still saved.',
      value: enabled,
      onChanged: _setEnabled,
    );
  }

  Future<void> _setEnabled(bool value) async {
    await Telemetry.setAnalyticsEnabled(value);
    ref.invalidate(productAnalyticsEnabledProvider);
    if (!mounted) return;
    if (value && !ProductAnalytics.isConfigured) {
      ForjaToast.info(
        'Analytics will activate once this build includes a PostHog API key.',
      );
    } else if (value && ProductAnalytics.isActive) {
      ForjaToast.success('Product analytics on');
    } else if (!value) {
      ForjaToast.success('Product analytics off');
    }
  }
}

/// macOS only — opt into Keychain for secrets (default is local app file).
class SettingsMacOsKeychainRow extends ConsumerStatefulWidget {
  const SettingsMacOsKeychainRow({super.key});

  @override
  ConsumerState<SettingsMacOsKeychainRow> createState() =>
      _SettingsMacOsKeychainRowState();
}

class _SettingsMacOsKeychainRowState
    extends ConsumerState<SettingsMacOsKeychainRow> {
  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) return const SizedBox.shrink();
    final enabled = ref.watch(macOsKeychainEnabledProvider).valueOrNull;
    if (enabled == null) return const SizedBox.shrink();
    return SettingsToggleRow(
      title: 'Store secrets in Keychain',
      subtitle:
          'Off by default (local app file). Turn on to use the macOS Keychain — '
          'Forja explains first; the system may ask for your password once.',
      value: enabled,
      onChanged: _setEnabled,
    );
  }

  Future<void> _setEnabled(bool value) async {
    if (value) {
      final result = await showMacOsKeychainConsentDialog(context);
      if (!mounted) return;
      final accepted = result == ForjaKeychainConsent.accepted;
      ref.invalidate(macOsKeychainEnabledProvider);
      if (accepted) {
        ForjaToast.success('Keychain enabled for secrets');
      }
      return;
    }
    await ForjaPlatformSecureStore.setKeychainConsent(
      ForjaKeychainConsent.declined,
    );
    ref.invalidate(macOsKeychainEnabledProvider);
    if (!mounted) return;
    ForjaToast.success('Using local file storage');
  }
}
